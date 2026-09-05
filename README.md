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

New project components will be recorded below as they are implemented and tested.

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
