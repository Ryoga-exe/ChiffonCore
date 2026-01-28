import argparse
import os
import re
import subprocess
from pathlib import Path

from elftools.elf.elffile import ELFFile

PASS_PAT = re.compile(r"riscv-tests success!", re.IGNORECASE)
FAIL_PAT = re.compile(r"riscv-tests failed!", re.IGNORECASE)
XERR_PAT = re.compile(r"\b(ERROR|FATAL)\b", re.IGNORECASE)


def extract_sym_addr(elf_path: Path, sym_name: str) -> int | None:
    from elftools.elf.elffile import ELFFile
    from elftools.elf.sections import SymbolTableSection

    with elf_path.open("rb") as f:
        ef = ELFFile(f)
        for sec in ef.iter_sections():
            if not isinstance(sec, SymbolTableSection):
                continue
            for sym in sec.iter_symbols():
                if sym.name == sym_name:
                    return int(sym["st_value"])
    return None


def discover_snapshot(workdir: Path, preferred_prefix: str = "tb_riscv_tests") -> str:
    xsim_dir = workdir / "xsim.dir"
    if not xsim_dir.is_dir():
        raise FileNotFoundError(f"xsim.dir not found under workdir: {workdir}")

    candidates = sorted([p.name for p in xsim_dir.iterdir() if p.is_dir()])
    if not candidates:
        raise FileNotFoundError(f"No snapshot folders found in: {xsim_dir}")

    pref = [c for c in candidates if c.startswith(preferred_prefix)]
    if len(pref) == 1:
        return pref[0]
    if len(candidates) == 1:
        return candidates[0]
    raise RuntimeError(
        "Multiple snapshots found. Pass --snapshot explicitly. Candidates:\n  "
        + "\n  ".join(candidates)
    )


def to_posix_path(p: Path) -> str:
    """
    IMPORTANT (Windows + xsim):
      Backslashes in -testplusarg values may get eaten/escaped by xsim.
      Use forward slashes: C:/Users/... which Windows APIs accept.
    """
    s = str(p.resolve())
    return s.replace("\\", "/")


def run_one_shell(
    xsim_cmd: str,
    snapshot: str,
    workdir: Path,
    out_log: Path,
    timeout_s: float,
    plusargs: list[str],
    verbose: bool,
) -> tuple[bool, str, int | None]:
    pa = " ".join([f'--testplusarg "{a}"' for a in plusargs])
    cmd = f"{xsim_cmd} {snapshot} -R {pa}"
    if verbose:
        print(f"[CMD] {cmd}")

    out_log.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(out_log, "w", encoding="utf-8", errors="replace") as f:
            p = subprocess.run(
                cmd,
                cwd=str(workdir),
                shell=True,
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=None if timeout_s == 0 else timeout_s,
                check=False,
            )
            rc = p.returncode
    except subprocess.TimeoutExpired:
        with open(out_log, "a", encoding="utf-8", errors="replace") as f:
            f.write("\n[TIMEOUT]\n")
        return False, "TIMEOUT", None

    text = out_log.read_text(encoding="utf-8", errors="replace")
    if PASS_PAT.search(text):
        return True, "PASS", rc
    if FAIL_PAT.search(text):
        return False, "FAIL", rc
    if rc != 0 or XERR_PAT.search(text):
        return False, "ERROR", rc
    return False, "UNKNOWN", rc


