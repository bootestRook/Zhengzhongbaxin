#!/usr/bin/env python3
"""Validate art handoff contracts and build a deterministic asset manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_CATALOG = PROJECT_ROOT / "data" / "generated" / "data_catalog.json"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "generated"
MANIFEST_NAME = "asset_manifest.json"
RUNTIME_ROOT = (PROJECT_ROOT / "assets" / "runtime").resolve()
SOURCE_ROOT = (PROJECT_ROOT / "art_source").resolve()
NUMBER_PREFIX = re.compile(r"^([0-9]+(?:\.[0-9]+)?)")
IMPORT_MODE_VALUES = {"lossless": 0, "vram_compressed": 2}


@dataclass(frozen=True)
class AssetIssue:
    asset_id: str
    field: str
    actual: str
    expected: str
    suggestion: str

    def __str__(self) -> str:
        return (
            f"[asset={self.asset_id} field={self.field}] expected={self.expected}; "
            f"actual={self.actual!r}; fix={self.suggestion}"
        )

    def as_dict(self) -> dict[str, str]:
        return {
            "asset_id": self.asset_id,
            "field": self.field,
            "actual": self.actual,
            "expected": self.expected,
            "suggestion": self.suggestion,
        }


class AssetValidationError(Exception):
    def __init__(self, issues: list[AssetIssue]):
        self.issues = sorted(issues, key=lambda issue: (issue.asset_id, issue.field))
        super().__init__(f"asset validation failed with {len(issues)} issue(s)")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8", errors="strict"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return parsed


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_runtime_path(res_path: str) -> Path | None:
    prefix = "res://assets/runtime/"
    if not res_path.startswith(prefix) or ".." in res_path or "\\" in res_path:
        return None
    candidate = (PROJECT_ROOT / res_path.removeprefix("res://")).resolve()
    if not candidate.is_relative_to(RUNTIME_ROOT):
        return None
    return candidate


def _safe_source_path(source_path: str) -> Path | None:
    if not source_path.startswith("art_source/") or ".." in source_path or "\\" in source_path:
        return None
    candidate = (PROJECT_ROOT / source_path).resolve()
    if not candidate.is_relative_to(SOURCE_ROOT):
        return None
    return candidate


def _svg_number(value: str | None) -> int | None:
    if not value:
        return None
    match = NUMBER_PREFIX.match(value.strip())
    return int(round(float(match.group(1)))) if match else None


def _image_dimensions(path: Path) -> tuple[int | None, int | None]:
    suffix = path.suffix.lower()
    if suffix == ".png":
        data = path.read_bytes()[:24]
        if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", data[16:24])
        return None, None
    if suffix == ".svg":
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            return None, None
        width = _svg_number(root.get("width"))
        height = _svg_number(root.get("height"))
        if width is not None and height is not None:
            return width, height
        view_box = root.get("viewBox", "").replace(",", " ").split()
        if len(view_box) == 4:
            try:
                return int(round(float(view_box[2]))), int(round(float(view_box[3])))
            except ValueError:
                pass
    return None, None


def _parse_import_metadata(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="strict")
    importer_match = re.search(r'^importer="([^"]+)"$', text, re.MULTILINE)
    params: dict[str, Any] = {}
    if "[params]" in text:
        params_text = text.split("[params]", 1)[1]
        for raw_line in params_text.splitlines():
            line = raw_line.strip()
            if not line or "=" not in line:
                continue
            key, raw_value = line.split("=", 1)
            raw_value = raw_value.strip()
            if raw_value in {"true", "false"}:
                value: Any = raw_value == "true"
            elif re.fullmatch(r"-?[0-9]+", raw_value):
                value = int(raw_value)
            elif re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?", raw_value):
                value = float(raw_value)
            else:
                value = raw_value.strip('"')
            params[key.strip()] = value
    return {"importer": importer_match.group(1) if importer_match else "", "params": params}


def _issue(
    issues: list[AssetIssue],
    asset_id: str,
    field: str,
    actual: Any,
    expected: str,
    suggestion: str,
) -> None:
    issues.append(AssetIssue(asset_id, field, str(actual), expected, suggestion))


def build_manifest(catalog_path: Path = DATA_CATALOG) -> tuple[dict[str, Any], dict[str, int]]:
    catalog = _read_json(catalog_path)
    tables = catalog.get("tables", {})
    if not isinstance(tables, dict):
        raise ValueError("data catalog must contain tables")
    bindings = tables.get("resource_bindings", [])
    policies = {row["id"]: row for row in tables.get("resource_policies", [])}
    issues: list[AssetIssue] = []
    entries: list[dict[str, Any]] = []
    budget_totals: dict[str, int] = {}

    for binding in bindings:
        asset_id = str(binding.get("id", ""))
        policy = policies.get(binding.get("policy_id"))
        if policy is None:
            _issue(issues, asset_id, "policy_id", binding.get("policy_id"), "existing policy", "fix the data reference")
            continue
        if policy.get("asset_kind") != binding.get("asset_kind"):
            _issue(
                issues,
                asset_id,
                "asset_kind",
                binding.get("asset_kind"),
                str(policy.get("asset_kind")),
                "use a policy for the same asset kind",
            )

        runtime_path = str(binding.get("runtime_path", ""))
        runtime_file = _safe_runtime_path(runtime_path)
        if runtime_file is None:
            _issue(
                issues,
                asset_id,
                "runtime_path",
                runtime_path,
                "normalized res://assets/runtime/... path",
                "move shipped resources under assets/runtime",
            )
            continue
        if not runtime_file.is_file():
            _issue(issues, asset_id, "runtime_path", runtime_path, "existing runtime asset", "export or restore the runtime asset")
            continue

        allowed_extensions = {
            item.strip().lower() for item in str(policy.get("allowed_extensions", "")).split("|") if item.strip()
        }
        suffix = runtime_file.suffix.lower()
        if suffix not in allowed_extensions:
            _issue(
                issues,
                asset_id,
                "runtime_path",
                suffix,
                f"one of {sorted(allowed_extensions)}",
                "export using an allowed runtime format or revise the policy through review",
            )

        runtime_bytes = runtime_file.stat().st_size
        max_bytes = int(policy.get("max_bytes", 0))
        if max_bytes > 0 and runtime_bytes > max_bytes:
            _issue(
                issues,
                asset_id,
                "bytes",
                runtime_bytes,
                f"<= {max_bytes}",
                "optimize the asset or change the reviewed budget",
            )

        width, height = _image_dimensions(runtime_file)
        max_width = int(policy.get("max_width", 0))
        max_height = int(policy.get("max_height", 0))
        if max_width > 0 and width is None:
            _issue(issues, asset_id, "width", "unknown", f"measurable and <= {max_width}", "use PNG/SVG or extend the dimension reader")
        elif max_width > 0 and width is not None and width > max_width:
            _issue(issues, asset_id, "width", width, f"<= {max_width}", "reduce dimensions or change the reviewed policy")
        if max_height > 0 and height is None:
            _issue(issues, asset_id, "height", "unknown", f"measurable and <= {max_height}", "use PNG/SVG or extend the dimension reader")
        elif max_height > 0 and height is not None and height > max_height:
            _issue(issues, asset_id, "height", height, f"<= {max_height}", "reduce dimensions or change the reviewed policy")

        source_path = str(binding.get("source_path", ""))
        source_file = _safe_source_path(source_path) if source_path else None
        if bool(policy.get("source_required", False)) and source_file is None:
            _issue(issues, asset_id, "source_path", source_path, "art_source/... path", "register the editable source asset")
        if source_file is not None and not source_file.is_file():
            _issue(issues, asset_id, "source_path", source_path, "existing source asset", "restore the editable source file")

        import_path = Path(str(runtime_file) + ".import")
        import_metadata: dict[str, Any] = {"importer": "", "params": {}}
        if not import_path.is_file():
            _issue(
                issues,
                asset_id,
                "import_metadata",
                import_path.name,
                "committed adjacent .import metadata",
                "open/import the project in Godot, review the policy, and commit the .import file",
            )
        else:
            import_metadata = _parse_import_metadata(import_path)
            import_mode = str(policy.get("import_mode", "default"))
            expected_compress_mode = IMPORT_MODE_VALUES.get(import_mode)
            actual_compress_mode = import_metadata["params"].get("compress/mode")
            if expected_compress_mode is not None and actual_compress_mode != expected_compress_mode:
                _issue(
                    issues,
                    asset_id,
                    "import_mode",
                    actual_compress_mode,
                    f"compress/mode={expected_compress_mode} for {import_mode}",
                    "update the Godot import settings or the reviewed resource policy",
                )

        budget_group = str(binding.get("budget_group", "unassigned"))
        budget_totals[budget_group] = budget_totals.get(budget_group, 0) + runtime_bytes
        entries.append(
            {
                "id": asset_id,
                "asset_kind": binding.get("asset_kind"),
                "source_path": source_path,
                "source_sha256": _sha256(source_file) if source_file is not None and source_file.is_file() else "",
                "runtime_path": runtime_path,
                "runtime_bytes": runtime_bytes,
                "runtime_sha256": _sha256(runtime_file),
                "import_path": _relative_import_path(import_path) if import_path.is_file() else "",
                "import_sha256": _sha256(import_path) if import_path.is_file() else "",
                "importer": import_metadata["importer"],
                "import_params": import_metadata["params"],
                "width": width,
                "height": height,
                "policy_id": binding.get("policy_id"),
                "import_mode": policy.get("import_mode"),
                "budget_group": budget_group,
                "owner": binding.get("owner"),
                "license_id": binding.get("license_id"),
                "required": binding.get("required"),
                "consumer": binding.get("consumer"),
            }
        )

    if issues:
        raise AssetValidationError(issues)

    entries.sort(key=lambda entry: entry["id"])
    manifest = {
        "format_version": 1,
        "generator": "tools/asset_pipeline.py",
        "data_catalog_sha256": _sha256(catalog_path),
        "assets": entries,
        "budget_totals": dict(sorted(budget_totals.items())),
    }
    summary = {"assets": len(entries), "bytes": sum(entry["runtime_bytes"] for entry in entries)}
    return manifest, summary


def _relative_import_path(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _manifest_bytes(manifest: dict[str, Any]) -> bytes:
    return (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check", "validate"))
    parser.add_argument("--catalog", type=Path, default=DATA_CATALOG)
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    try:
        manifest, summary = build_manifest(args.catalog)
        expected = _manifest_bytes(manifest)
        output_path = args.output / MANIFEST_NAME
        if args.command == "build":
            args.output.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(expected)
        elif args.command == "check" and (not output_path.is_file() or output_path.read_bytes() != expected):
            message = "generated asset manifest is stale or missing"
            print(json.dumps({"status": "error", "message": message}) if args.json else f"[FAIL] {message}\n[NEXT] python tools/project.py assets")
            return 1
        payload = {"status": "ok", "command": args.command, **summary}
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True) if args.json else f"[OK] assets {args.command}: assets={summary['assets']}, bytes={summary['bytes']}")
        return 0
    except AssetValidationError as exc:
        if args.json:
            print(json.dumps({"status": "error", "issues": [issue.as_dict() for issue in exc.issues]}, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {len(exc.issues)} asset validation issue(s)")
            for issue in exc.issues:
                print(f"  {issue}")
        return 1
    except (OSError, UnicodeError, ValueError) as exc:
        print(json.dumps({"status": "error", "message": str(exc)}) if args.json else f"[FAIL] {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
