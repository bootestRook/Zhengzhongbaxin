"""A successful process exit must not conceal engine error diagnostics."""
import subprocess
import unittest
from unittest.mock import patch

from tools import project


class EngineOutputTests(unittest.TestCase):
    def test_zero_exit_with_resource_error_is_rejected(self):
        result = subprocess.CompletedProcess([], 0, b'', b'ERROR: Error loading image\n')
        with patch.object(project.subprocess, 'run', return_value=result):
            with patch('builtins.print'):
                self.assertFalse(project.run_command(['godot'], 'import', scan_output=True))

    def test_clean_zero_exit_is_accepted(self):
        result = subprocess.CompletedProcess([], 0, b'[OK] Ready\n', b'')
        with patch.object(project.subprocess, 'run', return_value=result):
            with patch('builtins.print'):
                self.assertTrue(project.run_command(['godot'], 'import', scan_output=True))
