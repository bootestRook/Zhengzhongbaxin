"""Read the authoritative Chinese workbooks; never write authoring files."""
from __future__ import annotations

import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TABLES = ROOT / "data/source/defense_tables"
SCHEMA = ROOT / "data/schema/defense_tables.json"


def fail(path, sheet, row, field, message, value=None):
    raise ValueError(f"[{Path(path).name}/{sheet}:{row}:{field}] {message}; actual={value!r}")


def typed(value, spec, path, sheet, row):
    label = spec["label"]
    if value is None:
        if spec.get("required", False):
            fail(path, sheet, row, label, "必填项不能为空")
        return None
    if isinstance(value, str) and value.startswith("="):
        fail(path, sheet, row, label, "请填写数值或文本，不允许公式", value)
    kind = spec["type"]
    valid = (kind == "text" and isinstance(value, str)) or (kind == "bool" and type(value) is bool)
    if kind == "any":
        valid = type(value) in (str, int, float, bool) and (not isinstance(value, float) or math.isfinite(value))
    if kind in {"int", "number"}:
        valid = type(value) in (int, float) and math.isfinite(value)
        if kind == "int":
            valid = valid and value == int(value)
        if valid and "min" in spec:
            valid = value >= spec["min"]
        if valid and "max" in spec:
            valid = value <= spec["max"]
    if not valid:
        fail(path, sheet, row, label, f"类型/范围错误，期望 {kind}", value)
    if kind == "text" and value == "〈空文本〉":
        return ""
    return int(value) if kind == "int" else value


def read_sheet(book, path, spec):
    name, columns = spec["name"], spec["columns"]
    if name not in book.sheetnames:
        fail(path, name, 1, "工作表", "缺少必要工作表")
    sheet = book[name]
    rows = sheet.iter_rows(values_only=False)
    header = next(rows, ())
    labels = [cell.value for cell in header]
    while labels and labels[-1] is None:
        labels.pop()
    expected = [col["label"] for col in columns]
    if len(labels) != len(set(labels)) or set(labels) != set(expected):
        fail(path, name, 1, "表头", f"中文列须完整且不重复，期望 {expected}", labels)
    positions = {label: index for index, label in enumerate(labels)}
    result = []
    seen = set()
    for row_number, cells in enumerate(rows, 2):
        values = [cell.value for cell in cells]
        if not any(value is not None for value in values):
            continue
        if any(cell.data_type in {"f", "e"} for cell in cells):
            fail(path, name, row_number, "单元格", "不接受公式或 Excel 错误，请粘贴实际值")
        record = {}
        for col in columns:
            index = positions[col["label"]]
            value = values[index] if index < len(values) else None
            record[col["key"]] = typed(value, col, path, name, row_number)
        key = tuple(record[field] for field in spec["pk"])
        if key in seen:
            fail(path, name, row_number, "主键", "重复记录，请修改编号", key)
        seen.add(key)
        record["_row"] = row_number
        record["_empty"] = spec.get("empty_fields", {}).get(str(record.get("id")), [])
        result.append(record)
    return result


def restore_tree(rows, path, sheet):
    result = {}
    def tree_order(row):
        tokens = row["path"].split("/") if row["path"] else []
        return (row["id"], row["field"], len(tokens),
                tuple((0, int(token)) if token.isdecimal() else (1, token) for token in tokens))
    for row in sorted(rows, key=tree_order):
        owner, field, tokens = row["id"], row["field"], row["path"].split("/") if row["path"] else []
        kind, value = row["kind"], row["value"]
        if kind == "列表":
            value = []
        elif kind == "对象":
            value = {}
        elif kind == "空值":
            value = None
        else:
            types = {"整数": "int", "小数": "number", "文本": "text", "布尔": "bool"}
            if kind not in types:
                fail(path, sheet, row["_row"], "值类型", "未知类型", kind)
            value = typed(value, {"label": "参数值", "type": types[kind], "required": kind != "文本"}, path, sheet, row["_row"])
            if kind == "文本" and value is None:
                value = ""
        target = result.setdefault(owner, {})
        try:
            if not tokens:
                target[field] = value
                continue
            target = target[field]
            for token in tokens[:-1]:
                target = target[int(token)] if isinstance(target, list) else target[token]
            last = tokens[-1]
            if isinstance(target, list):
                index = int(last)
                if index < 0 or index > len(target):
                    raise ValueError("noncontiguous list")
                if index == len(target):
                    target.append(value)
                else:
                    raise ValueError("duplicate list index")
            else:
                target[last] = value
        except (KeyError, IndexError, ValueError, TypeError) as exc:
            fail(path, sheet, row["_row"], "参数路径", f"父项缺失或列表下标不连续: {exc}", row["path"])
    return result


