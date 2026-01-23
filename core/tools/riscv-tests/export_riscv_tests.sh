#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-/work/test/hex/riscv-tests}"
BYTES_PER_LINE="${BYTES_PER_LINE:-4}"

SRC="/opt/riscv-tests-install/share/riscv-tests/isa"

mkdir -p "$OUTDIR" "$OUTDIR/bin" "$OUTDIR/elf"

shopt -s nullglob
for elf in "$SRC"/rv32ui-p-* "$SRC"/rv32mi-p-*; do
  base="$(basename "$elf")"
  cp -f "$elf" "$OUTDIR/elf/${base}.elf"
  riscv32-unknown-elf-objcopy -O binary "$elf" "$OUTDIR/bin/${base}.bin"
  python3 /usr/local/bin/bin2hex.py "$BYTES_PER_LINE" "$OUTDIR/bin/${base}.bin" > "$OUTDIR/${base}.hex"
done

echo "[OK] exported to: $OUTDIR"
