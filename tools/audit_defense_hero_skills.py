"""Compare frozen hero/skill tables with reference cache and write review evidence."""
from __future__ import annotations
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"F:/T8demo/正中靶心2_拆解_20261013/07_实机证据/当前缓存配置")
OUT = ROOT / "validation/defense"


def normalize(value):
    if isinstance(value, dict):
        if set(value) == {"Items"}:
            return normalize(value["Items"])
        return {key: normalize(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize(item) for item in value]
    return value


def main():
    reference = json.loads((ROOT / "data/source/defense/reference.json").read_text(encoding="utf-8"))
    catalog = json.loads((ROOT / "data/generated/defense_catalog.json").read_text(encoding="utf-8"))
    tables = []
    for name in ["lead", "skill2", "upgrade_options", "status2", "target2", "equip_skill", "entity"]:
        path = SOURCE / (name + ".json")
        raw = json.loads(path.read_text(encoding="utf-8-sig"))
        rows = {str(row["__id__"]): normalize(row) for row in raw["Items"]}
        same = rows == reference[name]
        tables.append({"table": name, "rows": len(rows), "same": same, "path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        if not same:
            raise ValueError(f"reference drift: {name}")
    heroes = []
    for key in sorted(catalog["heroes"], key=int):
        hero = catalog["heroes"][key]
        initial = [catalog["options"][str(i)] for i in hero["initial_options"]]
        option = {"description": "\n".join(o["description"] for o in initial), "unlock": [sid for o in initial for sid in o.get("unlock", [])]}
        roots = [str(sid) for sid in hero["skills"]] + [sid for sid in option.get("unlock", []) if not sid.startswith("-")]
        upgrades = [o for o in catalog["options"].values() if o.get("type") == [hero["id"]] and o.get("options_num", 0) > 0]
        usable = set(roots)
        for item in upgrades:
            usable.update(str(abs(int(sid))) for sid in item.get("unlock", []))
            for replacement in item.get("up_skill", []):
                usable.update(replacement.split(":"))
        skills = {sid: catalog["skills"][sid] for sid in sorted(usable, key=int) if sid in catalog["skills"]}
        resources = sorted({str(s.get("res", "bullet")) + ":" + str(s["movie_effect"][0]) for s in skills.values() if s.get("movie_effect")})
        missing = sorted({sid for sid in usable if sid not in catalog["skills"]}, key=int)
        heroes.append({"hero": hero["id"], "name": hero["name"], "initial_options": hero["initial_options"], "description": option.get("description", ""),
                       "initial_skills": roots, "options": len(upgrades), "skills": skills, "effect_resources": resources,
                       "missing_skills": missing, "available": hero["available"]})
    OUT.mkdir(exist_ok=True)
    report = {"scope": "Reference cache equality and all 18 hero initial/legal-upgrade definitions; semantic acceptance is in test_defense_hero_skill_contracts.gd, not implied by row counts.",
              "tables": tables, "heroes": heroes, "missing_skill_ids": catalog["missing_skill_ids"],
              "missing_status_effect": "zhiliao6",
              "source_description_questions": [
                  {"hero": 3, "description": "至少2枚奥术飞弹", "configuration": "首发1枚，额外飞弹按70%、10%及后续50%链概率触发；尚未发现保底2枚的执行条件"},
                  {"hero": 11, "description": "分身继承30%基础属性", "configuration": "equip_skill 107 的 value1=20，amount=3，merge=1；按当前客户端算法得到60%"},
              ]}
    (OUT / "hero_skill_source_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    with (OUT / "hero_skill_source_audit.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(["英雄ID", "英雄", "初始选项", "初始技能", "初始描述", "局内选项数", "可解锁执行节点数", "特效资源数", "缺少技能", "招募状态"])
        for hero in heroes:
            writer.writerow([hero["hero"], hero["name"], hero["initial_options"], ",".join(hero["initial_skills"]), hero["description"], hero["options"], len(hero["skills"]), len(hero["effect_resources"]), ",".join(hero["missing_skills"]), "可招募" if hero["available"] else "缺少专属技能树"])
    print(f"[OK] reference tables match; {len(heroes)} hero records, {sum(h['options'] for h in heroes)} legal options audited")


if __name__ == "__main__":
    main()
