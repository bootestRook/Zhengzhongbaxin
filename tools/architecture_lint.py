#!/usr/bin/env python3
"""Enforce the small set of architecture rules that should not rely on prompts."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
MAX_SCRIPT_LINES = 260
FORBIDDEN_GAME_RANDOM = re.compile(r"\b(?:randi|randf|randi_range|randf_range)\s*\(|RandomNumberGenerator\.new\s*\(")
DEFINITION_BRANCH = re.compile(r"(?:if|match)[^\n]*(?:definition_id|content_id)[^\n]*(?:==|\bmatch\b)[^\n]*['\"]")
DYNAMIC_FIXED_UI = re.compile(r"\b(?:Button|Label|Panel|PanelContainer|Control|MarginContainer|VBoxContainer|HBoxContainer)\.new\s*\(")
COMMERCIAL_MARKERS = ("slay the spire", "megacrit", "sts2")


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"[{self.rule}] {self.path}:{self.line} {self.message}"


def _relative(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _scan_script(path: Path, findings: list[Finding]) -> None:
    relative = _relative(path)
    text = path.read_text(encoding="utf-8", errors="strict")
    lines = text.splitlines()
    if len(lines) > MAX_SCRIPT_LINES:
        findings.append(Finding("script_size", relative, 1, f"{len(lines)} lines exceeds {MAX_SCRIPT_LINES}"))

    normalized = relative.lower()
    pure_domain = "/domain/" in normalized or normalized.startswith("src/foundation/") or normalized.startswith("src/runtime/")
    if pure_domain:
        for line_number, line in enumerate(lines, start=1):
            if re.search(r"^\s*extends\s+(?:Node|Control|Canvas|Area|CharacterBody|RigidBody)", line):
                findings.append(Finding("domain_node", relative, line_number, "domain/foundation/runtime code may not extend scene-tree nodes"))
            if re.search(r"\b(?:get_node|get_tree|find_child)\s*\(", line):
                findings.append(Finding("domain_scene_access", relative, line_number, "domain code may not query the scene tree"))
            if FORBIDDEN_GAME_RANDOM.search(line):
                findings.append(Finding("random_source", relative, line_number, "use an injected named RngSet stream"))
            if DEFINITION_BRANCH.search(line):
                findings.append(Finding("definition_id_branch", relative, line_number, "register a capability/handler instead of branching on a concrete definition ID"))
        if re.search(r"res://src/(?:app|presentation|features/[^/]+/presentation)/", text):
            findings.append(Finding("domain_presentation_dependency", relative, 1, "domain code may not preload app or presentation code"))

    if normalized.startswith("src/foundation/") and re.search(r"res://src/(?:data|resources|runtime|features|presentation|app|platform)/", text):
        findings.append(Finding("foundation_dependency", relative, 1, "foundation may not depend on higher project modules"))

    if "/presentation/" in normalized:
        for line_number, line in enumerate(lines, start=1):
            if re.search(r"\.state\.[A-Za-z_][A-Za-z0-9_]*\s*=", line):
                findings.append(Finding("presentation_state_write", relative, line_number, "presentation must submit an intent instead of mutating feature state"))
            if DYNAMIC_FIXED_UI.search(line) and "architecture-lint: dynamic-list-item" not in line:
                findings.append(Finding("fixed_ui_in_code", relative, line_number, "keep fixed UI structure in .tscn; annotate only true dynamic list items"))


def _check_project(findings: list[Finding]) -> None:
    project_text = (PROJECT_ROOT / "project.godot").read_text(encoding="utf-8", errors="strict")
    if "[autoload]" in project_text:
        findings.append(Finding("autoload_allowlist", "project.godot", 1, "default framework permits no Autoload; add one only through an ADR and lint allowlist change"))

    catalog_path = PROJECT_ROOT / "data" / "generated" / "data_catalog.json"
    if not catalog_path.is_file():
        findings.append(Finding("feature_catalog", _relative(catalog_path), 1, "generated data catalog is missing"))
        return
    catalog = json.loads(catalog_path.read_text(encoding="utf-8", errors="strict"))
    for feature in catalog.get("tables", {}).get("feature_catalog", []):
        if feature.get("status") == "deprecated":
            continue
        for field in ("domain_root", "presentation_root"):
            res_path = str(feature.get(field, ""))
            local_path = PROJECT_ROOT / res_path.removeprefix("res://")
            if not local_path.is_dir():
                findings.append(Finding("feature_boundary", "data/source/feature_catalog.csv", 2, f"{res_path} does not exist"))

    for scope in (PROJECT_ROOT / "src", PROJECT_ROOT / "data" / "source"):
        for path in scope.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".gd", ".csv", ".json"}:
                continue
            lowered = path.read_text(encoding="utf-8", errors="strict").lower()
            for marker in COMMERCIAL_MARKERS:
                if marker in lowered:
                    findings.append(Finding("clean_room", _relative(path), 1, f"commercial-project marker found: {marker}"))


def run_lint() -> list[Finding]:
    findings: list[Finding] = []
    for path in sorted(SRC_ROOT.rglob("*.gd")):
        _scan_script(path, findings)
    _check_project(findings)
    return sorted(findings, key=lambda item: (item.rule, item.path, item.line))


def main() -> int:
    try:
        findings = run_lint()
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"[FAIL] architecture lint could not run: {exc}")
        return 1
    if findings:
        print(f"[FAIL] architecture lint: {len(findings)} finding(s)")
        for finding in findings:
            print(f"  {finding}")
        return 1
    print("[OK] architecture lint")
    return 0


if __name__ == "__main__":
    sys.exit(main())
