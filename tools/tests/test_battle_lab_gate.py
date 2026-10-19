"""The lab runner must select real work and reject false successful reports."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools import project, release_manifest

with patch.dict(sys.modules, {'project': project}):
    from tools import battle_lab


class LaboratoryGateTests(unittest.TestCase):
    def exercise(self, report, output=b'', returncode=0):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            destination = root/'result.json'
            destination.write_text('{"assertions":999,"failures":[]}', encoding='utf-8')
            calls = []

            def run(command, **kwargs):
                self.assertFalse(destination.exists(), 'stale evidence must be removed before launch')
                calls.append(command)
                if report is not None:
                    destination.write_text(json.dumps(report), encoding='utf-8')
                return subprocess.CompletedProcess(command, returncode, output, b'')

            with patch.object(battle_lab, 'ROOT', root), patch.object(project, 'find_godot', return_value='godot'), \
                    patch.object(battle_lab.subprocess, 'run', side_effect=run), patch('builtins.print'):
                result = battle_lab.main(['test', '--suite', 'controls', '--output', str(destination)])
            self.assertIn('controls', calls[0])
            self.assertIn('res://tests/lab_runner.gd', calls[0])
            self.assertNotIn('res://tests/test_runner.gd', calls[0])
            return result

    def test_successful_nonzero_selection(self):
        self.assertEqual(self.exercise({'assertions': 3, 'failures': []}), 0)

    def test_error_marker_fails_even_with_zero_exit(self):
        self.assertEqual(self.exercise({'assertions': 3, 'failures': []}, b'SCRIPT ERROR: broken\n'), 1)

    def test_stale_missing_zero_and_failed_results_are_rejected(self):
        for report in [None, {'assertions': 0, 'failures': []}, {'assertions': 1, 'failures': ['incorrect']}]:
            with self.subTest(report=report):
                self.assertEqual(self.exercise(report), 1)
        self.assertEqual(self.exercise({'assertions': 3, 'failures': []}, returncode=1), 1)

    def test_unknown_suite_fails_selection(self):
        with patch('sys.stderr'), self.assertRaises(SystemExit) as failure:
            battle_lab.main(['test', '--suite', 'not-a-suite'])
        self.assertEqual(failure.exception.code, 2)

    def test_export_and_manifest_exclude_lab_from_every_platform(self):
        release_manifest._check_export_exclusions()
        paths = [p.relative_to(release_manifest.PROJECT_ROOT).as_posix() for p in release_manifest._runtime_files()]
        self.assertIn('scenes/main.tscn', paths)
        self.assertNotIn('scenes/defense_lab.tscn', paths)
        self.assertFalse(any('/lab/' in p or p.endswith('/lab_app.gd') or p.endswith('/lab_files.gd') for p in paths))

    def test_one_platform_missing_lab_exclusion_is_rejected(self):
        source = (release_manifest.PROJECT_ROOT/'export_presets.cfg').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'export_presets.cfg').write_text(source.replace(',scenes/defense_lab.tscn', '', 1), encoding='utf-8')
            with patch.object(release_manifest, 'PROJECT_ROOT', root), self.assertRaises(ValueError):
                release_manifest._check_export_exclusions()
