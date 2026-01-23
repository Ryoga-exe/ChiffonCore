#!/usr/bin/env bash
set -euo pipefail

# ---- knobs ----
# 1 行あたり何バイトで hex 化するか
BYTES_PER_LINE="${BYTES_PER_LINE:-4}"

# ホストへ吐くディレクトリ
OUT_BASE="${OUT_BASE:-/work/test/hex/riscv-tests}"

SRC="/opt/riscv-tests-install/share/riscv-tests/isa"

mkdir -p "${OUT_BASE}" "${OUT_BASE}/elf" "${OUT_BASE}/bin"

echo "[*] exporting riscv-tests (RV32) into: ${OUT_BASE}"
echo "[*] bytes/line for hex: ${BYTES_PER_LINE}"

shopt -s nullglob

# rv32*-p-* を対象（env/p のテスト群）
for elf in "${SRC}"/rv32*-p-*; do
  base="$(basename "${elf}")"

  # 保存（ELF）
  cp -f "${elf}" "${OUT_BASE}/elf/${base}.elf"

  # ELF -> raw bin
  riscv64-unknown-elf-objcopy -O binary "${elf}" "${OUT_BASE}/bin/${base}.bin"

  # raw bin -> hex format
  python3 /usr/local/bin/bin2hex.py "${BYTES_PER_LINE}" "${OUT_BASE}/bin/${base}.bin" > "${OUT_BASE}/${base}.hex"
done

echo "[+] done."
echo "    hex : ${OUT_BASE}/*.hex"
echo "    bin : ${OUT_BASE}/bin/*.bin"
echo "    elf : ${OUT_BASE}/elf/*.elf"
