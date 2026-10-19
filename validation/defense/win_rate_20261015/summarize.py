"""Summarize completed, error-free batches; never mix policy denominators."""
from __future__ import annotations

from collections import Counter
import json
from math import sqrt
from pathlib import Path
from statistics import median
import sys

OUT = Path(__file__).resolve().parent


def wilson(wins: int, total: int) -> list[float]:
    z = 1.959963984540054
    p = wins / total
    den = 1 + z * z / total
    center = (p + z * z / (2 * total)) / den
    half = z * sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / den
    return [round(100 * (center - half), 2), round(100 * (center + half), 2)]


def main(names: list[str]) -> None:
    rows = []
    for name in names:
        status = json.loads((OUT / f"{name}.status.json").read_text("utf-8"))
        assert not status["source_drift"]
        for item in status["summaries"]:
            path = OUT / f"{name}_{item['worker']}.jsonl"
            for line in path.read_text("utf-8").splitlines():
                row = json.loads(line)
                row["baseline_sha256"] = status["baseline"]["combined_sha256"]
                rows.append(row)
    unique = {(row["level"], row["seed"], row["policy"], row["baseline_sha256"]) for row in rows}
    assert len(unique) == len(rows), "Duplicate simulation seeds in the same condition"
    summary = []
    for level, policy, baseline in sorted({(r["level"], r["policy"], r["baseline_sha256"]) for r in rows}):
        part = [r for r in rows if r["level"] == level and r["policy"] == policy and r["baseline_sha256"] == baseline]
        wins = sum(row["won"] for row in part)
        losses = [row for row in part if not row["won"]]
        diagnostics = Counter()
        for row in part:
            diagnostics.update(row["diagnostics"])
        by_opening = {}
        for hero in sorted({row["heroes"][0]["id"] for row in part}):
            subset = [row for row in part if row["heroes"][0]["id"] == hero]
            by_opening[str(hero)] = {"n": len(subset), "wins": sum(row["won"] for row in subset)}
        summary.append({"level": level, "policy": policy, "baseline_sha256": baseline, "n": len(part), "wins": wins,
                        "win_rate_percent": round(100 * wins / len(part), 2),
                        "wilson_95_percent": wilson(wins, len(part)),
                        "finished": all(row["finished"] for row in part),
                        "median_loss_wave": median(row["wave"] for row in losses) if losses else None,
                        "median_duration_seconds": median(row["time_ms"] for row in part) / 1000,
                        "five_heroes_runs": sum(len(row["heroes"]) == 5 for row in part),
                        "by_opening_hero": by_opening, "diagnostics": dict(diagnostics)})
    output = {"batches": names, "total_runs": len(rows), "summary": summary}
    (OUT / "summary.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n",
                                      encoding="utf-8", newline="\n")
    for row in summary:
        print(json.dumps(row, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1:])
