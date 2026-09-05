#!/usr/bin/env python3
"""One fail-fast regression entry point. All subprocess failures/timeouts propagate."""
import json
import pathlib
import re
import subprocess
import sys
from reference import cases
ROOT=pathlib.Path(__file__).resolve().parents[1]
CPU=[f'rtl/{n}.v' for n in ['alu','branch_unit','control_unit','cpu_core',
                           'immediate_generator','load_store_unit','register_file']]
SOC=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl'/'soc').glob('*.sv'))]

def command(cmd, logfile=None, timeout=180):
    print('+ '+' '.join(map(str,cmd)),flush=True)
    run=subprocess.run(list(map(str,cmd)),cwd=ROOT,text=True,stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT,timeout=timeout)
    if logfile: (ROOT/logfile).write_text(run.stdout)
    print(run.stdout, end='',flush=True)
    run.check_returncode()
    return run.stdout

def simulate(top, paths, params=(), args=(), name=None):
    name=name or top
    output=ROOT/'build'/name
    command(['iverilog','-g2012','-DSIM_ASSERT','-s',top,'-o',output,*params,*CPU,*SOC,*paths],f'build/{name}_compile.txt')
    result=command(['vvp',output,*args],f'build/{name}.txt')
    if 'PASS:' not in result: raise RuntimeError('Missing PASS: '+name)

def verify_uart(path, cpu_only=False):
    text=(ROOT/path).read_text()
    pattern=(r'CPU_TEST=([0-9a-f]{8}) SW=([0-9a-f]{8}) CPU=([0-9a-f]{8}) PASS'
             if cpu_only else r'TEST=([0-9a-f]{8}) SW=([0-9a-f]{8}) HW=([0-9a-f]{8}) CPU=([0-9a-f]{8}) ACC=([0-9a-f]{8}) E2E=([0-9a-f]{8}) PASS')
    lines=text.splitlines()
    overhead=re.fullmatch(r'COUNTER_READ_DELTA=([0-9a-f]{8})',lines[0])
    assert overhead and len(lines)==28 and 'FAIL' not in text, 'UART framing/content'
    rows=[]
    for case,line in zip(cases()[:26],lines[1:27]):
        m=re.fullmatch(pattern,line); assert m, f'Unexpected UART: {line}'
        vals=[int(x,16) for x in m.groups()]
        assert vals[0]==case['id'] and vals[1]==case['expected']&0xffffffff
        if not cpu_only:
            assert vals[2]==vals[1] and vals[4]==8 and vals[3]>0 and vals[5]>8
            rows.append(dict(id=case['id'],name=case['name'],result=case['expected'],
                             cpu=vals[3],compute=vals[4],e2e=vals[5],
                             compute_speedup=vals[3]/vals[4],e2e_speedup=vals[3]/vals[5]))
    assert lines[-1] == ('ALL CPU PASS' if cpu_only else 'ALL PASS')
    print(f'PASS: independently decoded UART {path}: 26 cases match Python reference')
    return dict(counter_read_delta=int(overhead.group(1),16),cases=rows)

def main():
    (ROOT/'build').mkdir(exist_ok=True)
    command([sys.executable,'scripts/baseline.py'],'build/baseline_regression.txt')
    command([sys.executable,'scripts/build_firmware.py'],'build/firmware_build.txt')
    simulate('accelerator_tb',['tb/soc/accelerator_tb.sv'])
    simulate('uart_tb',['tb/soc/uart_tb.sv'])
    results={}
    for name,stall,cpu_only in [('soc',0,0),('soc_stalls',1,0),('cpu_only',0,1)]:
        log=f'build/{name}_uart.txt'
        firmware='cpu' if cpu_only else 'demo'
        simulate('soc_tb',['tb/soc/uart_monitor.sv','tb/soc/soc_tb.sv'],
                 [f'-Psoc_tb.STALL_REQUESTS={stall}',f'-Psoc_tb.CPU_ONLY={cpu_only}',
                  f'-Psoc_tb.ROM_HEX="firmware/hex/{firmware}_rom.hex"',
                  f'-Psoc_tb.RAM_HEX="firmware/hex/{firmware}_ram.hex"'],
                 [f'+UART_LOG={log}'],name=name)
        results[name]=verify_uart(log,bool(cpu_only))
    (ROOT/'build'/'benchmarks.json').write_text(json.dumps(results,indent=2)+'\n')
    print('PASS: full simulation regression')

if __name__=='__main__': main()
