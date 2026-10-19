"""Run unchanged Godot domain battles in independent headless processes."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
from project import find_godot, process_environment


def drift() -> list[str]:
    baseline = json.loads((OUT / "baseline.json").read_text("utf-8"))
    return [name for name, digest in baseline["files"].items()
            if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--levels", required=True)
    parser.add_argument("--count", type=int, required=True)
    parser.add_argument("--first-seed", type=int, required=True)
    parser.add_argument("--policy", choices=["recruit_quality", "random"], default="recruit_quality")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    assert args.count > 0 and args.workers > 0
    assert args.name.replace("_", "").isalnum()
    assert not drift(), "Gameplay files changed since baseline"
    baseline = json.loads((OUT / "baseline.json").read_text("utf-8"))
    engine = find_godot()
    assert engine
    levels = [int(part) for part in args.levels.split(",")]

    def worker(index: int, count: int, first: int) -> dict:
        stem = f"{args.name}_{index}"
        data_path = OUT / f"{stem}.jsonl"
        log_path = OUT / f"{stem}.log"
        command = [engine, "--headless", "--language", "en", "--path", str(ROOT), "--script",
                   "res://validation/defense/win_rate_20261015/simulate.gd", "--", args.levels,
                   str(count), str(first), args.policy, data_path.as_posix()]
        with log_path.open("w", encoding="utf-8", newline="\n") as log:
            completed = subprocess.run(command, cwd=ROOT, env=process_environment(), stdout=log,
                                       stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        text = log_path.read_text("utf-8")
        assert completed.returncode == 0 and not any(marker in text for marker in
               ["SCRIPT ERROR", "ERROR:", "Assertion failed"]), log_path
        rows = [json.loads(line) for line in data_path.read_text("utf-8").splitlines()]
        assert len(rows) == len(levels) * count and all(row["finished"] for row in rows), data_path
        summary = {"worker": index, "runs": len(rows), "results": {
            str(level): {"n": count, "wins": sum(row["won"] for row in rows if row["level"] == level)}
            for level in levels}}
        print(json.dumps(summary), flush=True)
        return summary

    jobs = []
    offset = 0
    summaries = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for index in range(min(args.workers, args.count)):
            count = args.count // args.workers + int(index < args.count % args.workers)
            jobs.append(pool.submit(worker, index, count, args.first_seed + offset))
            offset += count
        for job in as_completed(jobs):
            summaries.append(job.result())
    changed = drift()
    status = {"arguments": vars(args), "summaries": summaries, "source_drift": changed, "baseline": baseline}
    (OUT / f"{args.name}.status.json").write_text(
        json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    assert not changed, changed


if __name__ == "__main__":
    main()
