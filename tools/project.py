#!/usr/bin/env python3
"""Project paths for data, assets, AbilityGraph plans, runtime, and checks."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ERROR_MARKERS = ("SCRIPT ERROR:", "ERROR:", "TEST FAILURE:")


def process_environment() -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(
        {
            "LANG": "en_US.UTF-8",
            "LANGUAGE": "en",
            "LC_ALL": "C.UTF-8",
            "PYTHONUTF8": "1",
            "PYTHONIOENCODING": "utf-8",
        }
    )
    return environment


def find_godot(hint: str = "") -> str | None:
    candidates = [hint, os.environ.get("GODOT_BIN", ""), os.environ.get("GODOT4_PATH", ""), "godot4", "godot"]
    if sys.platform == "win32":
        candidates.extend(
            [
                r"C:\Program Files\Godot\Godot_v4-stable_win64_console.exe",
                r"C:\Program Files\Godot\Godot_v4-stable_win64.exe",
            ]
        )
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        path = Path(candidate)
        if path.is_file():
            return str(path)
    return None


def _decode(data: bytes) -> str:
    return data.decode("utf-8", errors="strict")


def run_command(command: list[str], label: str, scan_output: bool = False) -> bool:
    result = subprocess.run(command, cwd=PROJECT_ROOT, capture_output=True, env=process_environment())
    try:
        output = _decode(result.stdout) + _decode(result.stderr)
    except UnicodeDecodeError as exc:
        print(f"[FAIL] {label}: non-UTF-8 process output at byte {exc.start}")
        return False
    if output.strip():
        print(output.rstrip())
    marker_failure = scan_output and any(marker in output for marker in ERROR_MARKERS)
    if result.returncode != 0 or marker_failure:
        print(f"[FAIL] {label}: exit={result.returncode}, marker_failure={marker_failure}")
        return False
    print(f"[OK] {label}")
    return True


def run_tool(script: str, command: str) -> bool:
    return run_command([sys.executable, str(PROJECT_ROOT / "tools" / script), command], f"{script} {command}")


def doctor(godot_hint: str) -> bool:
    print(f"[OK] Python {sys.version.split()[0]}: {sys.executable}")
    godot = find_godot(godot_hint)
    if not godot:
        print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
        return False
    if not run_command([godot, "--version"], "Godot version"):
        return False
    return run_tool("content_pipeline.py", "check") and run_tool("asset_pipeline.py", "check")


def generate_data() -> bool:
    return run_tool("defense_pipeline.py", "build") and run_tool("content_pipeline.py", "build")


def generate_assets() -> bool:
	return run_tool("content_pipeline.py", "check") and run_tool("asset_pipeline.py", "build")


def generate_graphs(godot_hint: str) -> bool:
	godot = find_godot(godot_hint)
	if not godot:
		print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
		return False
	return run_command(
		[godot, "--headless", "--language", "en", "--path", str(PROJECT_ROOT), "--script", "res://tools/compile_ability_graphs.gd"],
		"ability graph generation",
		scan_output=True,
	)


def checks(godot_hint: str, include_smoke: bool) -> bool:
    godot = find_godot(godot_hint)
    if not godot:
        print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
        return False
    steps = [
        lambda: run_tool("defense_pipeline.py", "check"),
        lambda: run_tool("content_pipeline.py", "check"),
        lambda: run_tool("asset_pipeline.py", "check"),
        lambda: run_command([sys.executable, "tools/delivery_check.py"], "delivery check"),
        lambda: run_command([sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-v"], "Python pipeline tests"),
        lambda: run_command([sys.executable, "tools/architecture_lint.py"], "architecture lint"),
        lambda: run_command([godot, "--headless", "--language", "en", "--path", str(PROJECT_ROOT), "--editor", "--quit"], "Godot import", scan_output=True),
        lambda: run_command([godot, "--headless", "--language", "en", "--path", str(PROJECT_ROOT), "--script", "res://tests/test_runner.gd"], "Godot tests", scan_output=True),
        lambda: run_tool("release_manifest.py", "check"),
    ]
    if include_smoke:
        steps.append(lambda: run_command([godot, "--headless", "--language", "en", "--path", str(PROJECT_ROOT), "--quit-after", "5"], "runtime smoke", scan_output=True))
    return all(step() for step in steps)


def run_project(godot_hint: str) -> bool:
    godot = find_godot(godot_hint)
    if not godot:
        print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
        return False
    if not run_tool("defense_pipeline.py", "check") or not run_tool("content_pipeline.py", "check") or not run_tool("asset_pipeline.py", "check"):
        return False
    return subprocess.run([godot, "--language", "en", "--path", str(PROJECT_ROOT)], cwd=PROJECT_ROOT, env=process_environment()).returncode == 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("doctor", "data", "assets", "graphs", "run", "test", "check", "release", "scaffold"))
    parser.add_argument("--godot", default="", help="path to a Godot 4 executable")
    args = parser.parse_args(argv)
    if args.command == "doctor":
        ok = doctor(args.godot)
    elif args.command == "data":
        ok = generate_data()
    elif args.command == "assets":
        ok = generate_assets()
    elif args.command == "graphs":
        ok = generate_graphs(args.godot)
    elif args.command == "run":
        ok = run_project(args.godot)
    elif args.command == "release":
        ok = run_tool("release_manifest.py", "build")
    elif args.command == "scaffold":
        ok = run_tool("scaffold.py", "build")
    else:
        ok = checks(args.godot, include_smoke=args.command == "check")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
