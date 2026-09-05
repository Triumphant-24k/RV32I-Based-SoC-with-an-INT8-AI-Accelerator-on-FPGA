# riscv-int8-ai-accelerator

Pre-FPGA preparation for the September 7–8, 2026 Design & Verification hackathon:
an RV32I SoC executing firmware that drives an eight-element signed INT8 dot-product accelerator.
This is an accelerator for an AI computation kernel, not a trained ANN classifier.
Competition permission to reuse existing code has not been confirmed. No FPGA validation is claimed.

## CPU provenance

Source: https://github.com/Triumphant-24k/riscv-r32-processor-v2

Exact source commit: `64977acc99bfd37eb6c43121e6377a9b47105b72`.
Reused without replacing the CPU: `rtl/{alu,branch_unit,control_unit,cpu_core,immediate_generator,load_store_unit,register_file}.v`,
the simulation wrapper/memory, `tb/core`, `tb/unit`, `software`, relevant upstream scripts,
and `formal` / `verification/act4` support. These components retain the MIT licence
and copyright (c) 2026 Shiv Sriram in LICENSE. No original Git history, credentials,
legacy core, physical-design reports, cached results, or build products were imported.
This repository starts with the user's independent initial commit.

All 30 imported files (including LICENSE) are checked against their original Git
blob IDs by `scripts/check_reuse.py`. CPU RTL and upstream tests remain unchanged.
New components are `rtl/soc`, `rtl/board`, `firmware`, `tb/soc`, the Python build and
regression scripts, reference vectors, board templates, and the handoff documents.

## Current status and full regression

**Simulation-verified:** the real CPU executes 26 firmware cases successfully,
both with normal synchronous memory and with deterministic request backpressure.
Serial TX bits are decoded and independently checked against Python results.
The CPU-only firmware also passes all 26 cases. This is not FPGA-validated.

From PowerShell in this repository, run the entire available regression:

```powershell
.\scripts\run-regression.ps1
```

From Linux / Ubuntu WSL in this repository, the equivalent command is:

```sh
python3 scripts/regress.py
```

Both propagate a nonzero status if any required test, firmware build, UART check,
lint, or portable synthesis check fails. The PowerShell wrapper defaults to
Ubuntu-22.04; use `-Distribution` for another configured WSL distribution.
Required Linux packages: `python3 make iverilog verilator yosys
gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf`. The tested versions are in
`reports/tools.txt`. No proprietary simulator or Python package is needed.

The command rebuilds firmware and reference vectors, audits emitted instructions,
runs the CPU baseline, accelerator/MMIO/UART/board tests and three CPU firmware
simulations, then runs fatal lint and Yosys process/memory synthesis checks.
Temporary outputs go to ignored `build/`. Firmware ROM/RAM hex files and selected
results/disassemblies in `reports/` are intentionally tracked for the handoff.

The accelerator takes **8 compute cycles**. In the no-backpressure simulation,
the full accelerated region takes **385 cycles**, including input MMIO transfers,
start, polling and the result read. Per-case CPU cycle measurements and both
speedup definitions are in `reports/BENCHMARKS.md`; they are simulation results
for the specific bounded shift/add software baseline, not promises for other CPUs.

## Handoff map

| Deliverable | Location |
| --- | --- |
| Register, transaction and arithmetic specification | `docs/SPEC.md` |
| Architecture diagram, memory/reset/stack details | `docs/ARCHITECTURE.md` |
| Accelerator, bus, UART and SoC RTL | `rtl/soc/` |
| Portable FPGA, LED and UART wrappers | `rtl/board/` |
| C firmware, startup, linker script, initialization images | `firmware/` |
| Independent vectors/reference model | `verification/vectors/`, `scripts/reference.py` |
| Assertions and self-checking tests | `rtl/soc/int8_accelerator.sv`, `tb/soc/` |
| Actual verification results and limitations | `docs/VERIFICATION.md`, `reports/regression.txt` |
| Raw serial logs, disassembly, benchmark tables | `reports/` |
| Board config and pin templates | `boards/` |
| Vendor synthesis preparation (not yet vendor-tested) | `scripts/vivado_prepare.tcl` |
| Hardware bring-up and demo/task split | `docs/BRINGUP.md`, `docs/DEMO.md` |

## Private GitHub upload

The local repository is complete. At handoff, GitHub CLI was unauthenticated,
no Git remote was configured, and the available connector had no repository-create
operation. Nothing was pushed. After signing into the intended GitHub account:

```powershell
gh auth login
gh repo create Triumphant-24k/riscv-int8-ai-accelerator --private --source . --remote origin --push
```

Run from this repository. `gh repo create` must create a NEW repository; if that
name already exists, stop and inspect it. Do not substitute a force push or upload
into an existing repository. The source CPU repository must remain untouched.

## Baseline regression

On Linux or Ubuntu WSL with Python 3 and Icarus Verilog:

```sh
python3 scripts/baseline.py
```

The copied source CPU uses an asynchronous active-high reset, starts at PC 0,
and halts on a reported trap. It implements base RV32I including signed LB/LH,
LW, byte strobes for stores, shifts, branches, JAL/JALR, and FENCE. MUL, compressed
instructions, counter CSRs, interrupts, and a trap handler are not provided.
Stores complete on `valid && ready`; reads may respond at acceptance or later.
The upstream simulation memory uses separate 4 KiB instruction/data spaces at zero;
the new SoC will give firmware a unified, non-overlapping instruction/data map.
