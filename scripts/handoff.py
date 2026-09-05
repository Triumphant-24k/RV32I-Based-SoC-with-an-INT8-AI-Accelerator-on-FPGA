#!/usr/bin/env python3
"""Publish current, successfully completed regression evidence into tracked reports."""
import json
import pathlib
import shutil
import subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]

def main():
    target=ROOT/'reports';target.mkdir(exist_ok=True)
    names=['reuse','baseline_regression','firmware_build','accelerator_tb','uart_tb',
           'bus_tb','board_tb','soc','soc_stalls','cpu_only','rtl_checks']
    summaries=[]
    for name in names:
        data=(ROOT/'build'/f'{name}.txt').read_text()
        assert 'PASS' in data and 'FATAL:' not in data, 'Incomplete evidence: '+name
        summaries.extend(line for line in data.splitlines() if line.startswith('PASS') or 'opcode audit PASS' in line)
    (target/'regression.txt').write_text('\n'.join(summaries)+'\n')
    for name in ['soc_uart.txt','soc_stalls_uart.txt','cpu_only_uart.txt','benchmarks.json','synthesis_summary.json']:
        shutil.copyfile(ROOT/'build'/name,target/name)
    for name in ['demo.audit.txt','cpu.audit.txt','demo.dis','cpu.dis','toolchain.txt']:
        shutil.copyfile(ROOT/'build'/'firmware'/name,target/name)
    versions=[]
    for cmd in [['iverilog','-V'],['verilator','--version'],['yosys','-V'],['riscv64-unknown-elf-gcc','--version'],['python3','--version']]:
        p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,check=True)
        versions.append(p.stdout.splitlines()[0])
    (target/'tools.txt').write_text('\n'.join(versions)+'\n')
    benchmarks=json.loads((ROOT/'build'/'benchmarks.json').read_text())
    md=['# Measured simulation benchmarks','',
        'Generated from the CPU firmware UART stream, decoded from TX bits in Icarus Verilog.',
        'All results were independently compared to Python integer arithmetic. No FPGA measurement is claimed.','',
        '## Measurement definitions','',
        '- CPU: cycle-counter delta around the runtime software dot product, including function/call/loop overhead.',
        '- ACC: accepted start to completion; exactly eight subsequent clock edges, one signed product per edge.',
        '- E2E: cycle-counter delta including all 16 input MMIO writes, start, polling, and result read.',
        '- Input case preparation and all UART formatting/transmission are outside both timed regions.',
        '- The 32-bit SoC counter increments every clock, including memory stalls. Unsigned subtraction handles one wrap.',
        '- Deltas are raw: counter-read overhead is retained, not subtracted. Back-to-back reads are reported below.',
        '- Compute-only ratio is CPU/ACC; end-to-end ratio is CPU/E2E. The former excludes data movement.',
        '- The software baseline uses a bounded eight-round shift/add multiply for each signed byte pair. It is a reproducible reference, not a claim of optimal RV32I software.',
        '- Testbench timing parameters are 1 MHz clock / 100 kbaud (10 clocks per UART bit), not an allocated board clock. Cycle ratios do not depend on UART printing.','']
    for key,title in [('soc','Synchronous memory, no request backpressure'),('soc_stalls','Synchronous memory with seeded request backpressure')]:
        data=benchmarks[key];rows=data['cases']
        md += [f'## {title}','',f"Back-to-back counter-read delta: **{data['counter_read_delta']} cycles**.",'',
               '| ID | Case | Signed result | CPU | ACC | E2E | CPU/ACC | CPU/E2E |',
               '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |']
        for r in rows:
            md.append(f"| {r['id']} | {r['name']} | {r['result']} | {r['cpu']} | {r['compute']} | {r['e2e']} | {r['compute_speedup']:.2f}x | {r['e2e_speedup']:.2f}x |")
        sw=sum(r['cpu'] for r in rows);acc=sum(r['compute'] for r in rows);e2e=sum(r['e2e'] for r in rows)
        md += ['',f'Ratio of summed measured cycles: CPU/ACC **{sw/acc:.2f}x**, CPU/E2E **{sw/e2e:.2f}x**.',
               'These ratios describe only these 26 vectors, this CPU, firmware, and memory configuration.','']
    (target/'BENCHMARKS.md').write_text('\n'.join(md)+'\n')
    print('PASS: reproducible handoff reports generated from current regression outputs')

if __name__=='__main__': main()
