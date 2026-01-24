#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-/work/test/hex/riscv-tests}"
BYTES_PER_LINE="${BYTES_PER_LINE:-4}"
SRC="/opt/riscv-tests-install/share/riscv-tests/isa"

mkdir -p "$OUTDIR" "$OUTDIR/bin" "$OUTDIR/elf"

shopt -s nullglob
for f in \
  "$SRC"/rv32ui-p-* "$SRC"/rv32mi-p-* \
  "$SRC"/rv64ui-p-* "$SRC"/rv64mi-p-* \
; do
  case "$f" in
    *.dump|*.hex|*.bin|*.elf|*.o|*.S|*.ld) continue ;;
  esac

  if ! riscv64-unknown-elf-readelf -h "$f" >/dev/null 2>&1; then
    continue
  fi

  base="$(basename "$f")"
  cp -f "$f" "$OUTDIR/elf/${base}.elf"
  riscv64-unknown-elf-objcopy -O binary "$f" "$OUTDIR/bin/${base}.bin"
  python3 /usr/local/bin/bin2hex.py "$BYTES_PER_LINE" "$OUTDIR/bin/${base}.bin" > "$OUTDIR/${base}.hex"
done

echo "[OK] exported to: $OUTDIR"