def load_tables(directory=TABLES):
    from openpyxl import load_workbook
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    output = {}
    for file in schema["files"]:
        path = Path(directory) / file["name"]
        if not path.is_file():
            fail(path, "", 0, "文件", "缺少配置文件")
        book = load_workbook(path, read_only=True, data_only=False, keep_links=False)
        try:
            if set(book.sheetnames) != {sheet["name"] for sheet in file["sheets"]}:
                fail(path, "", 0, "工作表", "工作表被新增、删除或重命名", book.sheetnames)
            for spec in file["sheets"]:
                rows = read_sheet(book, path, spec)
                if spec["kind"] == "tree":
                    output[spec["target"]] = restore_tree(rows, path, spec["name"])
                else:
                    output[spec["target"]] = rows
        finally:
            book.close()
    return output, schema


def records(data, name):
    rows, details = data[name], data.get(name + ".details", {})
    output, patches = {}, {}
    valid_ids = {str(row["id"]) for row in rows}
    if set(details) - valid_ids:
        raise ValueError(f"{name}: 明细引用了不存在的记录 {set(details) - valid_ids}")
    for row in rows:
        key = str(row["id"])
        value = {k: copy.deepcopy(v) for k, v in row.items() if k not in {"_row", "_empty", "id", "layer", "label"} and v is not None}
        value.update({field: [] for field in row.get("_empty", [])})
        # The actual data id lives in __id__; id here is only the worksheet key.
        value.update(copy.deepcopy(details.get(key, {})))
        if name == "options":
            value["id"] = int(key)
        if name in {"monsters", "summons"}:
            for field in ["hp", "atk"]:
                if field + "_growth" in value and field + "_base" not in value:
                    raise ValueError(f"{name} id={key}: 等级增量缺少基础值")
                if field + "_base" in value:
                    parts = [format(value.pop(field + "_base"), ".15g")]
                    if field + "_growth" in value:
                        parts.append(format(value.pop(field + "_growth"), ".15g"))
                    value[field] = ":".join(parts)
        if "__id__" in value and (type(value["__id__"]) is not int or value["__id__"] != int(key)):
            raise ValueError(f"{name} id={key}: 定义编号必须与记录编号一致")
        layer = row.get("layer", "基础")
        if layer not in {"基础", "英雄覆盖", "英雄新增"}:
            raise ValueError(f"{name} id={key}: 未知定义层 {layer}")
        if layer != "英雄新增" or name != "options":
            output[key] = value
        if layer != "基础":
            patches[key] = value
    return output, patches


