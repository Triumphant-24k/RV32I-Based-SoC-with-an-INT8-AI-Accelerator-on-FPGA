# Test programs

`software/assembly/` contains human-readable assembly and `software/hex/`
contains word-oriented hexadecimal images accepted by `simulation_memory`.
The checked-in smoke image is hand-encoded so it can run without a cross
compiler. Rebuild images with `scripts/build-programs.sh` after installing a
RISC-V GNU toolchain.

Internal directed tests live under `tb/unit` and `tb/core`. No random tests or
official architectural tests are currently claimed.
