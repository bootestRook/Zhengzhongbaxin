"""Read-only battle source comparison and complete hero/monster review inventory."""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import json
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from audit_defense_hero_skills import normalize

ROOT = Path(__file__).resolve().parents[1]
RESEARCH = Path(r"F:/T8demo/正中靶心2_拆解_20261013")
OUT = ROOT / "validation/defense/battle_reaudit"
TABLES = ["lead", "attribute", "monster", "entity", "skill2", "status2", "target2",
          "equip_skill", "upgrade_options", "enemyLevel", "function_price"]
BUNDLED_TABLES = ["chapter", "skill_attribute"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def live_tables(vmdk_path):
    # Reuse the research tool's installed read-only filesystem readers.
    sys.path.insert(0, r"F:\GameResearch\正中靶心2_APK拆解\tools\deps")
    from dissect.hypervisor.disk.vmdk import VMDK
    from dissect.extfs import ExtFS
    from dissect.util.stream import RangeStream

    with vmdk_path.open("rb") as disk:
        volume = VMDK(disk)
        fs = ExtFS(RangeStream(volume, 1050624 * 512, 535820288 * 512))
        db_files = {}
        proof = []
        for attempt in range(3):
            db_files.clear()
            proof.clear()
            for name in ["jsb.sqlite", "jsb.sqlite-wal", "jsb.sqlite-shm"]:
                try:
                    node = fs.get("/data/com.openew.monster/databases/" + name)
                except FileNotFoundError:
                    continue
                data = node.open().read()
                db_files[name] = data
                proof.append({"file": name, "bytes": len(data), "sha256": sha(data)})
            if all(data == fs.get("/data/com.openew.monster/databases/" + name).open().read()
                   for name, data in db_files.items()):
                break
        else:
            raise RuntimeError("Configuration database changed during all three snapshots")
        with tempfile.TemporaryDirectory(prefix="defense_source_audit_") as temp:
            for name, data in db_files.items():
                (Path(temp) / name).write_bytes(data)
            connection = sqlite3.connect(str(Path(temp) / "jsb.sqlite"))
            rows = connection.execute("SELECT key,value FROM data WHERE key LIKE 'net_%'").fetchall()
            connection.close()
        tables = {}
        for key, value in rows:
            name = key[4:]
            if name not in TABLES:
                continue
            encoded = base64.b64decode(value)
            mask = b"dull~whisker"
            decoded = bytes(byte ^ mask[i % len(mask)] for i, byte in enumerate(encoded))
            tables[name] = (json.loads(decoded), sha(decoded))
        script = fs.get("/data/com.openew.monster/files/tcg-remote-assets/src/assets/Script/src/GameLogic.jsc").open().read()
        old = RESEARCH / "07_实机证据/当前热更新/src/assets/Script/src/GameLogic.jsc"
        return tables, {"method": "read-only VMDK; SQLite files checked twice; only net_ battle tables queried",
                        "database_files": proof, "hot_script_sha256": sha(script),
                        "hot_script_matches_research": sha(script) == sha(old.read_bytes())}


def descendants(roots, skills):
    seen = set()
    pending = list(roots)
    while pending:
        key = str(abs(int(pending.pop())))
        if key in seen:
            continue
        seen.add(key)
        pending.extend(row[1] for row in skills.get(key, {}).get("skillGroupType", []))
    return sorted(seen, key=int)


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def monster_samples(reference):
    samples = []
    for level_id in [1, 3, 20, 50]:
        level = reference["enemyLevel"][str(level_id)]
        chapter = next(row for row in reference["chapter"].values() if level_id in row["level"])
        for wave in [1, 5, 12, 20, 30]:
            atk_growth = sum(level["grow_up"][min(i, len(level["grow_up"]) - 1)] for i in range(wave))
            hp_growth = sum(level["grow_up_hp"][min(i, len(level["grow_up_hp"]) - 1)] for i in range(wave))
            for key, monster in reference["monster"].items():
                if not monster.get("hp"):
                    continue
                hp_parts = [float(p) for p in monster["hp"].split(":")]
                atk_parts = [float(p) for p in monster["atk"].split(":")]
                for kind in ["enemy", "elite", "boss"]:
                    elite = float(level["cream_pro"].split(":")[1]) if kind == "elite" else 0
                    hp_level = level_id + chapter.get("hp_up", 0) + level.get("hp_up", 0) + elite
                    atk_level = level_id + chapter.get("atk_up", 0) + level.get("atk_up", 0) + atk_growth + elite
                    hp = (hp_parts[0] + hp_parts[1] * hp_level) * (1 + hp_growth / 100) * (1 + min(level_id, 100) * .001) ** (wave // 3)
                    atk = atk_parts[0] + atk_parts[1] * atk_level
                    defense = sum(atk * float(t[1]) / 100 for t in monster.get("characteristic", []) if t[0] == "defense")
                    samples.append({"monster": int(key), "level": level_id, "wave": wave, "kind": kind,
                                    "expected": {"1": hp, "4": atk, "6": monster["atkSpe"], "17": monster.get("speed", 0),
                                                 "5": monster["atkNum"], "10": defense}})
    return samples


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-vmdk", type=Path)
    args = parser.parse_args()
    reference = json.loads((ROOT / "data/source/defense/reference.json").read_text("utf-8"))
    catalog = json.loads((ROOT / "data/generated/defense_catalog.json").read_text("utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    proof = {}
    if args.live_vmdk:
        tables, proof = live_tables(args.live_vmdk)
    else:
        tables = {}
        for name in TABLES:
            path = RESEARCH / "07_实机证据/当前缓存配置" / (name + ".json")
            data = path.read_bytes()
            tables[name] = (json.loads(data.decode("utf-8-sig")), sha(data))
    comparisons = []
    for name in TABLES:
        raw, digest = tables[name]
        rows = {str(row.get("__id__", row.get("_id_"))): normalize(row) for row in raw["Items"]}
        same = rows == reference[name]
        comparisons.append({"table": name, "rows": len(rows), "same": same, "sha256": digest,
                            "source": "live net_ cache" if args.live_vmdk else "extracted net_ cache",
                            "changed_ids": sorted(k for k in rows.keys() | reference[name].keys()
                                                  if rows.get(k) != reference[name].get(k))})
    for name in BUNDLED_TABLES:
        path = RESEARCH / "06_战斗逻辑/当前版本/配置全表" / (name + ".json")
        data = path.read_bytes()
        rows = json.loads(data.decode("utf-8-sig"))
        comparisons.append({"table": name, "rows": len(rows), "same": rows == reference[name],
                            "source": "bundled configuration from research; no live net_ entry", "sha256": sha(data)})
    heroes = []
    for key, hero in sorted(catalog["heroes"].items(), key=lambda item: int(item[0])):
        initials = [catalog["options"][str(i)] for i in hero["initial_options"]]
        initial = {"unlock": [sid for o in initials for sid in o.get("unlock", [])], "description": "\n".join(o.get("description", "") for o in initials)}
        options = [o for o in catalog["options"].values() if o.get("type") == [hero["id"]] and o.get("options_num", 0) > 0]
        roots = hero["skills"] + [s for s in initial.get("unlock", []) if int(s) > 0]
        all_roots = list(roots)
        for option in options:
            all_roots.extend(option.get("unlock", []))
            for pair in option.get("up_skill", []):
                all_roots.extend(pair.split(":"))
        initial_ids = descendants(roots, catalog["skills"])
        all_ids = descendants(all_roots, catalog["skills"])
        heroes.append({"id": hero["id"], "name": hero["name"], "available": hero["available"],
                       "row": "前排" if hero["front"] else "后排", "base_attributes": hero["base"],
                       "initial_options": initials, "initial_skill_ids": initial_ids, "legal_option_count": len(options),
                       "skills": {sid: catalog["skills"][sid] for sid in all_ids if sid in catalog["skills"]},
                       "missing_skill_ids": [sid for sid in all_ids if sid not in catalog["skills"]],
                       "motion": catalog["combat"]["actors"].get("hero:" + key, {})})
    report = {"captured_at": datetime.now(timezone.utc).isoformat(),
              "scope": "All frozen fields compared; semantic and visual acceptance require separate runtime evidence",
              "source": "live emulator disk" if args.live_vmdk else "2026-10-13 extracted cache", "proof": proof,
              "tables": comparisons, "heroes": heroes, "monsters": catalog["monsters"],
              "skills": catalog["skills"], "statuses": catalog["statuses"],
              "counts": {"heroes": len(heroes), "available_heroes": sum(h["available"] for h in heroes),
                         "monster_rows": len(catalog["monsters"]), "active_monsters": sum(bool(m.get("hp")) for m in catalog["monsters"].values()),
                         "skills": len(catalog["skills"]), "legal_hero_options": sum(h["legal_option_count"] for h in heroes)}}
    write_json(OUT / "source_audit.json", report)
    write_json(OUT / "monster_expected.json", {"source": "source configuration and verified LevelBattle/MonsterHPAttribute arithmetic; no account/endless buffs",
                                               "samples": monster_samples(reference)})
    with (OUT / "heroes.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(["ID", "英雄", "招募", "前后排", "生命", "攻击", "攻速", "移速", "攻击范围增量", "阻挡", "初始技能", "初始描述", "合法选项数", "全部执行节点", "缺失节点"])
        for hero in heroes:
            b = hero["base_attributes"]
            writer.writerow([hero["id"], hero["name"], hero["available"], hero["row"], *[b.get(str(i), 0) for i in [1, 4, 6, 17, 26, 3]],
                             ",".join(hero["initial_skill_ids"]), "\n".join(o.get("description", "") for o in hero["initial_options"]), hero["legal_option_count"],
                             ",".join(hero["skills"]), ",".join(hero["missing_skill_ids"])])
    with (OUT / "monsters.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(["ID", "有效单位", "名称", "资源", "生命基础与成长", "攻击基础与成长", "攻速", "移速", "攻击目标数", "阻挡配置", "技能", "特征", "完整字段"])
        for key, monster in sorted(catalog["monsters"].items(), key=lambda item: int(item[0])):
            writer.writerow([key, bool(monster.get("hp")), monster.get("title", ""), *[monster.get(f, "") for f in ["res", "hp", "atk", "atkSpe", "speed", "atkNum", "block"]],
                             json.dumps(monster.get("skill", [])), json.dumps(monster.get("characteristic", []), ensure_ascii=False), json.dumps(monster, ensure_ascii=False, sort_keys=True)])
    print(json.dumps({"counts": report["counts"], "tables_match": all(t["same"] for t in comparisons), "proof": proof}, ensure_ascii=False))
    if not all(t["same"] for t in comparisons) or (proof and not proof["hot_script_matches_research"]):
        raise SystemExit("Source drift found; inspect source_audit.json")


if __name__ == "__main__":
    main()
