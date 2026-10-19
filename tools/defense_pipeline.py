"""Validate and compile the frozen defense definitions and resource metadata."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
import os
import re
import tempfile
import zipfile
from pathlib import Path
from PIL import Image
if __package__:
    from tools import defense_tables
else:
    import defense_tables

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/source/defense"
OUTPUT = ROOT / "data/generated/defense_catalog.json"
KNOWN_MISSING = {608, 1072, 510}
KNOWN_MISSING_EFFECTS = {"zhiliao6"}
GEM_QUALITIES = {"普通": 1, "精良": 2, "卓越": 3, "完美": 4, "传说": 5, "绝世": 6, "至尊": 7}
GEM_PARTS = {"头盔": "head", "衣服": "chest", "足具": "boots", "护臂": "arms", "裤子": "pants", "手套": "gloves"}
# Content regions are relative to the current named sprite's trimmed extent.
# These preserve the UI's existing inner frames/faces without baking pixels
# from a particular atlas export into presentation code.
UI_CONTENT_REGIONS = {
    **{f"map:speedUp{i}_face": (f"map:speedUp{i}", (2/81, 1/77, 65/81, 61/77)) for i in range(1, 5)},
    "map:expBarBg_track": ("map:expBarBg", (0, 0, 918/946, 37/72)),
    "map:choice3_inner": ("map:choice3", (24/318, 24/365, 254/318, 264/365)),
    "map:roster_header": ("map:downBg", (0, 0, 1, 56/475)),
    "map:roster_paper": ("map:downBg", (246/960, 56/475, 8/960, 240/475)),
    "map:roster_footer": ("map:downBg", (0, 296/475, 1, 179/475)),
    "map:roster_empty": ("map:downBg", (30/960, 56/475, 214/960, 242/475)),
    "map:buffCard_hero_Info_face": ("map:buffCard_hero_Info", (0, 0, 1, 1)),
    "map:tips2_paper": ("map:tips2", (0, 0, 107/131, 102/133)),
    "common:btnW2_face": ("common:btnW2", (1/215, 1/160, 196/215, 137/160)),
    "common:btn_Blue_face": ("common:btn_Blue", (1/239, 0, 230/239, 85/99)),
    "common:panel2_variant2_face": ("common:panel2_variant2", (0, 0, 310/328, 217/243)),
}


def ui_art(art):
    result = {**art, "sprites": art["sprites"].copy()}
    for name, (source, uv) in UI_CONTENT_REGIONS.items():
        sprite = art["sprites"].get(source, {})
        if not sprite or sprite.get("blank", False):
            raise ValueError(f"missing required sprite {source} for {name}")
        x, y, w, h = sprite["rect"]
        left, top = round(w * uv[0]), round(h * uv[1])
        right, bottom = round(w * (uv[0] + uv[2])), round(h * (uv[1] + uv[3]))
        if not 0 <= left < right <= w or not 0 <= top < bottom <= h:
            raise ValueError(f"invalid content region {name}")
        result["sprites"][name] = {"page": sprite["page"], "rect": [x + left, y + top, right - left, bottom - top],
                                   "offset": [0, 0], "size": [right - left, bottom - top]}
    return result


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_inputs(tables_dir=defense_tables.TABLES):
    return defense_tables.assemble(*(read(SOURCE / name) for name in
                                   ["reference.json", "art.json", "combat.json", "rules.json"]), tables_dir)[0]


def clean_text(value):
    value = re.sub(r"#c[0-9a-fA-F]{6}|#[ngrywbp]|<[^>]+>", "", str(value))
    return value.replace("\\n", "\n")


def compile_loot(reference):
    prices = {row["type"]: row.get("price", 0) for row in reference["function_price"].values()}
    names = [f"skill_pro{i}" for i in range(1, 6)]
    if any(name not in prices or type(prices[name]) is not int or prices[name] < 0 for name in names):
        raise ValueError("invalid loot probability or weight")
    quality = [prices[f"skill_pro{i}"] for i in range(1, 6)]
    if sum(quality) <= 0:
        raise ValueError("invalid loot probability or weight")
    return {"quality_weights": quality}


def _gem_number(text, index=0):
    values = re.findall(r"(?<![0-9])(?:[0-9]+(?:\.[0-9]+)?)(?![0-9])", str(text))
    return float(values[index]) if index < len(values) else 0.0


def compile_gems(rows, heroes):
    if not isinstance(rows, list) or not rows:
        raise ValueError("宝石表不能为空")
    hero_ids = {str(value.get("name", "")): int(key) for key, value in heroes.items()}
    family_ids = {}
    result = {}
    suspended = {"攻速增幅": "攻击速度暂缓", "鹰眼": "攻击范围暂缓"}
    for row in rows:
        gid = int(row["id"])
        name = str(row["name"])
        quality = str(row["quality"])
        owner = str(row["owner"])
        description = str(row["description"])
        if quality not in GEM_QUALITIES:
            raise ValueError(f"宝石 id={gid}: 未知品质 {quality}")
        if name not in family_ids:
            family_ids[name] = 1000 + len(family_ids) + 1
        # The source uses the Chinese column labels; keep this explicit so a renamed
        # slot cannot silently become an all-slot gem.
        allowed_parts = []
        for label, key in GEM_PARTS.items():
            source_key = {"head": "head", "chest": "chest", "boots": "boots", "arms": "arms", "pants": "pants", "gloves": "gloves"}[key]
            if str(row.get(source_key, "")) == "√":
                allowed_parts.append(key)
        if not allowed_parts:
            raise ValueError(f"宝石 id={gid}: 没有可镶嵌部位")
        if owner != "通用" and owner not in hero_ids:
            raise ValueError(f"宝石 id={gid}: 未知所属英雄 {owner}")
        owner_ids = [] if owner == "通用" else [hero_ids[owner]]
        value = _gem_number(description)
        effect = {"type": "suspended", "reason": "未启用"} if name in suspended else {"type": "unimplemented", "name": name}
        if name in {"攻击增幅", "生命增幅", "防御增幅", "恢复增幅"}:
            effect = {"type": "attribute_pct", "attribute": {"攻击增幅": "4", "生命增幅": "1", "防御增幅": "10", "恢复增幅": "2"}[name], "value": value}
        elif name in {"火系增幅", "冰系增幅", "电系增幅", "自然增幅", "物理增幅"}:
            effect = {"type": "element_damage_pct", "element": {"火系增幅": "fire", "冰系增幅": "ice", "电系增幅": "electric", "自然增幅": "nature", "物理增幅": "physical"}[name], "value": value}
        elif name == "暴击增幅":
            effect = {"type": "attribute_add", "attribute": "7", "value": value}
        elif name == "爆伤增幅":
            effect = {"type": "attribute_add", "attribute": "8", "value": value}
        elif name == "冷却":
            effect = {"type": "attribute_add", "attribute": "9", "value": value}
        elif name == "精英":
            effect = {"type": "attribute_pct_bundle", "attributes": ["1", "4", "10"], "value": value}
        elif name in {"近战精通", "远程精通"}:
            effect = {"type": "range_damage_pct", "range": "melee" if name == "近战精通" else "ranged", "value": value}
        elif name in {"战士精通", "法师精通", "辅助精通", "射手精通", "刺客精通"}:
            parts = re.findall(r"([0-9]+(?:\.[0-9]+)?)%", description)
            effect = {"type": "profession_damage_taken_pct", "profession": {"战士精通": 1, "法师精通": 2, "辅助精通": 5, "射手精通": 3, "刺客精通": 10}[name], "damage": float(parts[0]), "taken": float(parts[1])}
        elif name == "挑战":
            parts = re.findall(r"([0-9]+(?:\.[0-9]+)?)%", description)
            effect = {"type": "elite_damage_taken_pct", "damage": float(parts[0]), "taken": float(parts[1])}
        elif name == "一鼓作气":
            effect = {"type": "stage_damage_pct", "before_wave": int(_gem_number(description, 0)), "value": _gem_number(description, 1)}
        elif name == "普攻强化":
            effect = {"type": "attack_damage_pct", "value": value}
        elif name == "复仇":
            effect = {"type": "revive_buff", "duration_ms": int(_gem_number(description, 1) * 1000), "attack_pct": 100.0, "speed_pct": 100.0}
        elif name == "归魂":
            effect = {"type": "statue_on_death_pct", "value": value}
        elif name == "苏生":
            effect = {"type": "revive_time_reduction", "value": value}
        elif name == "死者复苏":
            effect = {"type": "instant_revive", "cooldown_ms": 60000}
        elif name == "天选":
            effect = {"type": "extra_choice", "count": 1}
        elif name == "雕像强化":
            effect = {"type": "statue_strength", "max_hp": value, "damage_reduction": _gem_number(description, 1)}
        elif name == "防护强化":
            effect = {"type": "statue_hit_immunity", "hits": int(value)}
        elif name == "天佑":
            effect = {"type": "statue_grace", "threshold_pct": 25.0, "duration_ms": int(_gem_number(description, 1) * 1000)}
        elif name == "天罚":
            effect = {"type": "statue_punishment", "threshold_pct": _gem_number(description, 0), "duration_ms": int(_gem_number(description, 1) * 1000), "radius": 300.0}
        elif name == "修复":
            effect = {"type": "statue_wave_heal_pct", "value": value}
        elif name == "格挡":
            effect = {"type": "hero_block", "hits": int(value)}
        elif name == "闪耀":
            effect = {"type": "guard_duration_add_ms", "value": int(value * 1000)}
        elif name == "刺目圣盾":
            effect = {"type": "guard_expire_stun_ms", "value": int(value * 1000)}
        elif name == "圣盾回击":
            effect = {"type": "guard_attack_burst", "duration_ms": int(_gem_number(description, 0) * 1000), "damage_pct": 200.0}
        elif name == "复苏之风":
            effect = {"type": "low_hp_regen", "threshold_pct": _gem_number(description, 0), "heal_pct": _gem_number(description, 2), "duration_ms": int(_gem_number(description, 1) * 1000), "cooldown_ms": int(_gem_number(description, 3) * 1000)}
        elif name == "火球增幅":
            effect = {"type": "skill_damage_pct", "skill": "fireball", "value": value}
        elif name == "爆破增幅":
            effect = {"type": "skill_radius_pct", "skill": "fireball", "value": value}
        elif name == "火球精通":
            effect = {"type": "skill_charge_pct", "skill": "fireball", "value": value}
        elif name == "多重火球":
            effect = {"type": "skill_copies_add", "skill": "fireball", "value": int(value)}
        elif name == "毁天灭地":
            effect = {"type": "skill_pierce_add", "skill": "fireball", "value": 1}
        elif name == "烈焰焚身":
            effect = {"type": "fireball_true_burn_pct", "value": 2.0, "cap_attack_multiplier": 100000.0}
        elif name == "荆棘滋养":
            effect = {"type": "skill_field_pct", "skill": "thorn", "field": "shield_percent", "value": value}
        elif name == "自然延续":
            effect = {"type": "skill_field_pct", "skill": "thorn", "field": "heal_percent", "value": value}
        elif name == "尖刺":
            effect = {"type": "skill_field_pct", "skill": "thorn", "field": "retaliate_percent", "value": value}
        elif name == "蔓延":
            effect = {"type": "skill_field_add", "skill": "thorn", "field": "targets", "value": int(value)}
        elif name == "自然庇护":
            effect = {"type": "thorn_cast_heal_max_pct", "value": value}
        elif name == "强力射击":
            effect = {"type": "skill_damage_pct", "skill": "ice", "value": value}
        elif name == "多重穿透":
            effect = {"type": "skill_field_add", "skill": "ice", "field": "pierce", "value": int(value)}
        elif name == "多重连击":
            effect = {"type": "ice_fixed_combo", "count": 1}
        elif name == "多重扩散":
            effect = {"type": "skill_field_add", "skill": "ice", "field": "copies", "value": 1}
        elif name == "浓烟":
            effect = {"type": "skill_field_pct", "skill": "assassination", "field": "smoke_radius", "value": value}
        elif name == "锋刃":
            effect = {"type": "skill_field_pct", "skill": "assassination", "field": "damage_percent", "value": value}
        elif name == "伺机待发":
            effect = {"type": "basic_reduce_skill_cd", "skill": "assassination", "chance": value, "reduce_ms": 1000}
        elif name == "暗影秘愈":
            effect = {"type": "assassination_shield_pct", "value": value, "duration_ms": 5000}
        elif name == "分形":
            effect = {"type": "skill_field_bool", "skill": "assassination", "field": "combo", "value": True}
        elif name == "致命专注":
            effect = {"type": "assassination_guaranteed_crit"}
        if name == "多重连击":
            description = "多重射击额外触发1次连击"
        result[str(gid)] = {"id": gid, "gem_id": gid, "effect_family_id": family_ids[name], "effect_id": 100000 + gid,
            "name": name, "quality": quality, "quality_rank": GEM_QUALITIES[quality], "owner": owner,
            "owner_ids": owner_ids, "description": description, "parts": allowed_parts, "effect": effect}
    if len(result) != len(rows):
        raise ValueError("宝石表存在重复 id")
    return result


def validate_result_rewards(entries):
    if not isinstance(entries, list) or any(
        not isinstance(entry, str) or not re.fullmatch(r"resource:[12]:[0-9]+", entry)
        for entry in entries
    ):
        raise ValueError("unsupported result reward reference")


def validate_rules(rules, world):
    keys = {"schema_version", "chest_reward_weights", "unlocked_heroes", "hero_limit", "wave_count", "max_level", "recruit_chance", "hero_spawn", "revive_seconds", "formation_five"}
    if set(rules) != keys or rules["schema_version"] != 6:
        raise ValueError("invalid experience rules schema")
    counts = rules["chest_reward_weights"]
    if not isinstance(counts, list) or len(counts) != 4 or any(type(v) is not int or v < 0 for v in counts) or sum(counts) <= 0:
        raise ValueError("invalid chest reward weights")
    unlocked = rules["unlocked_heroes"]
    if not isinstance(unlocked, list) or not unlocked or any(type(hero) is not int for hero in unlocked) or len(set(unlocked)) != len(unlocked):
        raise ValueError("invalid unlocked heroes")
    if any(type(rules[k]) is not int for k in ("hero_limit", "wave_count", "max_level")) or rules["hero_limit"] != 5 or not 1 <= rules["max_level"] <= rules["wave_count"] <= 30:
        raise ValueError("invalid experience limits")
    if type(rules["recruit_chance"]) is not int or not 0 <= rules["recruit_chance"] <= 10000:
        raise ValueError("invalid recruitment chance")
    if set(rules["revive_seconds"]) != {"1", "2", "3", "4", "5", "10"} or any(type(v) is not int or v < 1 for v in rules["revive_seconds"].values()):
        raise ValueError("invalid profession revival timing")
    def valid_point(point):
        return isinstance(point, list) and len(point) == 2 and all(type(v) is int for v in point) and world["left"] <= point[0] <= world["right"] and 0 <= point[1] < world["wall_y"]
    if not valid_point(rules["hero_spawn"]):
        raise ValueError("invalid hero spawn")
    if set(rules["formation_five"]) != {"front", "back"}:
        raise ValueError("invalid five hero formation")
    for points in rules["formation_five"].values():
        if len(points) != 5 or len({tuple(p) for p in points if valid_point(p)}) != 5:
            raise ValueError("invalid five hero formation")


def validate_guard(guard, statuses, skills):
    fields = {"status", "taunt_skill", "hurt_step", "hurt_cap", "hurt_interval_ms", "taunt_debuff_status", "knockback_immune", "control_multiplier", "lethal_cooldown_ms", "immunity_ms"}
    if not isinstance(guard, dict) or not guard or set(guard) - fields:
        raise ValueError("invalid guard fields")
    for key, value in guard.items():
        if key == "knockback_immune":
            valid = type(value) is bool
        elif key == "control_multiplier":
            valid = type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1
        else:
            valid = type(value) is int and value > 0
        if not valid:
            raise ValueError(f"invalid guard {key}")
        if key in {"status", "taunt_debuff_status"} and str(value) not in statuses:
            raise ValueError(f"guard {key}: unknown status")
        if key == "taunt_skill" and str(value) not in skills:
            raise ValueError("guard taunt_skill: unknown skill")
    for group in [{"hurt_step", "hurt_cap", "hurt_interval_ms"}, {"lethal_cooldown_ms", "immunity_ms"}]:
        if group & set(guard) and not group <= set(guard):
            raise ValueError("incomplete guard rule")


def validate_fireball(value, skills, statuses, partial=False):
    references = {"projectile", "blast", "ember", "burn_status", "stun_status", "shield_status"}
    numbers = {"charge_ms", "copies", "spread_degrees", "blast_bonus", "radius_bonus", "burn_seconds", "ember_seconds", "stun_seconds", "shield_percent", "speed_conversion", "pierce"}
    flags = {"secondary", "upgraded"}
    required = references | (numbers - {"stun_seconds"}) | flags
    if not isinstance(value, dict) or set(value) - (references | numbers | flags) or (not partial and not required <= set(value)):
        raise ValueError("invalid fireball fields")
    if partial and set(value) & (references | {"spread_degrees"}):
        raise ValueError("fireball modifiers cannot replace references")
    for key, amount in value.items():
        if key in flags:
            valid = type(amount) is bool
        else:
            valid = type(amount) in (int, float) and math.isfinite(amount) and amount >= 0
            if key in references | {"charge_ms", "copies", "pierce"}:
                valid = valid and type(amount) is int
            if key in references | {"charge_ms", "copies"}:
                valid = valid and amount > 0
        if not valid:
            raise ValueError(f"invalid fireball {key}")
        if key in references and str(amount) not in (statuses if key.endswith("_status") else skills):
            raise ValueError(f"fireball {key}: unknown reference")
    if (not partial and not 0 < value["spread_degrees"] <= 180) or value.get("shield_percent", 0) > 100 or value.get("copies", 1) > 16 or value.get("pierce", 0) > 16:
        raise ValueError("invalid fireball limits")


def validate_thorns(value, catalog, modifier=False):
    refs = {"armor_status", "extra_status", "slow_status", "root_status", "stun_status", "guard_status", "flower_template"}
    flags = {"extra_shield", "slow", "flowers", "burst", "self_fallback", "follow"}
    quantities = {"duration_ms", "heal_percent", "heal_bonus", "retaliate_percent", "flower_limit", "flower_duration_ms", "flower_interval_ms", "flower_radius", "flower_damage_percent", "burst_radius", "targets", "slow_ms", "burst_stun_ms", "root_ms", "guard_ms"}
    integers = {"duration_ms", "flower_limit", "flower_duration_ms", "flower_interval_ms", "targets", "slow_ms", "burst_stun_ms", "root_ms", "guard_ms"}
    allowed = flags | quantities | (set() if modifier else refs)
    if not isinstance(value, dict) or not value or set(value) - allowed or (not modifier and set(value) != allowed):
        raise ValueError("invalid thorn armor configuration")
    for key, amount in value.items():
        if key in flags:
            valid = type(amount) is bool
        else:
            valid = type(amount) in (int, float) and math.isfinite(amount) and amount >= 0
            if key in integers | refs:
                valid = valid and type(amount) is int and amount > 0
        if not valid:
            raise ValueError(f"invalid thorn armor {key}")
        if key in refs and str(amount) not in catalog["summons" if key == "flower_template" else "statuses"]:
            raise ValueError(f"thorn armor {key}: unknown reference")
    if not modifier and (value["flower_limit"] > 2 or value["targets"] > 2 or value["flower_interval_ms"] > value["flower_duration_ms"] or value["flower_radius"] <= 0 or value["burst_radius"] <= 0):
        raise ValueError("invalid thorn armor limits")


def validate_ice(value, catalog, modifier=False):
    refs = {"chill_status", "freeze_status", "rain_skill"}
    flags = {"chill", "focus", "upgraded"}
    numbers = {"bonus", "pierce", "copies", "spread_degrees", "combo_chance", "knock_chance", "rain_chance", "knock_distance", "knock_ms", "rain_radius", "rain_interval_ms", "rain_ticks", "rain_ms", "bounce_radius", "chill_ms", "freeze_ms", "rain_freeze_ms", "focus_ms", "focus_cap"}
    integers = refs | {"pierce", "copies", "knock_ms", "rain_interval_ms", "rain_ticks", "rain_ms", "chill_ms", "freeze_ms", "rain_freeze_ms", "focus_ms", "focus_cap"}
    allowed = numbers | flags | (set() if modifier else refs)
    if modifier:
        allowed -= {"spread_degrees"}
    if not isinstance(value, dict) or set(value) - allowed or (not modifier and set(value) != allowed):
        raise ValueError("invalid ice arrows fields")
    for key, amount in value.items():
        valid = type(amount) is bool if key in flags else type(amount) in (int, float) and math.isfinite(amount) and amount >= 0
        if key in integers:
            valid = valid and type(amount) is int
        if key in refs or (not modifier and key in numbers - {"bonus", "pierce", "combo_chance", "knock_chance", "rain_chance"}):
            valid = valid and amount > 0
        if not valid or (key.endswith("_chance") and amount > 100):
            raise ValueError(f"invalid ice arrows {key}")
        if key in refs and str(amount) not in catalog["skills" if key == "rain_skill" else "statuses"]:
            raise ValueError(f"ice arrows {key}: unknown reference")
    if value.get("copies", 0) > (1 if modifier else 4) or value.get("pierce", 0) > 1 or value.get("focus_cap", 40) > 40 or (not modifier and value["spread_degrees"] > 180):
        raise ValueError("invalid ice arrows limits")
    if not modifier and ((value["rain_ticks"] - 1) * value["rain_interval_ms"] >= value["rain_ms"] or value["rain_ticks"] > 10):
        raise ValueError("invalid ice arrows rain timing")


def validate_assassination(value, catalog, modifier=False):
    refs = {"paralyze_status", "smoke_status", "shock_status"}
    flags = {"combo", "paralyze", "smoke", "fan", "hunt", "shock", "execute"}
    numbers = {"damage_percent", "hunt_bonus", "smoke_radius", "smoke_damage", "fan_radius", "fan_damage", "execute_threshold", "elite_multiplier", "paralyze_ms", "smoke_ms", "fan_ms", "shock_ms"}
    allowed = numbers | flags | (set() if modifier else refs)
    if not isinstance(value, dict) or not value or set(value) - allowed or (not modifier and set(value) != allowed):
        raise ValueError("invalid assassination fields")
    for key, amount in value.items():
        valid = type(amount) is bool if key in flags else type(amount) in (int, float) and math.isfinite(amount) and amount > 0
        if key in refs or key.endswith("_ms"):
            valid = valid and type(amount) is int
        if not valid or (key == "execute_threshold" and amount >= 100):
            raise ValueError(f"invalid assassination {key}")
        if key in refs and str(amount) not in catalog["statuses"]:
            raise ValueError(f"assassination {key}: unknown reference")


def compile_hero_roster(catalog, source, skill_icons):
    if not isinstance(source, dict) or set(source) != {"schema_version", "heroes", "skills", "statuses", "targets", "options", "option_sets"} or type(source["schema_version"]) is not int or source["schema_version"] != 2 or not isinstance(source["heroes"], dict):
        raise ValueError("invalid hero roster schema")
    heroes, options = catalog["heroes"], catalog["options"]
    sets = source["option_sets"]
    if not isinstance(sets, dict) or set(sets) - set(source["heroes"]):
        raise ValueError("invalid explicit option sets")
    explicit = set()
    for hid, ids in sets.items():
        if not isinstance(ids, list) or not ids or any(type(i) is not int or i <= 0 for i in ids) or len(set(ids)) != len(ids):
            raise ValueError(f"hero {hid}: invalid option set")
        for oid in ids:
            if str(oid) in options or str(oid) in explicit:
                raise ValueError(f"option {oid}: ID collision")
            explicit.add(str(oid))
    if set(source["heroes"]) != {str(h) for h in catalog["rules"]["unlocked_heroes"]}:
        raise ValueError("hero roster must cover the unlocked roster")
    # Source overrides are compiled once; reference definitions remain immutable.
    for group in ["skills", "statuses", "targets", "options"]:
        if not isinstance(source[group], dict):
            raise ValueError(f"invalid roster {group}")
        allowed = set().union(*(row.keys() for row in catalog[group].values()))
        allowed.add("isContinued")
        if group == "options":
            allowed.update({"term_id", "term_type", "draw_weight", "recruit_weight", "duration_up", "guard", "fireball_mod", "thorn_mod", "ice_mod", "assassination_mod"})
        if group == "skills":
            allowed.update({"area_shape", "cast_range", "visual_tint", "fireball", "persistent_area", "periodic", "thorn_armor", "ice_arrows", "assassination"})
        if group == "statuses":
            allowed.update({"taunt_bound", "tick_at_expiry", "refresh_ticks", "damage_type", "keep_longer", "skillFor"})
        for key, patch in source[group].items():
            if not key.isdecimal() or int(key) <= 0 or not isinstance(patch, dict) or not patch:
                raise ValueError(f"invalid roster {group} definition")
            existing = catalog[group].get(key, {})
            if not existing and (patch.get("__id__") != int(key) or (group == "options" and key not in explicit)):
                raise ValueError(f"roster {group} {key}: unknown definition")
            if set(patch) - allowed or ("__id__" in patch and patch["__id__"] != int(key)):
                raise ValueError(f"roster {group} {key}: unknown fields")
            definition = {**existing, **copy.deepcopy(patch)}
            if group == "options" and key in explicit:
                required = {"id", "title", "description", "icon", "type", "term_id", "term_type", "draw_weight", "options_num", "premise1", "premise2"}
                if not required <= set(patch) or patch["id"] != int(key) or not patch["title"] or not patch["description"]:
                    raise ValueError(f"option {key}: incomplete definition")
                if patch["term_type"] not in {"initial", "upgrade"} or type(patch["term_id"]) is not int or patch["term_id"] <= 0 or type(patch["options_num"]) is not int or patch["options_num"] not in (1, 2):
                    raise ValueError(f"option {key}: invalid term metadata")
                parts = str(patch["icon"]).split(":")
                if len(parts) != 2 or parts[0] not in skill_icons or parts[1] not in {"1", "2", "3", "4", "5"}:
                    raise ValueError(f"option {key}: invalid icon")
                definition["icon_res"] = "gameIcon:" + skill_icons[parts[0]]["icon"]
                if definition["icon_res"] not in catalog["art"]["sprites"]:
                    raise ValueError(f"option {key}: missing icon sprite")
                for field in ["draw_weight", "recruit_weight"]:
                    if field in patch and (type(patch[field]) is not int or patch[field] <= 0):
                        raise ValueError(f"option {key}: invalid {field}")
                if "duration_up" in patch and (type(patch["duration_up"]) not in (int, float) or not math.isfinite(patch["duration_up"]) or patch["duration_up"] <= 0):
                    raise ValueError(f"option {key}: invalid duration_up")
            if group == "skills":
                for flag in ["persistent_area", "periodic"]:
                    if flag in definition and type(definition[flag]) is not bool:
                        raise ValueError(f"roster skill {key}: invalid {flag}")
                if "area_shape" in definition and definition["area_shape"] != "circle":
                    raise ValueError(f"roster skill {key}: invalid area shape")
                if "cast_range" in definition and (type(definition["cast_range"]) not in (int, float) or not math.isfinite(definition["cast_range"]) or definition["cast_range"] <= 0):
                    raise ValueError(f"roster skill {key}: invalid cast range")
                if "visual_tint" in definition and (not isinstance(definition["visual_tint"], str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", definition["visual_tint"])):
                    raise ValueError(f"roster skill {key}: invalid visual tint")
                if not definition.get("type") or any(type(definition.get(k, 0)) not in (int, float) or not math.isfinite(definition.get(k, 0)) or definition.get(k, 0) < 0 for k in ["cd", "attack_range"]):
                    raise ValueError(f"roster skill {key}: invalid timing or range")
            catalog[group][key] = definition
            if group == "statuses":
                for flag in ["tick_at_expiry", "refresh_ticks", "keep_longer"]:
                    if flag in definition and type(definition[flag]) is not bool:
                        raise ValueError(f"roster status {key}: invalid {flag}")
                if "skillFor" in definition and (type(definition["skillFor"]) is not int or definition["skillFor"] not in (0, 1)):
                    raise ValueError(f"roster status {key}: invalid skill prohibition")
    for key, patch in source["options"].items():
        if "assassination_mod" in patch:
            validate_assassination(patch["assassination_mod"], catalog, True)
            if not patch.get("aim_skill") or any("assassination" not in catalog["skills"].get(str(sid), {}) for sid in patch["aim_skill"]):
                raise ValueError(f"option {key}: assassination modifier requires assassination capability")
        if "guard" in patch:
            validate_guard(patch["guard"], catalog["statuses"], catalog["skills"])
        if "fireball_mod" in patch:
            validate_fireball(patch["fireball_mod"], catalog["skills"], catalog["statuses"], True)
        if "ice_mod" in patch:
            validate_ice(patch["ice_mod"], catalog, True)
            if not patch.get("aim_skill") or any("ice_arrows" not in catalog["skills"].get(str(sid), {}) for sid in patch["aim_skill"]):
                raise ValueError(f"option {key}: ice modifier requires arrow capability")
        if "thorn_mod" in patch:
            validate_thorns(patch["thorn_mod"], catalog, True)
            if not patch.get("aim_skill") or any("thorn_armor" not in catalog["skills"].get(str(sid), {}) for sid in patch["aim_skill"]):
                raise ValueError(f"option {key}: thorn modifier requires armor capability")
        for field in ["unlock", "aim_skill"]:
            if any(str(abs(int(sid))) not in catalog["skills"] and abs(int(sid)) not in KNOWN_MISSING for sid in patch.get(field, [])):
                raise ValueError(f"roster option {key}: unknown skill")
    for skill in catalog["skills"].values():
        if "assassination" in skill:
            validate_assassination(skill["assassination"], catalog)
        if "ice_arrows" in skill:
            validate_ice(skill["ice_arrows"], catalog)
        if "fireball" in skill:
            validate_fireball(skill["fireball"], catalog["skills"], catalog["statuses"])
        if "thorn_armor" in skill:
            validate_thorns(skill["thorn_armor"], catalog)
    for key, status in source["statuses"].items():
        if any(str(int(sid)) not in catalog["skills"] for sid in status.get("skillChange", [])):
            raise ValueError(f"roster status {key}: unknown granted skill")
    original = copy.deepcopy(options)
    retained = {}
    for hid, profile in source["heroes"].items():
        fields = {"name", "race", "element", "damage_type", "attack_delay_ms", "option", "trigger", "groups"}
        if hid not in heroes or not isinstance(profile, dict) or not fields <= set(profile) or set(profile) - (fields | {"equip_skill"}):
            raise ValueError(f"hero {hid}: invalid roster profile")
        if not isinstance(profile["name"], str) or not profile["name"].strip() or profile["race"] not in ["人类", "精灵"] or profile["element"] not in ["物理", "火", "自然", "冰", "电"]:
            raise ValueError(f"hero {hid}: invalid identity")
        if type(profile["attack_delay_ms"]) is not int or profile["attack_delay_ms"] <= 0:
            raise ValueError(f"hero {hid}: invalid attack delay")
        damage_types = {"物理": "1;6", "火": "0;106;102;6", "自然": "0;106;107;6", "冰": "0;106;104;6", "电": "0;106;109;6"}
        if profile["damage_type"] != damage_types[profile["element"]]:
            raise ValueError(f"hero {hid}: invalid damage element")
        hero = heroes[hid]
        old_name = hero["name"]
        hero.update({key: profile[key] for key in ["name", "race", "element", "damage_type", "attack_delay_ms"]})
        hero["description"] = ""
        hero["tags"][0] = {"title": profile["race"], "res": "gameIcon:heroType6" if profile["race"] == "人类" else "gameIcon:heroType7"}
        for option in options.values():
            if option.get("type") == [int(hid)]:
                option["description"] = option["description"].replace(old_name, profile["name"])
        entry = profile
        root, trigger, groups = entry["option"], entry["trigger"], entry["groups"]
        if type(root) is not int or str(root) not in original or not original[str(root)]["icon_res"]:
            raise ValueError(f"hero {hid}: invalid or duplicate initial option")
        if type(trigger) is not int or trigger < 0 or (trigger and str(trigger) not in catalog["skills"]):
            raise ValueError(f"hero {hid}: unknown trigger skill")
        unlocked = [int(s) for s in original[str(root)].get("unlock", []) if int(s) > 0]
        if (trigger and trigger not in unlocked) or (not trigger and unlocked):
            raise ValueError(f"hero {hid}: trigger does not belong to its initial option")
        if not isinstance(groups, list) or not groups or any(type(g) is not int or str(g) not in skill_icons for g in groups) or len(set(groups)) != len(groups):
            raise ValueError(f"hero {hid}: invalid skill groups")
        owner = original[str(root)]["type"]
        family = {str(oid) for oid in sets[hid]} if hid in sets else {key for key, row in original.items() if row.get("type") == owner and str(row.get("icon", "")).split(":")[0] in {str(g) for g in groups}}
        if hid in sets:
            if str(root) not in family or any(key not in original or original[key].get("type") != [int(hid)] for key in family):
                raise ValueError(f"hero {hid}: invalid option ownership")
            if len({original[key]["term_id"] for key in family}) != len(family):
                raise ValueError(f"hero {hid}: duplicate term ID")
            capability = catalog["skills"].get(str(trigger), {}).get("thorn_armor")
            if capability:
                scoped_fields = {"__id__", "id", "title", "description", "icon", "icon_res", "type",
                                 "term_id", "term_type", "draw_weight", "recruit_weight", "options_num",
                                 "premise1", "premise2", "unlock", "aim_skill", "thorn_mod"}
                if entry.get("equip_skill"):
                    raise ValueError(f"hero {hid}: thorn armor terms cannot grant global passives")
                combined = copy.deepcopy(capability)
                for oid in family:
                    row = original[oid]
                    if set(row) - scoped_fields or row.get("unlock", []) != ([trigger] if int(oid) == root else []):
                        raise ValueError(f"option {oid}: thorn armor terms must stay within their skill")
                    if int(oid) != root and (row.get("aim_skill") != [trigger] or not row.get("thorn_mod")):
                        raise ValueError(f"option {oid}: thorn armor upgrade must target only its initial skill")
                    for field, value in row.get("thorn_mod", {}).items():
                        combined[field] = value if type(value) is bool else combined[field] + value * row["options_num"]
                validate_thorns(combined, catalog)
            capability = catalog["skills"].get(str(trigger), {}).get("ice_arrows")
            if capability:
                combined = copy.deepcopy(capability)
                for oid in family:
                    row = original[oid]
                    for field, value in row.get("ice_mod", {}).items():
                        combined[field] = value if type(value) is bool else combined[field] + value * row["options_num"]
                validate_ice(combined, catalog)
            capability = catalog["skills"].get(str(trigger), {}).get("assassination")
            if capability:
                combined = copy.deepcopy(capability)
                for oid in family:
                    row = original[oid]
                    for field, value in row.get("assassination_mod", {}).items():
                        combined[field] = value if type(value) is bool else combined[field] + value * row["options_num"]
                validate_assassination(combined, catalog)
        family.add(str(root))
        for key in family:
            if key in retained:
                raise ValueError(f"option {key}: overlapping hero skill families")
            retained[key] = (int(hid), root)
        base = options[str(root)]
        base["trigger_skill"] = trigger
        if "recruit_weight" in base:
            hero["recruit_weight"] = base["recruit_weight"]
        if "equip_skill" in entry:
            if not isinstance(entry["equip_skill"], list) or any(not isinstance(p, str) or not re.fullmatch(r"[0-9]+:[0-9]+", p) or p.split(":")[0] not in catalog["passives"] for p in entry["equip_skill"]):
                raise ValueError(f"hero {hid}: invalid inherited passive")
            base["equip_skill"] = copy.deepcopy(entry["equip_skill"])
        heroes[hid]["initial_options"] = [root]
    for key, row in list(options.items()):
        if key not in retained and any(str(h) in source["heroes"] for h in row.get("type", [])):
            del options[key]
    for key, (hid, root) in retained.items():
        row = options[key]
        row["type"] = [hid]
        row["root_option"] = root
        row["active"] = int(options[str(root)].get("active", 0))
        if int(key) == root:
            row.update(isNew=1, options_num=1 if str(hid) in sets else 0, premise1=[], premise2=[])
        else:
            for field in ["premise1", "premise2"]:
                conditions = []
                for condition in row.get(field, []):
                    if len(condition) != 2 or str(int(condition[0])) not in original:
                        raise ValueError(f"option {key}: unknown prerequisite")
                    target, count = int(condition[0]), condition[1]
                    if str(hid) in sets and (str(target) not in retained or retained[str(target)][0] != hid or type(count) is not int or count != 1):
                        raise ValueError(f"option {key}: invalid explicit prerequisite")
                    # A removed old entry skill becomes this family's new base.
                    if str(target) not in options or (str(target) in retained and retained[str(target)][0] != hid):
                        if count < 0:
                            continue
                        target = root
                    pair = [target, count]
                    if pair not in conditions:
                        conditions.append(pair)
                row[field] = conditions
    for hid, ids in sets.items():
        reached = {source["heroes"][hid]["option"]}
        for _ in ids:
            for oid in ids:
                row = options[str(oid)]
                if all(p[0] in reached for p in row.get("premise1", [])) and (not row.get("premise2") or any(p[0] in reached for p in row["premise2"])):
                    reached.add(oid)
        if reached != set(ids):
            raise ValueError(f"hero {hid}: cyclic or unreachable prerequisites")
    # Kept locked heroes remain readable in the gallery; no scalar legacy field.
    for hero in heroes.values():
        for root in hero["initial_options"]:
            option = options[str(root)]
            option.setdefault("trigger_skill", int(str(option.get("icon", "0")).split(":")[0]))
    for key, skill in catalog["skills"].items():
        if any(str(int(aim)) not in catalog["targets"] for aim in skill.get("aim", [])):
            raise ValueError(f"skill {key}: unknown target")
        if any(str(int(status[0])) not in catalog["statuses"] for status in skill.get("statusChange", [])):
            raise ValueError(f"skill {key}: unknown status")
        if any(str(int(child[1])) not in catalog["skills"] and int(child[1]) not in KNOWN_MISSING for child in skill.get("skillGroupType", [])):
            raise ValueError(f"skill {key}: unknown child")
    return catalog


def compile_catalog(reference, art, combat, rules, hero_roster):
    if reference.get("schema_version") != 1 or art.get("schema_version") != 1:
        raise ValueError("unsupported defense schema")
    if combat.get("schema_version") != 1:
        raise ValueError("unsupported combat metadata schema")
    world = combat.get("world", {})
    lines = ["warning_y", "patrol_y", "retreat_y", "rear_threat_y"]
    if "back_y" in world or any(type(world.get(key)) not in [int, float] for key in lines):
        raise ValueError("invalid battle patrol lines")
    if not (0 <= world["warning_y"] <= world["patrol_y"] <= world["retreat_y"] < world["wall_y"] <= world["bottom"]
            and 0 <= world["rear_threat_y"] <= world["patrol_y"]):
        raise ValueError("invalid battle patrol lines")
    art = ui_art(art)
    validate_rules(rules, world)
    for row in combat["formation"].values():
        if len(row) != 4 or any(len(points) != index + 1 for index, points in enumerate(row)):
            raise ValueError("invalid hero formation")
    for actor in combat["actors"].values():
        for field in ["base_size", "shadow_size", "buff_size", "buff_offset", "hp_scale", "overlays"]:
            if field not in actor:
                raise ValueError(f"missing actor visual metadata: {field}")
        if any(value <= 0 for frames in actor["frames"].values() for value in frames):
            raise ValueError("invalid actor action timing")
    for status in reference["status2"].values():
        for effect in status.get("effect", []):
            name = effect[0]
            if name not in KNOWN_MISSING_EFFECTS and (name not in combat["buff_effects"] or "bulletStatus:" + name not in art["animations"]):
                raise ValueError(f"missing status effect: {name}")
    combat = copy.deepcopy(combat)
    del combat["revival"]
    for row, points in rules["formation_five"].items():
        combat["formation"][row].append(copy.deepcopy(points))
    result = {"schema_version": 14, "rules": copy.deepcopy(rules), "combat": combat, "heroes": {}, "skills": copy.deepcopy(reference["skill2"]),
              "statuses": copy.deepcopy(reference["status2"]), "targets": copy.deepcopy(reference["target2"]), "passives": reference["equip_skill"],
              "spawn_policy": {"pressure_count": reference["function_price"]["111"]["price"], "pressure_delay_ms": reference["function_price"]["112"]["price"]},
              "monsters": copy.deepcopy(reference["monster"]), "summons": copy.deepcopy(reference["entity"]),
              "attributes": copy.deepcopy(reference["attribute"]), "options": {}, "levels": {}, "selection": reference.get("level_buff", {}),
              "art": art, "baseline": {"hero_level": 1, "wall_hp": 3900, "external_bonus": 0},
              "missing_skill_ids": sorted(KNOWN_MISSING)}
    result["loot"] = compile_loot(reference)
    text = {}
    for rows in reference["chinese"].values():
        text.update(rows)
    def label(value):
        return clean_text(text.get(str(value), ""))
    option_rows = reference["upgrade_options"]
    for key, hero in reference["lead"].items():
        hid = int(key)
        initial = [int(k) for k, row in option_rows.items() if row.get("type") == [hid] and row.get("isNew") == 1]
        base = {k: float(v) for k, v in hero["base"].items()}
        profession = str(hero["label"][1])
        if profession not in rules["revive_seconds"]:
            raise ValueError(f"hero {key}: unknown profession {profession}")
        base["23"] = float(rules["revive_seconds"][profession])
        result["heroes"][key] = {"id": hid, "name": label(hero["name"]), "description": label(hero.get("desTra", "")),
            "res": hero["res"], "front": not bool(hero.get("missile_effect")), "class": hero.get("class", []), "profession": int(profession),
            "base": base, "initial_options": initial[:1], "skills": hero.get("skill", []),
            "attack_delay_ms": math.floor(500000 / (100 + max(25, base["6"]))), "damage_type": "1;6",
            "corpse": hero.get("corpse", 0),
            "available": bool(initial), "reason": "" if initial else "当前资料缺少专属技能"}
        tag_names = result["heroes"][key]["description"].split("，")
        tag_ids = hero["label"]
        if len(tag_names) != len(tag_ids):
            raise ValueError(f"hero {key}: label count mismatch")
        result["heroes"][key]["tags"] = [
            {"title": name, "res": f"gameIcon:heroType{tag_id}"}
            for name, tag_id in zip(tag_names, tag_ids)
        ]
        for tag in result["heroes"][key]["tags"]:
            if tag["res"] not in art["sprites"]:
                raise ValueError(f"hero {key}: missing tag icon {tag['res']}")
    for hid in rules["unlocked_heroes"]:
        if not result["heroes"].get(str(hid), {}).get("available", False):
            raise ValueError(f"unlocked hero {hid}: unknown or incomplete hero")
    for key, option in option_rows.items():
        if not option.get("name") or option.get("isNew", 0) < 0:
            continue
        value = option.copy()
        value["title"] = option.get("title", label(option["name"]))
        value["description"] = option.get("description", label(option.get("desTra", "")))
        value["id"] = int(key)
        if option.get("options_num", 0) > 0 and option.get("isNew", 0) >= 0 and any(h > 0 for h in option.get("type", [])):
            parts = str(option.get("icon", "")).split(":")
            if len(parts) != 2 or parts[1] not in {"1", "2", "3", "4", "5"}:
                raise ValueError(f"option {key}: invalid chest quality")
        icon_id = str(option.get("icon", "")).split(":")[0]
        value["icon_res"] = ""
        if icon_id:
            if icon_id not in reference["skill_icon"]:
                raise ValueError(f"option {key}: unknown icon {icon_id}")
            value["icon_res"] = "gameIcon:" + reference["skill_icon"][icon_id]["icon"]
            if value["icon_res"] not in art["sprites"]:
                raise ValueError(f"option {key}: missing icon sprite {value['icon_res']}")
        result["options"][key] = value
        for raw in option.get("unlock", []):
            sid = abs(int(raw))
            if str(sid) not in result["skills"] and sid not in KNOWN_MISSING:
                raise ValueError(f"option {key}: unknown skill {sid}")
    for key, skill in result["skills"].items():
        for group in skill.get("skillGroupType", []):
            sid = int(group[1])
            if str(sid) not in result["skills"] and sid not in KNOWN_MISSING:
                raise ValueError(f"skill {key}: unknown child {sid}")
    for unit in result["summons"].values():
        unit["title"] = label(unit.get("name", ""))
    for details in reference["level_details"]:
        lid = details["关卡"]
        validate_result_rewards(reference["enemyLevel"][str(lid)].get("reward", []))
        source_waves = [w for w in reference["waves"] if w["level"] == lid]
        if len(source_waves) != rules["wave_count"] or sorted(w["wave"] for w in source_waves) != list(range(1, rules["wave_count"] + 1)):
            raise ValueError(f"level {lid}: requires exactly {rules['wave_count']} unique waves")
        waves = copy.deepcopy(source_waves[:rules["wave_count"]])
        source_encounters = details["encounters"]
        if not isinstance(source_encounters, list):
            raise ValueError(f"level {lid}: invalid encounter list")
        encounters = []
        for entry in source_encounters:
            if not isinstance(entry, dict) or entry.get("kind") not in {"elite", "boss"}:
                raise ValueError(f"level {lid}: invalid encounter inputs")
            if str(entry.get("monster_id")) not in result["monsters"]:
                raise ValueError(f"level {lid}: missing encounter {entry.get('monster_id')}")
            encounter = copy.deepcopy(entry)
            encounter["id"] = int(entry["monster_id"])
            encounter["row_id"] = int(entry["id"])
            encounter["at_ms"] = int(entry["trigger_time_ms"])
            encounters.append(encounter)
        for wave in waves:
            if wave["count"] <= 0 or not wave.get("entries"):
                raise ValueError(f"level {lid} wave {wave['wave']}: invalid spawn inputs")
            for entry in wave["entries"]:
                if entry["count"] <= 0 or entry["batch_count"] <= 0 or entry["interval_ms"] < 0:
                    raise ValueError(f"level {lid} wave {wave['wave']}: invalid spawn entry")
                if str(entry["monster_id"]) not in result["monsters"] or "hp" not in result["monsters"][str(entry["monster_id"])]:
                    raise ValueError(f"level {lid}: missing monster {entry['monster_id']}")
        result["levels"][str(lid)] = {"id": lid, "chapter": details["章节"], "waves": waves,
            "enemy_hp_multiplier": reference["enemyLevel"][str(lid)]["enemy_hp_multiplier"],
            "enemy_atk_multiplier": reference["enemyLevel"][str(lid)]["enemy_atk_multiplier"],
            "atk_growth": details["攻击成长"][:rules["wave_count"]], "hp_growth": details["生命成长"][:rules["wave_count"]], "encounters": encounters,
            "raw": reference["enemyLevel"][str(lid)], "chapter_data": reference["chapter"][str(details["章节"])]}
    if len(result["levels"]) != 5:
        raise ValueError("campaign must contain 5 levels")
    for attribute in result["attributes"].values():
        attribute["title"] = label(attribute["name"])
    result["attributes"]["23"]["description"] = "阵亡后按职业倒计时复活，不消耗雕像生命。"
    for hero in result["heroes"].values():
        if hero["res"] + "_idle" not in art["animations"]:
            raise ValueError(f"hero {hero['id']}: missing idle animation")
    for animation in art["animations"].values():
        for frame in animation["frames"]:
            if frame["sprite"] not in art["sprites"] or frame["duration_ms"] < 0:
                raise ValueError("invalid animation frame")
    compile_hero_roster(result, hero_roster, reference["skill_icon"])
    result["gems"] = compile_gems(reference["gems"], result["heroes"])
    return result


def validate_home_art(art, scene_text):
    if re.search(r"atlas_\d+\.png", scene_text):
        raise ValueError("home scene must use logical sprite keys, not baked atlas page paths")
    keys = re.findall(r'^resource_key = "([^"\n]+)"$', scene_text, re.MULTILINE)
    if not keys:
        raise ValueError("home scene has no logical sprite bindings")
    for key in keys:
        if key not in art["sprites"] or art["sprites"][key].get("blank", False):
            raise ValueError(f"home scene: missing required sprite {key}")


def validate_presentation_art(art, sources):
    prefixes = {key.split(":")[0] for key in art["sprites"]} | {key.split(":")[0] for key in art["animations"]}
    for path, text in sources.items():
        if re.search(r"res://assets/runtime/defense/[^\s\"']+\.png", text) or (path.endswith(".tscn") and 'type="AtlasTexture"' in text):
            raise ValueError(f"{path}: UI must use logical sprite keys, not baked atlas page paths or regions")
        if not path.endswith("defense_atlas.gd") and re.search(r"\batlas\.pages\b|\bdraw_texture_rect_region\s*\(", text):
            raise ValueError(f"{path}: atlas pages and regions must be resolved only by DefenseAtlas")
        keys = {key for key in re.findall(r'"([A-Za-z][\w]*:[\w%]+)"', text) if key.split(":")[0] in prefixes and "%" not in key}
        keys.update(key for key in re.findall(r'\bresource_key\s*=\s*"([^"\n]+)"', text) if "%" not in key)
        keys.update(re.findall(r'\batlas\.(?:texture)\(\s*"([^"\n]+)"', text))
        keys.update(re.findall(r'\batlas\.(?:picture|stretch|draw|actor)\([^,\n]+,\s*"([A-Za-z][\w]*:[\w]+)"', text))
        for key in keys:
            if (key not in art["sprites"] and key not in art["animations"]) or art["sprites"].get(key, {}).get("blank", False):
                raise ValueError(f"{path}: missing required sprite {key}")


def validate_sprite_regions(art, page_sizes):
    if len(page_sizes) != len(art["pages"]):
        raise ValueError("atlas page dimensions missing")
    for name, sprite in art["sprites"].items():
        if sprite.get("blank", False):
            continue
        page = sprite["page"]
        if not isinstance(page, int) or not 0 <= page < len(page_sizes):
            raise ValueError(f"sprite {name}: invalid atlas page")
        x, y, w, h = sprite["rect"]
        pw, ph = page_sizes[page]
        ox, oy = sprite["offset"]
        sw, sh = sprite["size"]
        if not all(isinstance(v, int) for v in [x, y, w, h, ox, oy, sw, sh]) or not (0 <= x < x+w <= pw and 0 <= y < y+h <= ph and 0 <= ox < ox+w <= sw and 0 <= oy < oy+h <= sh):
            raise ValueError(f"sprite {name}: invalid atlas region or margins")


def validate_export_hashes(expected, actual):
    for path, digest in actual.items():
        if expected.get(path) != digest:
            raise ValueError(f"atlas page/index export mismatch: {path}; reimport the source atlas before generating data")


def build_bytes(tables_dir=defense_tables.TABLES):
    result = compile_catalog(*load_inputs(tables_dir))
    validate_home_art(result["art"], (ROOT / "scenes/defense/home.tscn").read_text(encoding="utf-8"))
    paths = sorted((ROOT / "src/features/defense/presentation").glob("*.gd")) + sorted((ROOT / "scenes/defense").glob("*.tscn")) + [ROOT / "scenes/main.tscn"]
    validate_presentation_art(result["art"], {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8") for p in paths})
    result["source_hashes"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SOURCE.glob("*.json"))}
    table_schema = read(defense_tables.SCHEMA)
    for path in [Path(tables_dir) / file["name"] for file in table_schema["files"]] + [defense_tables.SCHEMA]:
        result["source_hashes"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for path in result["art"]["pages"] + [result["art"]["font"]]:
        if not path.startswith("res://assets/runtime/defense/") or not (ROOT / path[6:]).is_file():
            raise ValueError(f"invalid runtime resource {path}")
    page_sizes = []
    page_hashes = {}
    for path in result["art"]["pages"]:
        page_hashes[path[6:]] = hashlib.sha256((ROOT / path[6:]).read_bytes()).hexdigest()
        with Image.open(ROOT / path[6:]) as image:
            page_sizes.append(image.size)
    validate_export_hashes(read(ROOT / "art_source/defense/provenance.json")["runtime_sha256"], page_hashes)
    validate_sprite_regions(result["art"], page_sizes)
    return (json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "check"])
    parser.add_argument("--tables-dir", type=Path, default=defense_tables.TABLES, help="directory containing the eight workbooks")
    parser.add_argument("--output", type=Path, default=OUTPUT, help="generated runtime JSON")
    args = parser.parse_args()
    try:
        output = build_bytes(args.tables_dir)
        if args.command == "build":
            args.output.parent.mkdir(parents=True, exist_ok=True)
            descriptor, temporary = tempfile.mkstemp(prefix=".defense-", suffix=".tmp", dir=args.output.parent)
            try:
                with os.fdopen(descriptor, "wb") as handle:
                    handle.write(output)
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(temporary, args.output)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        elif not args.output.exists() or args.output.read_bytes() != output:
            raise ValueError("defense catalog drift; run python tools/project.py data")
        unlocked_count = len(read(SOURCE / "rules.json")["unlocked_heroes"])
        level_count = len(json.loads(output).get("levels", {}))
        print(f"[OK] defense catalog: 18 hero entries, {unlocked_count} unlocked, 5 hero slots, {level_count} levels, {level_count * read(SOURCE / 'rules.json')['wave_count']} waves")
        if args.command == "build":
            print(f"[OK] 导表成功，运行数据已更新：{args.output}")
        return 0
    except (ValueError, KeyError, OSError, ImportError, zipfile.BadZipFile) as error:
        print(f"[FAIL] defense catalog: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
