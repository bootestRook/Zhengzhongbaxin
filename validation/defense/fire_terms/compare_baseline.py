"""Separate fire changes from the concurrent ADR-0019/0020/0021 hero work."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
folder = Path(__file__).resolve().parent
baseline = json.loads((folder / "baseline.json").read_text(encoding="utf-8"))
current = json.loads((root / "data/generated/defense_catalog.json").read_text(encoding="utf-8"))
report = {}
allowed = {"heroes": set(), "options": set(), "skills": {"17", "21", "22"},
           "statuses": set(), "targets": set()}
parallel = {"heroes": {"2", "13", "17"},
            "options": {key for key, row in baseline["options"].items() if row.get("type") in [[2], [13], [17]]},
            "skills": {"661", "20002", "868", "869", "870", "1435"}, "statuses": set(), "targets": set()}
for group, rows in baseline.items():
    changes = [key for key, row in rows.items() if current[group].get(key) != row]
    assert allowed[group] <= set(changes) <= allowed[group] | parallel[group], (group, changes)
    report[group] = {"compared": len(rows), "fire_changes": sorted(set(changes) & allowed[group]),
                     "parallel_other_hero_changes": sorted(set(changes) & parallel[group])}
report["parallel_adrs"] = ["docs/adr/0019-defense-druid-terms.md", "docs/adr/0020-defense-ice-terms.md",
                           "docs/adr/0021-defense-assassin-terms.md"]
report["new_skills"] = sorted(set(current["skills"]) - set(baseline["skills"]))
report["new_statuses"] = sorted(set(current["statuses"]) - set(baseline["statuses"]))
report["fire_options"] = sorted(int(k) for k, row in current["options"].items() if row["type"] == [1])
assert report["fire_options"] == list(range(200, 211))
report["baseline_sha256"] = hashlib.sha256((folder / "baseline.json").read_bytes()).hexdigest()
report["catalog_sha256"] = hashlib.sha256((root / "data/generated/defense_catalog.json").read_bytes()).hexdigest()
(folder / "baseline_comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                                 encoding="utf-8", newline="\n")
print(json.dumps(report, ensure_ascii=False, indent=2))
