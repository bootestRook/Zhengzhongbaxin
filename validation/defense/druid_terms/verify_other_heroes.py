"""One-time scope evidence for this revision, not a future content freeze."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
baseline = json.loads((Path(__file__).parent / "baseline_other_heroes.json").read_text(encoding="utf-8"))
catalog = json.loads((root / "data/generated/defense_catalog.json").read_text(encoding="utf-8"))
# The shared checkout also received independent ice-archer and assassin work.
excluded = {"2", "13", "17"}
for group in ["heroes", "options"]:
    expected = {k: v for k, v in baseline[group].items()
                if (group == "heroes" and k not in excluded) or
                (group == "options" and not excluded.intersection(map(str, v.get("type", []))))}
    current = {k: v for k, v in catalog[group].items()
               if (group == "heroes" and k not in excluded) or
               (group == "options" and not excluded.intersection(map(str, v.get("type", []))))}
    assert current == expected, f"other {group} changed"
    print(f"[OK] other {group} unchanged: {len(current)} records")
print("Scope: druid change; independent ice-archer and assassin changes excluded")
