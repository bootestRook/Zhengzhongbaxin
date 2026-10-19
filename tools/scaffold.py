#!/usr/bin/env python3
"""Build and verify a reusable Combat Framework scaffold archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = PROJECT_ROOT / "build" / "combat-framework-scaffold.zip"
ARCHIVE_ROOT = "combat-framework-scaffold"
FORMAT_VERSION = 1
EXCLUDED_DIRECTORIES = {
    ".git",
    ".godot",
    ".import",
    "__pycache__",
    ".pytest_cache",
    "build",
    "dist",
    "reports",
    "validation",
}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".import"}


def _is_excluded(path: Path) -> bool:
    relative = path.relative_to(PROJECT_ROOT)
    if any(part in EXCLUDED_DIRECTORIES for part in relative.parts):
        return True
    return path.is_file() and path.suffix.lower() in EXCLUDED_SUFFIXES


def _files() -> list[Path]:
    return [
        path
        for path in sorted(PROJECT_ROOT.rglob("*"))
        if path.is_file() and not _is_excluded(path)
    ]


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _manifest(files: list[Path]) -> dict:
    entries = []
    for path in files:
        relative = path.relative_to(PROJECT_ROOT).as_posix()
        payload = path.read_bytes()
        entries.append({"path": relative, "bytes": len(payload), "sha256": _sha256(payload)})
    combined = hashlib.sha256()
    for entry in entries:
        combined.update(entry["path"].encode("utf-8"))
        combined.update(b"\0")
        combined.update(entry["sha256"].encode("ascii"))
        combined.update(b"\n")
    return {
        "format_version": FORMAT_VERSION,
        "archive_root": ARCHIVE_ROOT,
        "project": "Universal Godot Game Framework",
        "file_count": len(entries),
        "total_bytes": sum(entry["bytes"] for entry in entries),
        "combined_sha256": combined.hexdigest(),
        "files": entries,
    }


def _zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 0
    info.external_attr = 0o100644 << 16
    return info


def build() -> bool:
    files = _files()
    if not files:
        print("[FAIL] scaffold source is empty")
        return False
    manifest = _manifest(files)
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.unlink(missing_ok=True)
    with zipfile.ZipFile(OUTPUT_PATH, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = path.relative_to(PROJECT_ROOT).as_posix()
            archive.writestr(_zip_info(f"{ARCHIVE_ROOT}/{relative}"), path.read_bytes())
        archive.writestr(_zip_info(f"{ARCHIVE_ROOT}/scaffold-manifest.json"), manifest_bytes)
    print(
        f"[OK] scaffold archive: {OUTPUT_PATH.relative_to(PROJECT_ROOT).as_posix()}, "
        f"files={manifest['file_count']}, bytes={OUTPUT_PATH.stat().st_size}"
    )
    return check()


def check() -> bool:
    if not OUTPUT_PATH.is_file():
        print("[FAIL] scaffold archive is missing")
        return False
    try:
        with zipfile.ZipFile(OUTPUT_PATH) as archive:
            names = set(archive.namelist())
            prefix = f"{ARCHIVE_ROOT}/"
            if f"{prefix}project.godot" not in names or f"{prefix}AI_AGENT_GUIDE.md" not in names:
                print("[FAIL] scaffold archive is missing required entry points")
                return False
            if any(name.startswith(f"{ARCHIVE_ROOT}/{excluded}/") for excluded in EXCLUDED_DIRECTORIES for name in names):
                print("[FAIL] scaffold archive contains an excluded generated directory")
                return False
            manifest = json.loads(archive.read(f"{prefix}scaffold-manifest.json").decode("utf-8"))
            actual_files = [name[len(prefix):] for name in names if name.startswith(prefix) and name != f"{prefix}scaffold-manifest.json"]
            if sorted(actual_files) != sorted(entry["path"] for entry in manifest["files"]):
                print("[FAIL] scaffold manifest does not match archive contents")
                return False
            for entry in manifest["files"]:
                payload = archive.read(f"{prefix}{entry['path']}")
                if len(payload) != int(entry["bytes"]) or _sha256(payload) != entry["sha256"]:
                    print(f"[FAIL] scaffold entry checksum mismatch: {entry['path']}")
                    return False
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile, KeyError) as exc:
        print(f"[FAIL] scaffold archive: {exc}")
        return False
    print(f"[OK] scaffold archive check: {OUTPUT_PATH.stat().st_size} bytes")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check"))
    args = parser.parse_args()
    return 0 if (build() if args.command == "build" else check()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
