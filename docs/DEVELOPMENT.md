# Development notes

## Full regression

From PowerShell in the repository:

```powershell
.\scripts\run-regression.ps1
```

The wrapper uses Ubuntu-22.04 in WSL. Its `-Distribution` parameter selects another installed distribution.

The equivalent Linux command is:

```sh
python3 scripts/regress.py
```

The regression rebuilds firmware and reference vectors, audits the generated instructions, checks CPU provenance, and runs the CPU, accelerator, bus, UART, and board-wrapper tests. It also runs Verilator lint and portable Yosys synthesis checks. A required check failing produces a nonzero exit status.

## Tools

Linux packages:

```text
python3 make iverilog verilator yosys
gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

The tested versions are recorded in `reports/tools.txt`. The regression does not require a proprietary simulator or additional Python packages.

## Individual checks

```sh
python3 scripts/baseline.py
python3 scripts/build_firmware.py
python3 scripts/check_rtl.py
```

Temporary files go into ignored `build/`. Firmware memory images and selected logs, disassemblies, and benchmark results are tracked for reproducibility. The complete regression refreshes those reports after its checks succeed.

## Reused source records

`verification/cpu-provenance.json` records the source commit and original Git blob IDs. The two imported test READMEs were rewritten for this project; their original contents are preserved in `verification/upstream-docs/`. The manifest's `preserved_documentation` mapping connects each original path to its preserved copy. The other imported files remain at their original paths.

`scripts/check_reuse.py` checks all 30 original contents, including those two preserved copies. The README edits do not change the CPU RTL, firmware support, or testbench provenance.

Board-specific setup is covered separately in [BRINGUP.md](BRINGUP.md). Competition permission to reuse the CPU has not yet been confirmed.
