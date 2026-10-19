"""Compare existing non-warrior records with the pre-change snapshot."""
import hashlib
import json
import copy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
before_path = HERE / "other_heroes_before.json"
before = json.loads(before_path.read_text(encoding="utf-8"))
after = json.loads((ROOT / "data/generated/defense_catalog.json").read_text(encoding="utf-8"))
approved = json.loads((HERE / "approved_parallel_changes.json").read_text(encoding="utf-8"))
report = {"baseline_sha256": hashlib.sha256(before_path.read_bytes()).hexdigest(), "tables": {}, "approved_parallel_changes": approved}
for table, rows in before.items():
    changed = [key for key, value in rows.items() if after[table].get(key) != value]
    unexpected = []
    for key in changed:
        expected = copy.deepcopy(rows[key])
        expected.update(approved.get(table, {}).get(key, {}))
        if after[table].get(key) != expected:
            unexpected.append(key)
    report["tables"][table] = {"existing_records": len(rows), "changed": changed, "unexpected": unexpected}
report["all_unchanged"] = all(not value["changed"] for value in report["tables"].values())
report["only_approved_parallel_changes"] = all(not value["unexpected"] for value in report["tables"].values())
(HERE / "other_heroes_isolation.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(0 if report["only_approved_parallel_changes"] else 1)
