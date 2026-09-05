#!/usr/bin/env sh
set -eu
CC="${RISCV_CC:-riscv64-unknown-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv64-unknown-elf-objcopy}"
mkdir -p build/programs
"$CC" -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -Wl,-Ttext=0 \
  -o build/programs/smoke.elf software/assembly/smoke.S
"$OBJCOPY" -O verilog --verilog-data-width=4 build/programs/smoke.elf software/hex/smoke.hex