def assemble(reference, art, combat, rules, directory=TABLES):
    data, schema = load_tables(directory)
    reference = copy.deepcopy(reference)
    reference["gems"] = data["gems"]
    roster = {"schema_version": 2, "heroes": {}, "option_sets": {}}
    for name, raw in [("skills", "skill2"), ("statuses", "status2"), ("targets", "target2"), ("options", "upgrade_options")]:
        reference[raw], roster[name] = records(data, name)
    for key in roster["skills"]:
        reference["skill2"][key] = {k: copy.deepcopy(v) for k, v in reference["skill2"][key].items()
                                    if k not in {"fireball", "thorn_armor", "ice_arrows", "assassination"}}
    for name, raw in [("monsters", "monster"), ("summons", "entity"), ("passives", "equip_skill")]:
        reference[raw] = records(data, name)[0]
    roster["heroes"] = records(data, "profiles")[0]
    hero_bases = {str(row["id"]): {key[2:]: value for key, value in row.items() if key.startswith("a_")} for row in data["hero_bases"]}
    if set(hero_bases) != set(reference["lead"]):
        raise ValueError("英雄属性: 必须覆盖全部现有英雄编号")
    for key, values in hero_bases.items():
        if values["1"] <= 0 or values["4"] < 0:
            raise ValueError(f"英雄属性 id={key}: 生命必须大于零，攻击不能小于零")
        reference["lead"][key]["base"] = values
    for key, row in roster["options"].items():
        if row.get("term_id") and row.get("type"):
            hid = str(row["type"][0])
            roster["option_sets"].setdefault(hid, []).append(int(key))
    # Keep the original explicit family order; group membership is authored once.
    for ids in roster["option_sets"].values():
        ids.sort()
    levels = {int(row["id"]): row for row in data["levels"]}
    if set(levels) != set(range(1, 6)):
        raise ValueError("关卡配置: 当前须覆盖关卡 1 至 5")
    waves, encounters = {}, {}
    source_levels = set()
    kind_names = {None: "normal", "": "normal", 2: "elite", 3: "boss"}
    for row in data["waves"]:
        source_level = int(row["source_level"])
        lid = source_level - 1000
        wave_number = int(row["wave"])
        source_levels.add(source_level)
        if lid not in levels or not 1 <= wave_number <= rules["wave_count"]:
            raise ValueError(f"刷怪配置:{row['_row']}: 关卡或波次不在当前开放范围")
        if str(row["monster_id"]) not in reference["monster"]:
            raise ValueError(f"刷怪配置:{row['_row']}: 怪物ID={row['monster_id']} 不存在")
        code = row["kind_code"]
        if type(code) is float and code.is_integer():
            code = int(code)
        if type(code) is bool or code not in kind_names:
            raise ValueError(f"刷怪配置:{row['_row']}: 波次类型只能为空、2或3")
        kind = kind_names[code]
        trigger_time_ms = round(float(row["trigger_time_sec"]) * 1000)
        interval_ms = round(float(row["interval_sec"]) * 1000)
        entry = {
            "id": int(row["row_id"]), "kind": kind, "wave": wave_number,
            "trigger_time_ms": trigger_time_ms, "monster_id": int(row["monster_id"]),
            "count": int(row["count"]), "fluctuation": float(row["fluctuation"] or 0),
            "interval_ms": interval_ms, "batch_count": int(row["batch_count"]),
            "distribution": int(row["distribution"]), "atk_multiplier": float(row["atk_multiplier"]),
            "hp_multiplier": float(row["hp_multiplier"]), "health_bars": int(row["health_bars"]),
            "trigger_type": int(row["trigger_type"]), "death_trigger": row["death_trigger"],
            "trigger_param1": row["trigger_param1"], "trigger_param2": row["trigger_param2"],
        }
        waves.setdefault(lid, {}).setdefault(wave_number, []).append(entry)
        if kind in {"elite", "boss"}:
            encounters.setdefault(lid, []).append(copy.deepcopy(entry))
    if source_levels != set(range(1001, 1006)):
        raise ValueError("刷怪配置: 当前须覆盖 1001 至 1005 五个测试关卡")
    reference["waves"], reference["level_details"] = [], []
    for lid, level in sorted(levels.items()):
        current = waves.get(lid, {})
        if sorted(current) != list(range(1, rules["wave_count"] + 1)):
            raise ValueError(f"刷怪配置: 关卡 {lid} 的波次必须完整覆盖 1 至 {rules['wave_count']}")
        for wave_number in current:
            current[wave_number].sort(key=lambda entry: (entry["trigger_time_ms"], entry["id"]))
        chapter = reference["chapter"][str(level["chapter"])]
        raw = reference["enemyLevel"][str(lid)]
        for source_key, target_key in [("hp_up", "hp_add"), ("atk_up", "atk_add")]:
            value = level[target_key] - chapter.get(source_key, 0)
            if value != 0 or source_key in raw:
                raw[source_key] = value
        raw["enemy_hp_multiplier"], raw["enemy_atk_multiplier"] = level["hp_multiplier"], level["atk_multiplier"]
        reference["waves"].extend({"level": lid, "wave": wave_number,
                                    "count": sum(entry["count"] for entry in current[wave_number]),
                                    "entries": copy.deepcopy(current[wave_number])}
                                   for wave_number in sorted(current))
        reference["level_details"].append({"关卡": lid, "章节": level["chapter"],
                                           "encounters": sorted(encounters.get(lid, []), key=lambda entry: (entry["wave"], entry["trigger_time_ms"], entry["id"])),
                                           "攻击成长": [0 for _ in range(rules["wave_count"])],
                                           "生命成长": [0 for _ in range(rules["wave_count"]) ]})
    return [reference, art, combat, rules, roster], schema
