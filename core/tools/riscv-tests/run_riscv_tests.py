import argparse
import os
import re
import subprocess
from pathlib import Path

PASS_PAT = re.compile(r"riscv-tests success!", re.IGNORECASE)
FAIL_PAT = re.compile(r"riscv-tests failed!", re.IGNORECASE)


def is_windows_bat(path: str) -> bool:
    p = path.lower()
    return p.endswith(".bat") or p.endswith(".cmd")


def discover_snapshot(
    workdir: Path, preferred_prefix: str | None = "tb_riscv_tests"
) -> str:
    """
    Vivado sim workdir layout (example):
      simulation/simulation.sim/sim_1/behav/xsim/
        xsim.dir/
          <snapshot_name>/
            xsimk.exe ...
    We pick:
      - if preferred_prefix matches exactly one folder -> that
      - else if only one folder exists -> that
      - else raise with candidates
    """
    xsim_dir = workdir / "xsim.dir"
    if not xsim_dir.is_dir():
        raise FileNotFoundError(f"xsim.dir not found under workdir: {workdir}")

    candidates = sorted([p.name for p in xsim_dir.iterdir() if p.is_dir()])
    if not candidates:
        raise FileNotFoundError(f"No snapshot folders found in: {xsim_dir}")

    if preferred_prefix:
        pref = [c for c in candidates if c.startswith(preferred_prefix)]
        if len(pref) == 1:
            return pref[0]

    if len(candidates) == 1:
        return candidates[0]

    # If many, show them so user can pass --snapshot explicitly
    raise RuntimeError(
        "Multiple snapshots found. Pass --snapshot explicitly. Candidates:\n  "
        + "\n  ".join(candidates)
    )


def run_one(
    xsim_cmd: str,
    snapshot: str,
    out_log: Path,
    timeout_s: float,
    plusargs: list[str],
    workdir: Path,
) -> tuple[bool, str, int | None]:
    """
    Runs one xsim invocation in `workdir`.
      xsim <snapshot> -R --testplusarg KEY=VAL ...
    Returns (ok, status_str, returncode_or_None)
    """
    # Build command list (no shell).
    # If xsim_cmd is a .bat/.cmd, run via cmd /c.
    if is_windows_bat(xsim_cmd):
        cmd = ["cmd", "/c", xsim_cmd, snapshot, "-R"]
    else:
        cmd = [xsim_cmd, snapshot, "-R"]

    for a in plusargs:
        cmd += ["--testplusarg", a]

    out_log.parent.mkdir(parents=True, exist_ok=True)

    try:
        with open(out_log, "w", encoding="utf-8", errors="replace") as f:
            p = subprocess.run(
                cmd,
                cwd=str(workdir),
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=None if timeout_s == 0 else timeout_s,
                check=False,
            )
            rc = p.returncode
    except subprocess.TimeoutExpired:
        # Append timeout marker
        with open(out_log, "a", encoding="utf-8", errors="replace") as f:
            f.write("\n[TIMEOUT]\n")
        return False, "TIMEOUT", None

    text = out_log.read_text(encoding="utf-8", errors="replace")
    if PASS_PAT.search(text):
        return True, "PASS", rc
    if FAIL_PAT.search(text):
        return False, "FAIL", rc
    return False, "UNKNOWN", rc


def main() -> int:
    ap = argparse.ArgumentParser()

    # Vivado xsim
    ap.add_argument(
        "--xsim",
        required=True,
        help="xsim executable (e.g. C:\\Xilinx\\Vivado\\2024.2\\bin\\xsim.bat or just 'xsim')",
    )
    ap.add_argument(
        "--workdir",
        required=True,
        help=r"Vivado sim workdir (e.g. simulation\simulation.sim\sim_1\behav\xsim)",
    )
    ap.add_argument(
        "--snapshot",
        default=None,
        help="xsim snapshot name (folder under workdir/xsim.dir). If omitted, auto-detect.",
    )
    ap.add_argument(
        "--snapshot_prefix",
        default="tb_riscv_tests",
        help="auto-detect: prefer snapshots starting with this prefix",
    )

    # Test files
    ap.add_argument("--dir", required=True, help="directory containing hex files")
    ap.add_argument(
        "--prefix", default="rv32ui-p-", help="test filename prefix (default rv32ui-p-)"
    )
    ap.add_argument("--ext", default=".hex", help="file extension (default .hex)")
    ap.add_argument("--recursive", action="store_true", help="search recursively")
    ap.add_argument("--results", default="results", help="output directory")
    ap.add_argument(
        "--time_limit",
        type=float,
        default=20.0,
        help="per-test timeout seconds (0 = no limit)",
    )

    # TB plusargs (match your tb_riscv_tests.sv)
    ap.add_argument("--membase", default="20000000")
    ap.add_argument("--entry", default="00000000")
    ap.add_argument("--tohost", default="00001000")
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

    if args.recursive:
        files = sorted(tests_dir.rglob(f"{args.prefix}*{args.ext}"))
    else:
        files = sorted(tests_dir.glob(f"{args.prefix}*{args.ext}"))

    if not files:
        print(f"[ERR] No tests found: {tests_dir} ({args.prefix}*{args.ext})")
        return 2

    plusargs_base = [
        f"MEMBASE={args.membase}",
        f"ENTRY={args.entry}",
        f"TOHOST={args.tohost}",
        f"TIMEOUT={args.tb_timeout}",
    ]

    print(f"[INFO] workdir  : {workdir}")
    print(f"[INFO] snapshot : {snapshot}")
    print(f"[INFO] tests    : {len(files)} files")
    print(f"[INFO] results  : {out_dir}")

    results: list[tuple[str, bool, str, int | None, str]] = []

    for f in files:
        log_name = f"{f.name}.log.txt"
        out_log = out_dir / log_name

        plusargs = plusargs_base + [f"HEX={str(f)}"]
        ok, status, rc = run_one(
            args.xsim, snapshot, out_log, args.time_limit, plusargs, workdir
        )

        print(f"{status:7s} : {f.name}")
        results.append((f.name, ok, status, rc, str(out_log)))

    passed = sum(1 for _, ok, *_ in results if ok)
    total = len(results)
    summary = f"Test Result : {passed} / {total}"

    # sort for stable report
    results_sorted = sorted(results, key=lambda x: x[0])

    with open(out_dir / "result.txt", "w", encoding="utf-8") as w:
        w.write(summary + "\n")
        for name, ok, status, rc, logp in results_sorted:
            w.write(f"{status:7s} : {name} (rc={rc}) log={logp}\n")

    print(summary)
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
