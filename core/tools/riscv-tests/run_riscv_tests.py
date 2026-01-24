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


def run_one(xsim_cmd, snapshot, hexfile, out_log, timeout_s, plusargs):
    # xsim plusargs:
    #   xsim <snapshot> -R --testplusarg HEX=... --testplusarg ENTRY=... ...
    cmd = []
    if isinstance(xsim_cmd, str):
        xsim_cmd = [xsim_cmd]

    if len(xsim_cmd) == 1 and is_windows_bat(xsim_cmd[0]):
        cmd = ["cmd", "/c"] + xsim_cmd + [snapshot, "-R"]
    else:
        cmd = xsim_cmd + [snapshot, "-R"]

    for a in plusargs:
        cmd += ["--testplusarg", a]

    with open(out_log, "w", encoding="utf-8", errors="replace") as f:
        try:
            p = subprocess.run(
                cmd,
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=None if timeout_s == 0 else timeout_s,
                check=False,
            )
            rc = p.returncode
        except subprocess.TimeoutExpired:
            f.write("\n[TIMEOUT]\n")
            return False, "TIMEOUT", None

    text = Path(out_log).read_text(encoding="utf-8", errors="replace")
    if PASS_PAT.search(text):
        return True, "PASS", rc
    if FAIL_PAT.search(text):
        return False, "FAIL", rc

    return False, "UNKNOWN", rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--xsim",
        default="xsim",
        help="xsim executable (e.g. .../Vivado/2024.2/bin/xsim.bat)",
    )
    ap.add_argument(
        "--snapshot",
        required=True,
        help="xsim snapshot name (e.g. tb_riscv_tests_behav)",
    )
    ap.add_argument("--dir", required=True, help="directory containing hex files")
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

    ap.add_argument("--membase", default="20000000")
    ap.add_argument("--entry", default="00000000")
    ap.add_argument("--tohost", default="00001000")
    ap.add_argument(
        "--tb_timeout",
        default="5000000",
        help="TB internal cycle timeout (TIMEOUT=...)",
    )

    args = ap.parse_args()

    tests_dir = Path(args.dir)
    out_dir = Path(args.results)
    out_dir.mkdir(parents=True, exist_ok=True)

    # file list
    if args.recursive:
        files = sorted(tests_dir.rglob(f"{args.prefix}*{args.ext}"))
    else:
        files = sorted(tests_dir.glob(f"{args.prefix}*{args.ext}"))

    if not files:
        print(f"No tests found: {tests_dir} ({args.prefix}*{args.ext})")
        return 2

    plusargs_base = [
        f"MEMBASE={args.membase}",
        f"ENTRY={args.entry}",
        f"TOHOST={args.tohost}",
        f"TIMEOUT={args.tb_timeout}",
    ]

    results = []
    for f in files:
        log_name = f.name.replace(os.sep, "_") + ".log.txt"
        out_log = out_dir / log_name

        plusargs = plusargs_base + [f"HEX={str(f.resolve())}"]
        ok, status, rc = run_one(
            args.xsim, args.snapshot, f, out_log, args.time_limit, plusargs
        )

        print(f"{status:7s} : {f.name}")
        results.append((f.name, ok, status, rc, str(out_log)))

    # summary
    passed = sum(1 for _, ok, *_ in results if ok)
    total = len(results)
    summary = f"Test Result : {passed} / {total}"

    # stable sort by filename
    results_sorted = sorted(results, key=lambda x: x[0])

    with open(out_dir / "result.txt", "w", encoding="utf-8") as w:
        w.write(summary + "\n")
        for name, ok, status, rc, logp in results_sorted:
            w.write(f"{status:7s} : {name} (rc={rc}) log={logp}\n")

    print(summary)
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
