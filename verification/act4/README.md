# RISC-V architectural tests

This folder contains the ACT4 configuration carried over from my CPU project. It targets the unprivileged RV32I instruction set, with the upstream revision recorded in `PINNED_REVISION`.

Architectural certification tests have not been run for this SoC. The current verification results come from the CPU regression, accelerator tests, and CPU-driven firmware simulations described in the [verification summary](../../docs/VERIFICATION.md).

The inherited ACT4 setup uses a simulation-only status address of `0x0000fff0` for its pass/fail marker. It still needs a DUT execution adapter and validation against the current SoC memory map before it can contribute certification results.
