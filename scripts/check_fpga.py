#!/usr/bin/env python3
"""Arty simulations, source/XDC/image checks, and Tcl contract tests (NOT Vivado)."""
import ctypes
import ctypes.util
import json
import pathlib
import re
import sys
import tempfile
from regress import ROOT,command,simulate
from reference import cases
from validate_images import validate_image

BOARD_RTL=['rtl/board/reset_conditioner.sv','rtl/board/uart_hello.sv',
           'boards/arty_a7_100t/arty_a7_top.sv']

def board_uart(path,cpu_only=False):
    lines=(ROOT/path).read_text().splitlines()
    assert lines[0]=='RV32I SoC Booted', 'Missing boot message'
    assert re.fullmatch(r'COUNTER_READ_DELTA=[0-9a-f]{8}',lines[1])
    width=4 if cpu_only else 9
    assert len(lines)==2+26*width+1 and 'FAIL' not in '\n'.join(lines)
    rows=[]
    for c in cases()[:26]:
        group=lines[2+c['id']*width:2+(c['id']+1)*width]
        assert group[0]==('CPU test: ' if cpu_only else 'Test: ')+str(c['id'])
        assert group[1]==f"CPU result: {c['expected']}"
        if cpu_only:
            assert int(group[2].removeprefix('CPU cycles: '))>0 and group[3]=='TEST PASSED'
        else:
            assert group[2]==f"Accelerator result: {c['expected']}"
            cpu=int(group[3].removeprefix('CPU cycles: '))
            acc=int(group[4].removeprefix('Accelerator cycles: '))
            e2e=int(group[5].removeprefix('End-to-end cycles: '))
            assert cpu>0 and acc==8 and e2e>acc
            for label,line,denom in [('Speedup',group[6],e2e),('Compute-only speedup',group[7],acc)]:
                scaled=cpu*100//denom
                assert line==f'{label}: {scaled//100}.{scaled%100:02d}x', 'Printed speedup differs from measured counters'
            assert group[8]=='TEST PASSED'
            rows.append(dict(id=c['id'],result=c['expected'],cpu=cpu,compute=acc,e2e=e2e))
    assert lines[-1]==('ALL CPU PASS' if cpu_only else 'ALL PASS')
    print(f'PASS: {path}, 26 decimal result/cycle reports'+('' if cpu_only else ' and 52 calculated speedup values'))
    return rows

def image_checks():
    for stem in ['demo','cpu','board','board_cpu']:
        folder=ROOT/'build'/'firmware' if stem.startswith('board') else ROOT/'firmware'/'hex'
        for kind in ['rom','ram']:validate_image(folder/f'{stem}_{kind}.hex',program=(kind=='rom'))
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
        p=pathlib.Path(temp)/'bad.hex'
        malformed=['','12345678\n','0000000g\n'*4096,'0\n'*4096,'00000000\n'*4096,'00000013\n'*4096]
        for text in malformed:
            p.write_text(text)
            try:validate_image(p,program=True)
            except ValueError:pass
            else:raise AssertionError('Accepted malformed/empty program')
    print('PASS: 8 valid memory images; 6 malformed/empty-program fixtures rejected')

def tcl_eval(code):
    # Use the already-installed Tcl shared library; no machine installation needed.
    lib=ctypes.CDLL(ctypes.util.find_library('tcl8.6') or 'libtcl8.6.so')
    lib.Tcl_CreateInterp.restype=ctypes.c_void_p
    lib.Tcl_Init.argtypes=[ctypes.c_void_p];lib.Tcl_Init.restype=ctypes.c_int
    lib.Tcl_Eval.argtypes=[ctypes.c_void_p,ctypes.c_char_p];lib.Tcl_Eval.restype=ctypes.c_int
    lib.Tcl_GetStringResult.argtypes=[ctypes.c_void_p];lib.Tcl_GetStringResult.restype=ctypes.c_char_p
    lib.Tcl_DeleteInterp.argtypes=[ctypes.c_void_p]
    interp=lib.Tcl_CreateInterp()
    try:
        if lib.Tcl_Init(interp):raise RuntimeError('Tcl initialization failed')
        rc=lib.Tcl_Eval(interp,code.encode())
        result=lib.Tcl_GetStringResult(interp).decode(errors='replace')
        return rc,result
    finally:lib.Tcl_DeleteInterp(interp)

