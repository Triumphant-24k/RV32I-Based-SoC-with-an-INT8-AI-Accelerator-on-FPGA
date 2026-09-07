#!/usr/bin/env python3
"""Arty simulations, source/XDC/image checks, and Tcl contract tests (NOT Vivado)."""
import ctypes
import ctypes.util
import json
import os
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
    old_cwd=os.getcwd()
    try:
        if lib.Tcl_Init(interp):raise RuntimeError('Tcl initialization failed')
        rc=lib.Tcl_Eval(interp,code.encode())
        result=lib.Tcl_GetStringResult(interp).decode(errors='replace')
        return rc,result
    finally:
        lib.Tcl_DeleteInterp(interp)
        os.chdir(old_cwd)

def tcl_checks():
    source='source {'+str(ROOT/'boards'/'arty_a7_100t'/'build.tcl')+'}'
    # Start outside the repository, with spaces in the directory name, matching
    # a separate Vivado working directory rather than relying on the caller cwd.
    with tempfile.TemporaryDirectory(prefix='separate Vivado run ',dir=ROOT/'build') as temp:
        for demo in ['integrated','cpu','uart','led']:
            rc,msg=tcl_eval(f'cd {{{temp}}};set argv {{--check-only --demo {demo}}}; {source}')
            assert rc==0,msg
    rc,msg=tcl_eval('set argv {}; '+source)
    assert rc!=0 and 'Vivado is unavailable' in msg
    # Execute guard branches with explicit mocks. These are script contract tests,
    # never vendor-tool results; mock report files are redirected into build/tcl-contract.
    mocks=r'''
        proc puts args {}
        rename open real_open
        proc open {path args} {
            if {[string match */build/vivado/* $path]} {
                set path [file join $::root build tcl-contract $::scenario [file tail $path]]
                file mkdir [file dirname $path]
            }
            return [real_open $path {*}$args]
        }
        foreach cmd {report_utilization write_checkpoint
                     opt_design place_design phys_opt_design report_route_status report_timing_summary
                     report_clock_interaction report_cdc report_drc} {proc $cmd args {}}
        proc read_verilog {flag path} {
            if {$flag ne "-sv" || ![file isfile $path] || [string match */tb/* $path] ||
                [file tail $path] in {cpu_sim_top.v simulation_memory.v}} {error "Bad synthesis source $path"}
        }
        proc read_xdc {path} {if {![file isfile $path]} {error "Missing XDC"}}
        proc synth_design args {
            if {[pwd] ne [file join $::root build vivado arty_a7_100t integrated]} {error "Wrong build working directory"}
            foreach name {rom.hex ram.hex} {
                if {![file isfile $name] || [file size $name]==0} {error "Missing staged memory $name"}
            }
            foreach generic {{ROM_HEX="rom.hex"} {RAM_HEX="ram.hex"}} {
                if {[lsearch -exact [dict get $args -generic] $generic]<0} {error "Bad memory generic $generic"}
            }
        }
        proc route_design {} {if {$::scenario eq "route"} {error "mock route failure"}}
        proc get_parts args {return xc7a100tcsg324-1}
        proc get_ports args {return {clk reset_btn uart_rx uart_tx led[0] led[1] led[2] led[3]}}
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
    print('PASS: real Tcl preflight for 4 modes from separate directory; staged images/source paths; missing-Vivado error; 6 mocked bitstream gates (not Vivado execution)')

def programming_checks():
    source='source {'+str(ROOT/'scripts'/'program-arty.tcl')+'}'
    rc,msg=tcl_eval('set argv {--demo nonexistent};'+source)
    assert rc!=0 and 'Unknown demo' in msg
    # No file is created and no hardware API is called. All hardware commands and
    # bitstream metadata below are explicit mocks, including the success case.
    mocks=r'''
        proc puts args {}
        rename file real_file
        proc file {sub args} {
            if {[string match *.bit [lindex $args 0]]} {
                if {$sub eq "isfile"} {return [expr {$::scenario ne "missing"}]}
                if {$sub eq "size"} {return 16}
            }
            return [real_file $sub {*}$args]
        }
        proc open_hw_manager {} {incr ::opened}
        foreach cmd {connect_hw_server current_hw_target open_hw_target current_hw_device
                     refresh_hw_device set_property close_hw_manager} {proc $cmd args {}}
        proc get_hw_targets {} {if {$::scenario eq "targets"} {return {one two}};return one}
        proc get_hw_devices {} {if {$::scenario eq "devices"} {return {one two}};return one}
        proc get_property args {if {$::scenario eq "wrong"} {return xc7a35t};return xc7a100t}
        proc program_hw_devices args {incr ::programmed}
    '''
    for scenario in ['missing','dry','success','targets','devices','wrong']:
        argv='' if scenario=='dry' else '--program'
        code=f'set scenario {scenario};set opened 0;set programmed 0;'+mocks+f'\nset argv {{{argv}}};'
        code+='set failed [catch {'+source+'} message];list $failed $opened $programmed'
        rc,msg=tcl_eval(code)
        expected={'missing':'1 0 0','dry':'0 0 0','success':'0 1 1'}.get(scenario,'1 1 0')
        assert rc==0 and msg==expected,(scenario,rc,msg)
    print('PASS: 6 mocked manual-programming guards; default opens no hardware; no device programmed')

def xdc_checks():
    text=(ROOT/'boards'/'arty_a7_100t'/'arty_a7_100t.xdc').read_text()
    mapping=dict((port,pin) for pin,port in re.findall(r'PACKAGE_PIN\s+(\w+)\s+IOSTANDARD LVCMOS33\}\s+\[get_ports\s+\{([^}]+)\}',text))
    expected={'clk':'E3','reset_btn':'D9','uart_rx':'D10','uart_tx':'A9',
              'led[0]':'H5','led[1]':'J5','led[2]':'T9','led[3]':'T10'}
    assert mapping==expected and len(set(mapping.values()))==8
    assert re.search(r'set_property PULLUP true \[get_ports \{uart_rx\}\]',text)
    assert len(re.findall(r'^create_clock ',text,re.M))==1 and '-period 10.000' in text
    net=json.loads((ROOT/'build'/'arty_synthesis.json').read_text())
    ports=net['modules']['arty_a7_top']['ports']
    expanded=set()
    for name,port in ports.items():
        if len(port['bits'])==1:expanded.add(name)
        else:expanded.update(f'{name}[{i}]' for i in range(len(port['bits'])))
        assert port['direction']==('input' if name in ('clk','reset_btn','uart_rx') else 'output')
    assert expanded==set(mapping),'XDC and synthesized wrapper ports differ'
    print('PASS: 8 XDC pins match synthesized top ports/directions and recorded Digilent mapping; 10 ns clock')

def main():
    image_checks()
    command([sys.executable,'scripts/check_rtl.py','--arty'],'build/arty_rtl_checks.txt')
    xdc_checks();tcl_checks();programming_checks()
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
