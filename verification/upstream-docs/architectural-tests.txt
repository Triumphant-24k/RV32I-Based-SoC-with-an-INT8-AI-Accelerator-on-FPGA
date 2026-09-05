# Official architectural-test integration

This directory targets the authoritative RISC-V Architectural Certification
Tests (ACT4), pinned in `PINNED_REVISION`. RISCOF is intentionally not used
because upstream now marks it deprecated in favor of ACT4.

The configuration limits generation to the unprivileged `I` extension and
excludes privileged tests. The DUT halt macro writes `1` (pass) or `2` (fail)
to the simulation-only address `0x0000fff0`. This configuration must pass ACT4
schema validation before its results can be treated as architectural-test
evidence.

Required tools are GNU Make, Git, Python 3.10+, the ACT4 Python/Ruby/UDB
dependencies, `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-objdump`, and
`sail_riscv_sim` 0.13.1. Run `make isa-test` from WSL/Linux after installing
them. Until the generated self-checking ELFs run on the DUT and all report
pass, the project status remains **official architectural tests: NOT RUN**.
