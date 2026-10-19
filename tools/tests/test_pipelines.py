from __future__ import annotations

import json
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools import asset_pipeline, content_pipeline, godot_api, package as package_tool


class DataPipelineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.schema = self.root / "data_schema.json"
        self.source = self.root / "source"
        shutil.copy2(content_pipeline.DEFAULT_SCHEMA, self.schema)
        shutil.copytree(content_pipeline.DEFAULT_SOURCE, self.source)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_baseline_is_deterministic(self) -> None:
        first, counts = content_pipeline.build_outputs(self.schema, self.source)
        second, _ = content_pipeline.build_outputs(self.schema, self.source)
        self.assertEqual(first, second)
        self.assertEqual(counts["definitions"], 2)

    def test_duplicate_id_reports_source_line_and_field(self) -> None:
        path = self.source / "definitions.csv"
        rows = path.read_text(encoding="utf-8")
        path.write_text(rows + rows.splitlines()[1] + "\n", encoding="utf-8", newline="\n")
        with self.assertRaises(content_pipeline.ContentValidationError) as raised:
            content_pipeline.build_outputs(self.schema, self.source)
        issue = raised.exception.issues[0]
        self.assertEqual(issue.source, "definitions.csv")
        self.assertGreaterEqual(issue.row, 2)
        self.assertIn("id", issue.field)

    def test_bad_reference_is_rejected(self) -> None:
        path = self.source / "relations.csv"
        text = path.read_text(encoding="utf-8").replace("sample.interaction_reward", "missing.definition")
        path.write_text(text, encoding="utf-8", newline="\n")
        with self.assertRaises(content_pipeline.ContentValidationError) as raised:
            content_pipeline.build_outputs(self.schema, self.source)
        self.assertTrue(any(issue.field == "target_definition_id" for issue in raised.exception.issues))

    def test_typed_setting_and_tuning_range_are_rejected(self) -> None:
        settings = self.source / "system_settings.csv"
        settings.write_text(settings.read_text(encoding="utf-8").replace("platform,int,60", "platform,int,sixty"), encoding="utf-8", newline="\n")
        tuning = self.source / "tuning.csv"
        tuning.write_text(tuning.read_text(encoding="utf-8").replace(",20,0,100,", ",120,0,100,"), encoding="utf-8", newline="\n")
        with self.assertRaises(content_pipeline.ContentValidationError) as raised:
            content_pipeline.build_outputs(self.schema, self.source)
        fields = {issue.field for issue in raised.exception.issues}
        self.assertIn("value", fields)


class AssetPipelineTests(unittest.TestCase):
    def test_baseline_manifest_is_deterministic(self) -> None:
        first, summary = asset_pipeline.build_manifest()
        second, _ = asset_pipeline.build_manifest()
        self.assertEqual(first, second)
        self.assertEqual(summary["assets"], 119)

    def test_budget_violation_is_rejected(self) -> None:
        catalog = json.loads(asset_pipeline.DATA_CATALOG.read_text(encoding="utf-8"))
        policy = next(
            item
            for item in catalog["tables"]["resource_policies"]
            if item["id"] == "ui_vector"
        )
        policy["max_bytes"] = 1
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "catalog.json"
            path.write_text(json.dumps(catalog), encoding="utf-8", newline="\n")
            with self.assertRaises(asset_pipeline.AssetValidationError) as raised:
                asset_pipeline.build_manifest(path)
        self.assertTrue(any(issue.field == "bytes" for issue in raised.exception.issues))


class GodotApiTests(unittest.TestCase):
    def test_class_member_query_returns_exact_signature(self) -> None:
        xml = """<?xml version="1.0" encoding="UTF-8" ?>
<class name="Node" inherits="Object">
  <methods>
    <method name="add_child">
      <return type="void" />
      <param index="0" name="node" type="Node" />
      <param index="1" name="force_readable_name" type="bool" default="false" />
    </method>
  </methods>
</class>
"""
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "Node.xml"
            path.write_text(xml, encoding="utf-8", newline="\n")
            results = godot_api.query_cache(Path(temporary), "Node.add_child")
        self.assertEqual(results, ["Node.add_child(node: Node, force_readable_name: bool = false) -> void"])


