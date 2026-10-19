"""Normalize reference behavior metadata; never import executable client code."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = Path(r"F:\T8demo\正中靶心2_拆解_20261013")


def build(source: Path):
    json_root = source / "09_当前客户端补充/03_配置表/01_JsonAsset完整"
    inputs = {name: next(json_root.glob(name + "__*.json")) for name in ["heroData", "unitData", "skillData"]}
    rows = {name: json.loads(path.read_text(encoding="utf-8")) for name, path in inputs.items()}
    reference = json.loads((ROOT / "data/source/defense/reference.json").read_text(encoding="utf-8"))
    art = json.loads((ROOT / "data/source/defense/art.json").read_text(encoding="utf-8"))
    map_path = source / "09_当前客户端补充/01_美术资源/05_场景与加载图/map/04_组件结构/battleBar3__9bc66acb.json"
    points = {child["name"]: child["y"] for child in json.loads(map_path.read_text(encoding="utf-8"))["children"]
              if child["name"] in ["heroPoint1", "heroPoint3"]}
    prices = {row["type"]: row["price"] for row in reference["function_price"].values() if row.get("type", "").startswith("line")}
    front_line = points["heroPoint1"] - prices["line3"] - prices["line1"]
    back_line = points["heroPoint3"] - prices["line3"] - prices["line2"]
    patrol_line = max(front_line, back_line)
    result = {"schema_version": 1, "actors": {}, "bullets": {}, "world": {
        "left": 350, "right": 1250, "top": 0, "bottom": 1600, "wall_y": 1460,
        "warning_y": min(front_line, back_line), "patrol_y": patrol_line,
        "retreat_y": patrol_line + prices["line1"], "rear_threat_y": front_line - prices["line4"], "center": [800, 754],
        "canvas_offset": [-320, 103], "block_search": 400, "cell_size": 50},
        "formation": {"front": [[[800, 950]], [[1000, 950], [600, 950]],
            [[1050, 995], [550, 995], [800, 950]], [[1130, 1000], [470, 1000], [690, 950], [920, 950]]],
            "back": [[[800, 1150]], [[1000, 1150], [600, 1150]],
            [[1050, 1150], [550, 1150], [800, 1150]], [[1130, 1150], [470, 1150], [690, 1150], [910, 1150]]]},
        "target_score": {}, "revival": {}, "buff_effects": rows["skillData"]["buffData"], "provenance": []}
    for value in reference["function_price"].values():
        if value.get("type", "").startswith("distance"):
            result["target_score"][value["type"]] = value["price"]
        if value.get("type", "") in ["reviveTime1", "reviveTime2"]:
            result["revival"][value["type"]] = value.get("price", 0)
    for table, group in [("lead", "hero"), ("entity", "soldierData"), ("monster", "monsterData")]:
        for key, unit in reference[table].items():
            if not unit.get("res") or (group != "hero" and not unit.get("hp")):
                continue
            res = unit["res"]
            raw = rows["heroData"].get(key, {}) if group == "hero" else rows["unitData"][group].get(res, {})
            config = raw.get("configData", {})
            base = config.get("baseSize", {"x": 200, "y": 178})
            pivot = config.get("basePivot", {"x": 0.5, "y": 0.85})
            attack = config.get("attackPointPos", {"x": base["x"] * pivot["x"], "y": base["y"] * pivot["y"]})
            box = config.get("attackBoxPos", attack)
            body = config.get("collisionPos", attack)
            # Feet are physical circles; the body is a separate attack sensor.
            shadow_y = config.get("shadowSize", {"y": 0})["y"]
            collision = str(unit.get("collision", "0:1")).split(":")
            box_size = config.get("attackBoxSize", {"x": 0, "y": 0})
            body_size = config.get("collisionSize", {"x": 0, "y": 0})
            actions = {}
            for action in ["attack", "skill", "skill2", "die", "hit"]:
                movie = raw.get("movieData", {}).get(action)
                if movie:
                    delays = movie.get("addDelays", [0] * movie["framesNum"])
                    frames = [max(1, int(1000 * (movie["interval"] + value))) for value in delays]
                else:
                    frames = [f["duration_ms"] for f in art["animations"].get(res + "_" + action, {}).get("frames", [])]
                if frames:
                    actions[action] = frames
            result["actors"][group + ":" + key] = {"pivot": [pivot["x"], pivot["y"]],
                "base_size": [base["x"], base["y"]], "shadow_size": [config.get("shadowSize", {}).get("x", 0), shadow_y],
                "buff_size": [config.get("buffSize", {}).get("x", 0), config.get("buffSize", {}).get("y", 0)],
                "buff_offset": [config.get("buffPos", {}).get("x", base["x"] * pivot["x"]) - base["x"] * pivot["x"],
                                config.get("buffPos", {}).get("y", base["y"] * pivot["y"]) - base["y"] * pivot["y"]],
                "hp_scale": [config.get("hpScale", {}).get("x", 1), config.get("hpScale", {}).get("y", 1)],
                "overlays": {action: res + suffix for flag, action, suffix in [(1, "attack", "_attack2"), (2, "skill", "_skill3"), (3, "skill2", "_skill4")]
                             if flag in unit.get("attaack_effect", []) and res + suffix in art["animations"]},
                "attack_offset": [attack["x"] - base["x"] * pivot["x"], attack["y"] - base["y"] * pivot["y"]],
                "attack_box_offset": [box["x"] - base["x"] * pivot["x"], box["y"] - base["y"] * pivot["y"]],
                "attack_box_size": [box_size["x"], box_size["y"]],
                "attack_angle": config.get("attackBoxAngle", 0),
                "body_offset": [body["x"] - base["x"] * pivot["x"], body["y"] - base["y"] * pivot["y"]],
                "body_size": [body_size["x"], body_size["y"]],
                "foot_radius": float(collision[1]) * shadow_y / 2,
                "active_foot_radius": float(collision[0]) * shadow_y / 2,
                "hp_offset": [config.get("hpPos", {}).get("x", 0), config.get("hpPos", {}).get("y", -90)],
                "frames": actions, "valid": unit.get("valid", []),
                "missile": unit.get("missile_effect", ""), "sound": unit.get("sound1", [])}
    for key, value in rows["skillData"]["bulletData"].items():
        result["bullets"][key] = {name: value[name] for name in ["basePivot", "baseSize", "collisionPivot", "collisionSize", "collisionPos", "collisionPolygonPoints"] if name in value}
    for name, path in inputs.items():
        result["provenance"].append({"table": name, "path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    result["provenance"].append({"table": "battleBar3", "path": str(map_path), "sha256": hashlib.sha256(map_path.read_bytes()).hexdigest()})
    path = ROOT / "data/source/defense/combat.json"
    path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"[OK] combat metadata: {len(result['actors'])} actors, {len(result['bullets'])} bullet shapes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT)
    build(parser.parse_args().source)
