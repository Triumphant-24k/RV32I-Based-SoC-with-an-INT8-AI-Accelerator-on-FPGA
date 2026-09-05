#!/usr/bin/env python3
"""Execute the original testbenches without changing the imported CPU."""
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
CPU = [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'rtl').glob('*.v'))]

def main():
    out = ROOT / 'build' / 'baseline'
    out.mkdir(parents=True, exist_ok=True)
    logs = []
    for name, path in [('unit_tb', 'tb/unit/unit_tb.sv'),
                       ('core_tb', 'tb/core/core_tb.sv'),
                       ('memory_wait_tb', 'tb/core/memory_wait_tb.sv'),
                       ('generated_tb', 'tb/core/generated_tb.sv')]:
        cmd = ['iverilog', '-g2012', '-s', name, '-o', str(out / name), *CPU, path]
        subprocess.run(cmd, cwd=ROOT, check=True, timeout=60)
        run = subprocess.run(['vvp', str(out / name)], cwd=ROOT, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        print(run.stdout, end='')
        logs.append(run.stdout)
        run.check_returncode()
        if 'PASS:' not in run.stdout:
            raise RuntimeError('Missing PASS: ' + name)
    (out / 'results.txt').write_text(''.join(logs))

if __name__ == '__main__':
    main()
