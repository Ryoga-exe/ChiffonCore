#!/usr/bin/env python3
import re
import sys
from pathlib import Path

LINKER_SCRIPT = Path("env/p/link.ld")


def main() -> int:
    if not LINKER_SCRIPT.exists():
        print(f"error: not found: {LINKER_SCRIPT}", file=sys.stderr)
        return 2

    s = LINKER_SCRIPT.read_text(encoding="utf-8")

    # ". = 0x........;" を最初の1回だけ 0x00000000 にする
    pat = r"(?m)^[ \t]*\.[ \t]*=[ \t]*0x[0-9A-Fa-f_]+[ \t]*;"
    repl = ". = 0x00000000;"

    s2, n = re.subn(pat, repl, s, count=1)

    if n != 1:
        print(
            f"error: expected to patch 1 occurrence, but patched {n}", file=sys.stderr
        )
        return 3

    if s2 == s:
        print("warning: content unchanged (already patched?)", file=sys.stderr)

    LINKER_SCRIPT.write_text(s2, encoding="utf-8")
    print(f"patched: {LINKER_SCRIPT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
