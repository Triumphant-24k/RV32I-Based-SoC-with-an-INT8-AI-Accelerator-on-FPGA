# CPU test programs

These are the small programs and tests used to check the CPU before integrating the accelerator.

The original smoke program is kept in `software/assembly/`, with its word-oriented memory image in `software/hex/`. The CPU unit and directed tests live in `tb/unit/` and `tb/core/`; the latter also includes generated arithmetic tests and memory-wait tests.

The accelerator demonstration has its own firmware in `firmware/` and system tests in `tb/soc/`. Those tests exercise the full path from CPU instructions to accelerator results and UART output.

The [verification summary](../../docs/VERIFICATION.md) records the results for both the reused CPU tests and the new system tests.
