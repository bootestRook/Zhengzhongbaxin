#!/usr/bin/env python3
"""Check repository encoding, local links, concise agent rules, and required delivery files."""

from __future__ import annotations

import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {".cfg", ".csv", ".gd", ".godot", ".import", ".json", ".md", ".py", ".svg", ".uid"}
SKIP_DIRS = {".godot", "__pycache__", "build", "dist"}
LINK_PATTERN = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
REQUIRED = (
    "README.md",
    "AGENTS.md",
    "project.godot",
    "package_profiles.json",
    "scenes/main.tscn",
    "data/generated/data_catalog.json",
    "assets/generated/asset_manifest.json",
    "tools/godot_api.py",
    "tools/package.py",
    "docs/ARCHITECTURE.md",
    "docs/DATA_AND_CONFIG.md",
    "docs/ASSET_PIPELINE.md",
    "docs/EXTENDING.md",
    "docs/TESTING_AND_RELEASE.md",
    "docs/PACKAGING.md",
    "docs/WEB_EXPORT_PARITY.md",
    "docs/OFFICIAL_GODOT_DOCS.md",
)


def _files() -> list[Path]:
    return [
        path
        for path in PROJECT_ROOT.rglob("*")
        if path.is_file() and not any(part in SKIP_DIRS for part in path.relative_to(PROJECT_ROOT).parts)
    ]


def main() -> int:
    issues: list[str] = []
    files = _files()
    for required in REQUIRED:
        if not (PROJECT_ROOT / required).is_file():
            issues.append(f"missing required file: {required}")

    for path in files:
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {"LICENSE", ".editorconfig", ".gitattributes", ".gitignore"}:
            continue
        data = path.read_bytes()
        relative = path.relative_to(PROJECT_ROOT).as_posix()
        if data.startswith(b"\xef\xbb\xbf"):
            issues.append(f"UTF-8 BOM is not allowed: {relative}")
        try:
            text = data.decode("utf-8", errors="strict")
        except UnicodeDecodeError as exc:
            issues.append(f"invalid UTF-8: {relative}:{exc.start}")
            continue
        if "\ufffd" in text:
            issues.append(f"replacement character found: {relative}")
        if "\r" in text:
            issues.append(f"non-LF line ending found: {relative}")
        if path.suffix.lower() == ".md":
            for raw_target in LINK_PATTERN.findall(text):
                target = raw_target.strip().strip("<>").split("#", 1)[0]
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                resolved = (path.parent / target).resolve()
                if not resolved.is_relative_to(PROJECT_ROOT) or not resolved.exists():
                    issues.append(f"broken local link: {relative} -> {raw_target}")

    agents = PROJECT_ROOT / "AGENTS.md"
    if agents.is_file():
        agents_text = agents.read_text(encoding="utf-8", errors="strict")
        line_count = len(agents_text.splitlines())
        byte_count = len(agents_text.encode("utf-8"))
        if line_count > 70 or byte_count > 5000:
            issues.append(f"AGENTS.md is no longer concise: lines={line_count}, bytes={byte_count}")

    for core_directory in ("foundation", "runtime", "app"):
        for path in (PROJECT_ROOT / "src" / core_directory).rglob("*"):
            lowered = path.name.lower()
            if any(term in lowered for term in ("card", "deck", "combat", "monster")):
                issues.append(f"genre-specific core path found: {path.relative_to(PROJECT_ROOT).as_posix()}")

    if issues:
        print(f"[FAIL] delivery check: {len(issues)} issue(s)")
        for issue in issues:
            print(f"  {issue}")
        return 1
    print(f"[OK] delivery check: files={len(files)}, AGENTS.md<=70 lines/5000 bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
