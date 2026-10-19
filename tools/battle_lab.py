"""Launch the shared battle laboratory or run explicitly selected suites."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

import project

ROOT = Path(__file__).resolve().parents[1]
SUITES = ('controls', 'heroes', 'cases', 'ui', 'coverage', 'profile')

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('run', 'test', 'case'))
    parser.add_argument('--suite', choices=SUITES, default='controls')
    parser.add_argument('--case', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--godot', default='')
    args = parser.parse_args(argv)
    if args.command == 'case' and args.case is None:
        parser.error('case requires --case FILE')
    if args.case is not None and not args.case.is_file():
        parser.error('case file does not exist')
    if args.capture and (args.command != 'test' or args.suite != 'ui'):
        parser.error('--capture requires test --suite ui')
    godot = project.find_godot(args.godot)
    if not godot:
        print('[FAIL] Godot not found; set GODOT_BIN or pass --godot')
        return 1
    destination = ROOT/'validation'/'battle_lab'
    destination.mkdir(parents=True, exist_ok=True)
    command = [godot, '--language', 'en', '--path', str(ROOT)]
    if args.command == 'run':
        command += ['res://scenes/defense_lab.tscn']
        if args.case: command += ['--', '--case', str(args.case.resolve())]
        with (destination/'latest_run.log').open('w', encoding='utf-8') as log:
            process = subprocess.Popen(command, cwd=ROOT, env=project.process_environment(), stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0)
        print(f'Battle laboratory started (PID {process.pid}); log: {destination / "latest_run.log"}')
        return 0
    suite = 'case' if args.command == 'case' else args.suite
    output = (args.output or destination/f'{suite}.json').resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    if not args.capture: command.append('--headless')
    command += ['--script', 'res://tests/lab_runner.gd', '--', '--suite', suite, '--output', str(output)]
    if args.case: command += ['--input', str(args.case.resolve())]
    if args.capture: command.append('--capture')
    began = time.perf_counter()
    try:
        result = subprocess.run(command, cwd=ROOT, env=project.process_environment(), capture_output=True, timeout=300)
    except subprocess.TimeoutExpired:
        print('[FAIL] laboratory timed out after 300 seconds')
        return 1
    text = (result.stdout.decode('utf-8', errors='strict') + result.stderr.decode('utf-8', errors='strict')).replace('\r\n', '\n').replace('\r', '')
    (destination/f'{suite}.log').write_text(text, encoding='utf-8', newline='\n')
    print(text.rstrip())
    failed = result.returncode != 0 or any(marker in text for marker in project.ERROR_MARKERS) or not output.is_file()
    if not failed:
        report = json.loads(output.read_text(encoding='utf-8'))
        failed = not report.get('assertions', 0) or bool(report.get('failures'))
    print(f'[{"FAIL" if failed else "OK"}] laboratory {suite}: {time.perf_counter() - began:.2f}s; {output}')
    return int(failed)

if __name__ == '__main__':
    raise SystemExit(main())
