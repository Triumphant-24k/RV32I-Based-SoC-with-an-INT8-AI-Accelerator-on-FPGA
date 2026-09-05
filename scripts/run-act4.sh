#!/usr/bin/env sh
set -eu
revision=4281ead674c5e36fe5f6b73b4a5854b25037c3cf
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dependency="$root/build/deps/riscv-arch-test"
missing=""
for tool in make git python3 ruby bundle riscv64-unknown-elf-gcc riscv64-unknown-elf-objdump sail_riscv_sim; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  echo "ACT4 NOT RUN: missing required executable(s):$missing" >&2
  exit 2
fi
if [ ! -d "$dependency/.git" ]; then
  git clone https://github.com/riscv/riscv-arch-test.git "$dependency"
fi
git -C "$dependency" fetch origin "$revision"
git -C "$dependency" checkout --detach "$revision"
actual=$(git -C "$dependency" rev-parse HEAD)
[ "$actual" = "$revision" ] || { echo "ACT4 revision mismatch: $actual" >&2; exit 2; }
make -C "$dependency" CONFIG_FILES="$root/verification/act4/test_config.yaml" EXTENSIONS=I
echo "ACT4 ELF generation completed. DUT execution adapter is required before PASS may be reported." >&2
exit 2