class PackageProfileTests(unittest.TestCase):
    def test_unconfirmed_profile_is_blocked(self) -> None:
        config = package_tool.load_profiles()
        config["profiles"]["webapp"]["confirmation"]["resolution_and_mode_confirmed"] = False
        issues, _ = package_tool.validate_profile("webapp", config=config)
        self.assertIn("resolution/mode is not confirmed", issues)
        self.assertIn("target adaptation is not reviewed", issues)
        candidate_issues, _ = package_tool.validate_profile(
            "webapp", config=config, require_adaptation_review=False
        )
        self.assertIn("resolution/mode is not confirmed", candidate_issues)
        self.assertNotIn("target adaptation is not reviewed", candidate_issues)

    def test_confirmed_profiles_match_project_and_presets(self) -> None:
        config = package_tool.load_profiles()
        for profile in config["profiles"].values():
            for key in profile["confirmation"]:
                profile["confirmation"][key] = True
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shutil.copy2(package_tool.PROJECT_ROOT / "project.godot", root / "project.godot")
            shutil.copy2(package_tool.PROJECT_ROOT / "export_presets.cfg", root / "export_presets.cfg")
            font = root / "assets/runtime/fonts/test.ttf"
            font.parent.mkdir(parents=True)
            font.write_bytes(b"test font fixture")
            config["profiles"]["webapp"]["bundled_font_files"] = [
                "assets/runtime/fonts/test.ttf"
            ]
            for name in ("webapp", "exe"):
                with self.subTest(profile=name):
                    issues, _ = package_tool.validate_profile(name, root=root, config=config)
                    self.assertEqual(issues, [])

            # An omitted engine default is valid, but an explicit conflicting
            # aspect must still be rejected.
            project_path = root / "project.godot"
            project_text = "\n".join(line for line in project_path.read_text(encoding="utf-8").splitlines()
                                     if not line.startswith("window/stretch/aspect=")) + "\n"
            project_text = project_text.replace("window/stretch/mode=", 'window/stretch/aspect="ignore"\nwindow/stretch/mode=', 1)
            project_path.write_text(project_text, encoding="utf-8", newline="\n")
            issues, _ = package_tool.validate_profile("exe", root=root, config=config)
            self.assertIn("project stretch aspect does not match design", issues)

    def test_web_archive_has_root_index_and_size_gate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            web = root / "build/web"
            web.mkdir(parents=True)
            (web / "index.html").write_text(
                '<!doctype html><meta charset="utf-8"><title>Test</title>',
                encoding="utf-8",
                newline="\n",
            )
            (web / "index.js").write_text("start();\n", encoding="utf-8", newline="\n")
            summary = {
                "output": "build/web/index.html",
                "archive": "build/webapp.zip",
                "max_archive_bytes": 100_000_000,
            }
            archive_path, archive_bytes, _ = package_tool.write_web_archive(summary, root)
            self.assertLessEqual(archive_bytes, 100_000_000)
            with zipfile.ZipFile(archive_path) as archive:
                self.assertIn("index.html", archive.namelist())
                self.assertNotIn("web/index.html", archive.namelist())
            summary["max_archive_bytes"] = 1
            with self.assertRaisesRegex(ValueError, "limit is 1 bytes"):
                package_tool.write_web_archive(summary, root)
            self.assertFalse(archive_path.exists())

    def test_engine_cache_cleanup_is_scoped(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in (".godot", ".import"):
                cache = root / name
                cache.mkdir()
                (cache / "stale.bin").write_bytes(b"stale")
            keep = root / "keep.txt"
            keep.write_text("keep\n", encoding="utf-8", newline="\n")
            package_tool.clean_engine_caches(root)
            self.assertFalse((root / ".godot").exists())
            self.assertFalse((root / ".import").exists())
            self.assertEqual(keep.read_text(encoding="utf-8"), "keep\n")


if __name__ == "__main__":
    unittest.main()