def tcl_checks():
    source='source {'+str(ROOT/'boards'/'arty_a7_100t'/'build.tcl')+'}'
    for demo in ['integrated','cpu','uart','led']:
        rc,msg=tcl_eval(f'set argv {{--check-only --demo {demo}}}; {source}')
        assert rc==0,msg
    rc,msg=tcl_eval('set argv {}; '+source)
    assert rc!=0 and 'Vivado is unavailable' in msg
    # Execute guard branches with explicit mocks. These are script contract tests,
    # never vendor-tool results; mock report files are redirected into build/tcl-contract.
    mocks=r'''
        proc puts args {}
        rename open real_open
        proc open {path args} {
            if {[string match build/vivado/* $path]} {
                set path [file join build tcl-contract $::scenario [file tail $path]]
                file mkdir [file dirname $path]
            }
            return [real_open $path {*}$args]
        }
        foreach cmd {read_verilog read_xdc synth_design report_utilization write_checkpoint
                     opt_design place_design phys_opt_design report_route_status report_timing_summary
                     report_clock_interaction report_cdc report_drc} {proc $cmd args {}}
        proc route_design {} {if {$::scenario eq "route"} {error "mock route failure"}}
        proc get_parts args {return xc7a100tcsg324-1}
        proc get_ports args {return {clk reset_n uart_rx uart_tx led[0] led[1] led[2] led[3]}}
        proc get_clocks args {return soc_clock}
        proc get_property {property object} {
            switch -- $property {
                PACKAGE_PIN {return verified}
                IOSTANDARD {return LVCMOS33}
                PERIOD {return 10.0}
                SLACK {if {$::scenario eq "slack"} {return -0.1};return 0.5}
                default {error "Unexpected property"}
            }
        }
        proc get_timing_paths args {return path}
        proc check_timing args {
            if {$::scenario eq "unknown_format"} {return unexpected}
            if {$::scenario eq "unconstrained"} {return "1. checking unconstrained_internal_endpoints (1)"}
            return "1. checking no_clock (0)\n2. checking unconstrained_internal_endpoints (0)"
        }
        proc get_drc_checks args {return rule}
        proc get_drc_violations args {if {$::scenario eq "drc"} {return violation};return {}}
        proc write_bitstream args {set ::wrote 1}
    '''
    for scenario in ['success','route','slack','unconstrained','unknown_format','drc']:
        code=f'set scenario {scenario};set wrote 0;'+mocks+'\nset argv {};\n'
        code+='set failed [catch {'+source+'} message];list $failed $wrote'
        rc,msg=tcl_eval(code)
        assert rc==0 and msg==('0 1' if scenario=='success' else '1 0'),(scenario,rc,msg)
    print('PASS: real Tcl preflight for 4 modes; missing-Vivado error; 6 mocked build/bitstream-gate scenarios (not Vivado execution)')

def xdc_checks():
    text=(ROOT/'boards'/'arty_a7_100t'/'arty_a7_100t.xdc').read_text()
    mapping=dict((port,pin) for pin,port in re.findall(r'PACKAGE_PIN\s+(\w+)\s+IOSTANDARD LVCMOS33\}\s+\[get_ports\s+\{([^}]+)\}',text))
    expected={'clk':'E3','reset_n':'C2','uart_rx':'D10','uart_tx':'A9',
              'led[0]':'H5','led[1]':'J5','led[2]':'T9','led[3]':'T10'}
    assert mapping==expected and len(set(mapping.values()))==8
    assert len(re.findall(r'^create_clock ',text,re.M))==1 and '-period 10.000' in text
    net=json.loads((ROOT/'build'/'arty_synthesis.json').read_text())
    ports=net['modules']['arty_a7_top']['ports']
    expanded=set()
    for name,port in ports.items():
        if len(port['bits'])==1:expanded.add(name)
        else:expanded.update(f'{name}[{i}]' for i in range(len(port['bits'])))
        assert port['direction']==('input' if name in ('clk','reset_n','uart_rx') else 'output')
    assert expanded==set(mapping),'XDC and synthesized wrapper ports differ'
    print('PASS: 8 XDC pins match synthesized top ports/directions and recorded Digilent mapping; 10 ns clock')

def main():
    image_checks()
    command([sys.executable,'scripts/check_rtl.py','--arty'],'build/arty_rtl_checks.txt')
    xdc_checks();tcl_checks()
    simulate('uart_tb',['tb/soc/uart_tb.sv'],['-Puart_tb.CLOCK_HZ=100000000','-Puart_tb.BAUD=115200'],name='uart_arty_divider')
    simulate('arty_smoke_tb',[*BOARD_RTL,'tb/soc/uart_monitor.sv','tb/soc/arty_smoke_tb.sv'])
    rows={}
    for name,cpu,stem in [('arty',0,'board'),('arty_cpu',1,'board_cpu')]:
        log=f'build/{name}_uart.txt'
        simulate('arty_tb',[*BOARD_RTL,'tb/soc/uart_monitor.sv','tb/soc/arty_tb.sv'],
                 [f'-Party_tb.CPU_ONLY={cpu}',f'-Party_tb.ROM_HEX="build/firmware/{stem}_rom.hex"',
                  f'-Party_tb.RAM_HEX="build/firmware/{stem}_ram.hex"'],[f'+UART_LOG={log}'],name=name)
        rows[name]=board_uart(log,bool(cpu))
    (ROOT/'build'/'arty_benchmarks.json').write_text(json.dumps(rows,indent=2)+'\n')
    print('PASS: FPGA readiness checks; Vivado implementation and physical validation NOT RUN')

if __name__=='__main__':main()