def main() -> int:
    ap = argparse.ArgumentParser()

    ap.add_argument(
        "--xsim", default="xsim", help="xsim executable (xsim.bat or full path to it)"
    )
    ap.add_argument(
        "--workdir",
        default="simulation/simulation.sim/sim_1/behav/xsim",
        help="Vivado sim workdir (e.g. simulation/simulation.sim/sim_1/behav/xsim)",
    )
    ap.add_argument(
        "--snapshot",
        default=None,
        help="xsim snapshot name (folder under workdir/xsim.dir). If omitted, auto-detect.",
    )
    ap.add_argument(
        "--snapshot_prefix",
        default="tb_riscv_tests",
        help="auto-detect preference prefix",
    )

    ap.add_argument(
        "--dir", default="test/hex/riscv-tests", help="directory containing hex files"
    )
    ap.add_argument("--prefix", default="rv32ui-p-", help="test filename prefix")
    ap.add_argument("--ext", default=".hex", help="file extension (default .hex)")
    ap.add_argument("--recursive", action="store_true", help="search recursively")
    ap.add_argument("--results", default="results", help="output directory")
    ap.add_argument(
        "--time_limit",
        type=float,
        default=20.0,
        help="per-test timeout seconds (0 = no limit)",
    )
    ap.add_argument(
        "--verbose", action="store_true", help="print first command line(s)"
    )

    ap.add_argument("--membase", default="20000000")
    ap.add_argument("--entry", default="00000000")
    ap.add_argument("--tohost", default="80001000")
    ap.add_argument("--tohost_from_elf", action="store_true")
    ap.add_argument("--elfdir", default=None, help="default: <dir>/elf")
    ap.add_argument(
        "--tb_timeout",
        default="5000000",
        help="TB internal cycle timeout (TIMEOUT=...)",
    )

    args = ap.parse_args()

    workdir = Path(args.workdir).resolve()
    if not workdir.is_dir():
        print(f"[ERR] workdir not found: {workdir}")
        return 2

    snapshot = args.snapshot
    if snapshot is None:
        try:
            snapshot = discover_snapshot(workdir, args.snapshot_prefix)
        except Exception as e:
            print(f"[ERR] snapshot auto-detect failed: {e}")
            return 2

    tests_dir = Path(args.dir).resolve()
    if not tests_dir.is_dir():
        print(f"[ERR] tests dir not found: {tests_dir}")
        return 2

    out_dir = Path(args.results).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    files = (
        sorted(tests_dir.rglob(f"{args.prefix}*{args.ext}"))
        if args.recursive
        else sorted(tests_dir.glob(f"{args.prefix}*{args.ext}"))
    )
    if not files:
        print(f"[ERR] No tests found: {tests_dir} ({args.prefix}*{args.ext})")
        return 2

    print(f"[INFO] workdir  : {workdir}")
    print(f"[INFO] snapshot : {snapshot}")
    print(f"[INFO] tests    : {len(files)} files")
    print(f"[INFO] results  : {out_dir}")

    plusargs_base = [
        f"MEMBASE={args.membase}",
        f"ENTRY={args.entry}",
        f"TIMEOUT={args.tb_timeout}",
    ]

    results: list[tuple[str, bool, str, int | None, str]] = []

    for idx, f in enumerate(files):
        out_log = out_dir / f"{f.name}.log.txt"
        tohost_arg = args.tohost
        if args.tohost_from_elf:
            elfdir = Path(args.elfdir).resolve() if args.elfdir else (tests_dir / "elf")
            elf_path = elfdir / f"{f.stem}.elf"
            if elf_path.is_file():
                th = extract_sym_addr(elf_path, "tohost")
                if th is not None:
                    tohost_arg = format(th, "x")

        plusargs = plusargs_base + [
            f"TOHOST={tohost_arg}",
            f"HEX={str(to_posix_path(f))}",
        ]

        # print command only for the first test unless verbose
        show_cmd = args.verbose and idx < 3
        ok, status, rc = run_one_shell(
            args.xsim, snapshot, workdir, out_log, args.time_limit, plusargs, show_cmd
        )

        print(f"{status:7s} : {f.name}")
        results.append((f.name, ok, status, rc, str(out_log)))

    passed = sum(1 for _, ok, *_ in results if ok)
    total = len(results)
    summary = f"Test Result : {passed} / {total}"

    with open(out_dir / "result.txt", "w", encoding="utf-8") as w:
        w.write(summary + "\n")
        for name, ok, status, rc, logp in sorted(results, key=lambda x: x[0]):
            w.write(f"{status:7s} : {name} (rc={rc}) log={logp}\n")

    print(summary)
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
