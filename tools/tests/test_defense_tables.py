import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from tools import defense_pipeline as pipeline, defense_tables as tables

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def edit_cell(path, sheet_index, cell, value, formula=False):
    """Mutate a disposable XLSX fixture without touching the user's workbooks."""
    with zipfile.ZipFile(path) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    name = f"xl/worksheets/sheet{sheet_index}.xml"
    root = ET.fromstring(files[name])
    target = root.find(f".//s:c[@r='{cell}']", NS)
    if target is None:
        raise AssertionError(f"fixture cell not found: {cell}")
    for child in list(target):
        target.remove(child)
    target.attrib.pop("t", None)
    if isinstance(value, str) and not formula:
        target.set("t", "inlineStr")
        ET.SubElement(ET.SubElement(target, "{" + NS["s"] + "}is"), "{" + NS["s"] + "}t").text = value
    elif value is not None:
        ET.SubElement(target, "{" + NS["s"] + ("}f" if formula else "}v")).text = str(value)
    files[name] = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, value in files.items():
            archive.writestr(name, value)


def edit_field(directory, target, key, value):
    """Find fixture cells by their authored headers instead of fixed offsets."""
    from openpyxl import load_workbook
    from openpyxl.utils import get_column_letter

    schema = json.loads(tables.SCHEMA.read_text(encoding="utf-8"))
    file, spec = next((file, sheet) for file in schema["files"] for sheet in file["sheets"] if sheet["target"] == target)
    path = directory / file["name"]
    book = load_workbook(path, read_only=True)
    try:
        sheet = book[spec["name"]]
        label = next(col["label"] for col in spec["columns"] if col["key"] == key)
        headers = next(sheet.values)
        cell = get_column_letter(headers.index(label) + 1) + "2"
        index = book.sheetnames.index(spec["name"]) + 1
    finally:
        book.close()
    edit_cell(path, index, cell, value)


class DefenseWorkbookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def temporary_tables(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        target = Path(temporary.name) / "中文配置"
        shutil.copytree(tables.TABLES, target, ignore=shutil.ignore_patterns("*.ndjson"))
        return target

    def accept_initial_roundtrip(self):
        actual = pipeline.compile_catalog(*self.inputs)
        self.assertEqual(set(actual["levels"]), {"1", "2", "3", "4", "5"})
        for level in actual["levels"].values():
            self.assertEqual(len(level["waves"]), 20)
            self.assertTrue(all("entries" in wave for wave in level["waves"]))
            self.assertTrue(all("enemy_pool" not in wave and "weights" not in wave for wave in level["waves"]))

    def test_eight_files_and_deterministic_generation(self):
        self.assertEqual(len(list(tables.TABLES.glob("*.xlsx"))), 8)
        _, schema = tables.load_tables()
        spawn = next(file for file in schema["files"] if file["name"] == "07_刷怪配置.xlsx")
        self.assertEqual([sheet["name"] for sheet in spawn["sheets"]], ["关卡波次配置-1测试关卡"])
        self.assertEqual(pipeline.build_bytes(), pipeline.build_bytes())

    def test_edits_reach_runtime_json(self):
        directory = self.temporary_tables()
        edit_cell(directory / "01_英雄属性与局外成长.xlsx", 1, "F2", 65)
        edit_field(directory, "skills", "cd", 11000)
        edit_field(directory, "skills", "description", "测试技能完整描述")
        edit_cell(directory / "03_英雄词条.xlsx", 1, "H2", 5200)
        edit_cell(directory / "04_Buff配置.xlsx", 1, "R2", 7)
        edit_field(directory, "monsters", "hp_base", 240)
        edit_field(directory, "monsters", "title", "测试怪物")
        edit_field(directory, "monsters", "description", "测试怪物描述")
        edit_cell(directory / "06_关卡配置.xlsx", 1, "E2", 2)
        edit_cell(directory / "06_关卡配置.xlsx", 1, "F2", 3)
        edit_field(directory, "waves", "hp_multiplier", 1.5)
        edit_field(directory, "waves", "atk_multiplier", 2.5)
        result = json.loads(pipeline.build_bytes(directory))
        self.assertEqual(result["heroes"]["4"]["base"]["4"], 65)
        self.assertEqual(result["skills"]["755"]["cd"], 11000)
        self.assertEqual(result["skills"]["755"]["description"], "测试技能完整描述")
        self.assertEqual(result["options"]["200100"]["draw_weight"], 5200)
        self.assertEqual(result["statuses"]["1"]["superposition"], 7)
        self.assertEqual(result["monsters"]["1"]["hp"], "240:20")
        self.assertEqual(result["monsters"]["1"]["title"], "测试怪物")
        self.assertEqual(result["monsters"]["1"]["description"], "测试怪物描述")
        self.assertEqual(result["levels"]["1"]["enemy_hp_multiplier"], 2)
        self.assertEqual(result["levels"]["1"]["enemy_atk_multiplier"], 3)
        self.assertEqual(result["levels"]["1"]["waves"][0]["entries"][0]["hp_multiplier"], 1.5)
        self.assertEqual(result["levels"]["1"]["waves"][0]["entries"][0]["atk_multiplier"], 2.5)
        (pipeline.ROOT / "validation/defense/xlsx_config/edited_catalog.json").write_text(json.dumps(result, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

    def test_wave_type_codes_compile_without_a_pool(self):
        from openpyxl import load_workbook
        for code, expected in [(2, "elite"), (3, "boss")]:
            directory = self.temporary_tables()
            path = directory / "07_刷怪配置.xlsx"
            book = load_workbook(path)
            book["关卡波次配置-1测试关卡"]["C2"] = code
            book.save(path)
            result = json.loads(pipeline.build_bytes(directory))
            self.assertEqual(result["levels"]["1"]["waves"][0]["entries"][0]["kind"], expected)

    def test_invalid_input_never_overwrites_previous_output(self):
        directory = self.temporary_tables()
        output = directory.parent / "runtime.json"
        output.write_bytes(b"previous working data\n")
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        cases = [("waves", "count", 0, "怪物数量"), ("waves", "monster_id", 999999, "怪物ID"),
                 ("waves", "atk_multiplier", "坏数值", "攻击系数"), ("waves", "health_bars", 0, "血条系数"),
                 ("levels", "hp_multiplier", 0, "关卡生命系数"), ("hero_bases", "a_1", None, "必填项不能为空")]
        for target, key, value, expected in cases:
            with self.subTest(target=target, key=key, value=value):
                originals = {path: path.read_bytes() for path in directory.glob("*.xlsx")}
                edit_field(directory, target, key, value)
                process = subprocess.run([sys.executable, "-X", "utf8", str(pipeline.ROOT / "tools/defense_pipeline.py"),
                                          "build", "--tables-dir", str(directory), "--output", str(output)], capture_output=True, text=True, encoding="utf-8")
                self.assertNotEqual(process.returncode, 0, process.stdout)
                self.assertIn("[FAIL]", process.stdout)
                self.assertIn(expected, process.stdout)
                self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(), digest)
                for path, original in originals.items():
                    path.write_bytes(original)

    def test_duplicate_keys_formula_and_zero_total_pool_rejected(self):
        for cell, value, formula, expected in [("B3", 1, False, "重复记录"), ("P2", "1+1", True, "不接受公式")]:
            directory = self.temporary_tables()
            edit_cell(directory / "07_刷怪配置.xlsx", 1, cell, value, formula)
            with self.assertRaisesRegex(ValueError, expected):
                pipeline.build_bytes(directory)

    def test_missing_file_is_not_filled_from_snapshot(self):
        directory = self.temporary_tables()
        (directory / "04_Buff配置.xlsx").unlink()
        with self.assertRaisesRegex(ValueError, "缺少配置文件"):
            pipeline.build_bytes(directory)

    def test_sorted_detail_rows_restore_numeric_array_order(self):
        root = {"id": "1", "field": "groups", "path": None, "kind": "列表", "value": None, "_row": 99}
        rows = [{"id": "1", "field": "groups", "path": str(i), "kind": "整数", "value": i, "_row": i + 2} for i in range(11)]
        rows = sorted(rows, key=lambda row: row["path"]) + [root]
        self.assertEqual(tables.restore_tree(rows, "fixture.xlsx", "明细"), {"1": {"groups": list(range(11))}})


if __name__ == "__main__":
    unittest.main()
