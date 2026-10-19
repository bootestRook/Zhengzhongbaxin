#!/usr/bin/env python3
"""Build or verify a deterministic allowlisted release-input manifest."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "validation"
OUTPUT_NAME = "release_manifest.json"
ROOT_FILES = ("project.godot", "export_presets.cfg", "LICENSE", "THIRD_PARTY.md")
RUNTIME_TREES = ("scenes", "src", "data/generated", "assets/runtime", "assets/generated")
FORBIDDEN_EXPORT_ROOTS = (
    ".godot/",
    ".import/",
    "build/",
    "dist/",
    "reports/",
    "__pycache__/",
	"art_source/",
	"data/source/",
	"data/schema/",
	"authoring/",
	"addons/",
	"tools/",
    "tests/",
    "docs/",
    "validation/",
)
DEVELOPMENT_PATTERNS = (
    "scenes/defense_lab.tscn", "scenes/defense/lab_overlay.tscn",
    "src/app/lab_app.gd*", "src/platform/lab_files.gd*",
    "src/features/defense/domain/lab/*", "src/features/defense/presentation/lab/*",
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _runtime_files() -> Iterable[Path]:
    for relative in ROOT_FILES:
        path = PROJECT_ROOT / relative
        if path.is_file():
            yield path
    for relative in RUNTIME_TREES:
        root = PROJECT_ROOT / relative
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*")):
            if path.is_file() and not any(fnmatch.fnmatchcase(path.relative_to(PROJECT_ROOT).as_posix(), pattern) for pattern in DEVELOPMENT_PATTERNS):
                yield path


def _check_export_exclusions() -> None:
    preset_path = PROJECT_ROOT / "export_presets.cfg"
    text = preset_path.read_text(encoding="utf-8", errors="strict")
    for forbidden in FORBIDDEN_EXPORT_ROOTS:
        if f"{forbidden}*" not in text:
            raise ValueError(f"export presets do not exclude {forbidden}")
    for index, exclusions in enumerate(re.findall(r'^exclude_filter="([^"]*)"', text, re.MULTILINE)):
        for pattern in DEVELOPMENT_PATTERNS:
            if pattern not in exclusions.split(','):
                raise ValueError(f"export preset {index} includes development path {pattern}")


def build_manifest() -> dict:
    _check_export_exclusions()
    files = []
    seen: set[str] = set()
    for path in _runtime_files():
        relative = path.relative_to(PROJECT_ROOT).as_posix()
        if relative in seen:
            continue
        seen.add(relative)
        if any(relative.startswith(forbidden) for forbidden in FORBIDDEN_EXPORT_ROOTS):
            raise ValueError(f"forbidden path entered release allowlist: {relative}")
        files.append({"path": relative, "bytes": path.stat().st_size, "sha256": _sha256(path)})
    files.sort(key=lambda item: item["path"])
    combined = hashlib.sha256()
    for item in files:
        combined.update(item["path"].encode("utf-8"))
        combined.update(b"\0")
        combined.update(item["sha256"].encode("ascii"))
        combined.update(b"\n")
    return {
        "format_version": 1,
        "project": "Universal Godot Game Framework",
        "godot_baseline": "4.7.1",
        "generator": "tools/release_manifest.py",
        "file_count": len(files),
        "total_bytes": sum(item["bytes"] for item in files),
        "combined_sha256": combined.hexdigest(),
        "files": files,
    }


def _manifest_bytes(manifest: dict) -> bytes:
    return (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check"))
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args(argv)
    try:
        manifest = build_manifest()
        expected = _manifest_bytes(manifest)
        output_path = args.output / OUTPUT_NAME
        if args.command == "build":
            args.output.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(expected)
        elif not output_path.is_file() or output_path.read_bytes() != expected:
            print("[FAIL] release manifest is stale or missing\n[NEXT] python tools/project.py release")
            return 1
        print(f"[OK] release manifest {args.command}: files={manifest['file_count']}, bytes={manifest['total_bytes']}")
        return 0
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] release manifest: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
