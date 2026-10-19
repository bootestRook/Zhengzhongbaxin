#!/usr/bin/env python3
"""Validate an approved display contract, then export a WebApp or Windows package."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any

try:
    from tools import project as project_cli
    from tools import release_manifest as release_manifest_tool
except ModuleNotFoundError:
    import project as project_cli
    import release_manifest as release_manifest_tool


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = PROJECT_ROOT / "package_profiles.json"
WEB_RESIZE_POLICIES = {"none": 0, "project": 1, "adaptive": 2}
MAX_WEB_ARCHIVE_BYTES = 100_000_000
FONT_SUFFIXES = {".ttf", ".otf", ".woff", ".woff2", ".fnt"}


def _godot_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return json.loads(raw)
    if raw == "true":
        return True
    if raw == "false":
        return False
    try:
        return int(raw)
    except ValueError:
        return raw


def read_godot_config(path: Path) -> dict[str, dict[str, Any]]:
    sections: dict[str, dict[str, Any]] = {"": {}}
    current = sections[""]
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = sections.setdefault(line[1:-1], {})
            continue
        if "=" not in line:
            raise ValueError(f"{path.name}:{line_number}: expected key=value")
        key, value = line.split("=", 1)
        current[key.strip()] = _godot_value(value)
    return sections


def load_profiles(path: Path = PROFILE_PATH) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("package_profiles.json must contain an object")
    return data


def _resolution(value: Any, label: str, issues: list[str]) -> tuple[int, int] | None:
    if (
        not isinstance(value, list)
        or len(value) != 2
        or any(isinstance(item, bool) or not isinstance(item, int) or item <= 0 for item in value)
    ):
        issues.append(f"{label} must be [positive_width, positive_height]")
        return None
    return value[0], value[1]


def _relative_output(value: Any, issues: list[str], label: str = "output") -> str | None:
    if not isinstance(value, str) or not value:
        issues.append(f"{label} must be a non-empty relative path")
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != "build":
        issues.append(f"{label} must stay under build/")
        return None
    return path.as_posix()


def _bundled_fonts(value: Any, root: Path, issues: list[str]) -> list[str]:
    if not isinstance(value, list) or not value:
        issues.append("bundled_font_files must list at least one shipped font")
        return []
    fonts: list[str] = []
    runtime_root = (root / "assets" / "runtime").resolve()
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item:
            issues.append(f"bundled_font_files[{index}] must be a path")
            continue
        path = (root / item).resolve()
        if not path.is_relative_to(runtime_root) or path.suffix.lower() not in FONT_SUFFIXES:
            issues.append(f"bundled font must be a supported file under assets/runtime/: {item}")
        elif not path.is_file():
            issues.append(f"bundled font does not exist: {item}")
        else:
            fonts.append(Path(item).as_posix())
    return fonts


def _find_preset(
    presets: dict[str, dict[str, Any]], name: Any
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    for section, values in presets.items():
        if section.startswith("preset.") and not section.endswith(".options") and values.get("name") == name:
            return values, presets.get(f"{section}.options", {})
    return None, None


def validate_profile(
    profile_name: str,
    root: Path = PROJECT_ROOT,
    config: dict[str, Any] | None = None,
    require_confirmation: bool = True,
    require_adaptation_review: bool = True,
) -> tuple[list[str], dict[str, Any]]:
    issues: list[str] = []
    config = config if config is not None else load_profiles(root / "package_profiles.json")
    if config.get("format_version") != 1:
        issues.append("format_version must be 1")

    design = config.get("design")
    profiles = config.get("profiles")
    if not isinstance(design, dict):
        return issues + ["design must be an object"], {}
    if not isinstance(profiles, dict) or profile_name not in profiles:
        return issues + [f"unknown profile: {profile_name}"], {}
    profile = profiles[profile_name]
    if not isinstance(profile, dict):
        return issues + [f"profiles.{profile_name} must be an object"], {}

    project = read_godot_config(root / "project.godot")
    display = project.get("display", {})
    rendering = project.get("rendering", {})
    project_resolution = _resolution(
        [
            display.get("window/size/viewport_width"),
            display.get("window/size/viewport_height"),
        ],
        "project viewport resolution",
        issues,
    )
    resolution = profile.get("resolution")
    design_resolution: tuple[int, int] | None = None
    if not isinstance(resolution, dict):
        issues.append("resolution must be an object")
    elif resolution.get("mode") == "project":
        design_resolution = project_resolution
        if resolution.get("override") is not None:
            issues.append("project resolution mode must not define an override")
    elif resolution.get("mode") == "special":
        design_resolution = _resolution(
            resolution.get("override"), "resolution.override", issues
        )
        if not isinstance(resolution.get("reason"), str) or not resolution["reason"].strip():
            issues.append("special resolution requires a non-empty reason")
        if design_resolution and project_resolution != design_resolution:
            issues.append("special resolution must be applied to project.godot before packaging")
    else:
        issues.append("resolution.mode must be project or special")
    test_values = profile.get("test_resolutions")
    test_resolutions: list[tuple[int, int]] = []
    if not isinstance(test_values, list) or len(test_values) < 3:
        issues.append("test_resolutions must contain at least 3 sizes")
    elif isinstance(test_values, list):
        for index, value in enumerate(test_values):
            parsed = _resolution(value, f"test_resolutions[{index}]", issues)
            if parsed:
                test_resolutions.append(parsed)

    orientations = profile.get("supported_orientations")
    if not isinstance(orientations, list) or not orientations:
        issues.append("supported_orientations must not be empty")
        orientations = []
    else:
        invalid = set(orientations) - {"landscape", "portrait"}
        if invalid:
            issues.append(f"unsupported orientations: {', '.join(sorted(invalid))}")
    if "landscape" in orientations and not any(width > height for width, height in test_resolutions):
        issues.append("test_resolutions has no landscape case")
    if "portrait" in orientations and not any(height > width for width, height in test_resolutions):
        issues.append("test_resolutions has no portrait case")

    confirmation = profile.get("confirmation")
    if not isinstance(confirmation, dict):
        issues.append("confirmation must be an object")
    elif require_confirmation:
        if confirmation.get("resolution_and_mode_confirmed") is not True:
            issues.append("resolution/mode is not confirmed")
        if require_adaptation_review and confirmation.get("adaptation_reviewed") is not True:
            issues.append("target adaptation is not reviewed")

    output = _relative_output(profile.get("output"), issues)
    if display.get("window/stretch/mode") != design.get("stretch_mode"):
        issues.append("project stretch mode does not match design")
    # Godot 4.7.1 defaults this setting to keep; the editor omits defaults.
    if display.get("window/stretch/aspect", "keep") != design.get("stretch_aspect"):
        issues.append("project stretch aspect does not match design")

    presets = read_godot_config(root / "export_presets.cfg")
    preset, options = _find_preset(presets, profile.get("preset"))
    if preset is None:
        issues.append(f"export preset not found: {profile.get('preset')}")
    else:
        if preset.get("platform") != profile.get("platform"):
            issues.append("export preset platform does not match profile")
        preset_output = Path(str(preset.get("export_path", ""))).as_posix()
        if output and preset_output != output:
            issues.append("export preset path does not match profile output")

    if profile_name == "webapp":
        if profile.get("platform") != "Web":
            issues.append("webapp platform must be Web")
        policy = WEB_RESIZE_POLICIES.get(profile.get("canvas_resize_policy"))
        if policy is None:
            issues.append("canvas_resize_policy must be none, project, or adaptive")
        elif options is not None and options.get("html/canvas_resize_policy") != policy:
            issues.append("Web canvas resize policy does not match export preset")
        if output and Path(output).name.lower() != "index.html":
            issues.append("Web output must be named index.html")
        archive = _relative_output(profile.get("archive"), issues, "archive")
        if archive and Path(archive).suffix.lower() != ".zip":
            issues.append("Web archive must be a .zip")
        if archive and Path(archive).parent != Path("build"):
            issues.append("Web archive must be directly under build/")
        max_archive_bytes = profile.get("max_archive_bytes")
        if (
            isinstance(max_archive_bytes, bool)
            or not isinstance(max_archive_bytes, int)
            or not 0 < max_archive_bytes <= MAX_WEB_ARCHIVE_BYTES
        ):
            issues.append(f"max_archive_bytes must be between 1 and {MAX_WEB_ARCHIVE_BYTES}")
        browsers = profile.get("test_browsers")
        if not isinstance(browsers, list) or len(browsers) < 2:
            issues.append("test_browsers must contain at least 2 target browsers")
        locales = profile.get("required_locales")
        if not isinstance(locales, list) or not locales or not all(isinstance(item, str) and item for item in locales):
            issues.append("required_locales must contain locale names")
        if rendering.get("renderer/rendering_method") != "gl_compatibility":
            issues.append("Web projects must be previewed with the gl_compatibility renderer")
        if rendering.get("renderer/rendering_method.mobile") != "gl_compatibility":
            issues.append("Web mobile rendering must use gl_compatibility")
        vram_targets = profile.get("vram_texture_targets")
        if (
            not isinstance(vram_targets, list)
            or not vram_targets
            or set(vram_targets) - {"desktop", "mobile"}
        ):
            issues.append("vram_texture_targets must contain desktop and/or mobile")
        elif options is not None:
            for target in ("desktop", "mobile"):
                expected = target in vram_targets
                if options.get(f"vram_texture_compression/for_{target}") is not expected:
                    issues.append(f"Web {target} VRAM texture target does not match profile")
        if require_adaptation_review:
            _bundled_fonts(profile.get("bundled_font_files"), root, issues)
            if isinstance(confirmation, dict):
                if confirmation.get("color_parity_reviewed") is not True:
                    issues.append("Web color parity is not reviewed")
                if confirmation.get("text_and_font_reviewed") is not True:
                    issues.append("Web text/font rendering is not reviewed")
                if confirmation.get("editor_candidate_parity_reviewed") is not True:
                    issues.append("Godot editor/candidate parity is not reviewed")
    elif profile_name == "exe":
        if profile.get("platform") != "Windows Desktop":
            issues.append("windows platform must be Windows Desktop")
        initial = _resolution(profile.get("initial_window_resolution"), "initial_window_resolution", issues)
        if initial:
            # Godot's physical window override is independent of its logical viewport.
            # The profile must match that override; stretch mode handles the mapping.
            if display.get("window/size/window_width_override") != initial[0]:
                issues.append("project initial window width does not match profile")
            if display.get("window/size/window_height_override") != initial[1]:
                issues.append("project initial window height does not match profile")
        if not isinstance(profile.get("resizable"), bool):
            issues.append("resizable must be true or false")
        elif display.get("window/size/resizable", True) != profile["resizable"]:
            issues.append("project resizable setting does not match profile")
        if output and Path(output).suffix.lower() != ".exe":
            issues.append("Windows output must be an .exe")
    else:
        issues.append(f"unsupported profile: {profile_name}")

    summary = {
        "profile": profile_name,
        "design_resolution": list(design_resolution) if design_resolution else None,
        "output": output,
        "test_resolutions": [list(item) for item in test_resolutions],
    }
    if profile_name == "webapp":
        summary["archive"] = archive
        summary["max_archive_bytes"] = profile.get("max_archive_bytes")
    return issues, summary


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_artifact_manifest(
    profile_name: str,
    stage: str,
    summary: dict[str, Any],
    source_fingerprint: str,
    godot_version: str,
    root: Path = PROJECT_ROOT,
) -> Path:
    output = root / str(summary["output"])
    artifact_root = output.parent
    manifest_path = artifact_root / "package-manifest.json"
    files = []
    for path in sorted(artifact_root.rglob("*")):
        if path.is_file() and path != manifest_path:
            files.append(
                {
                    "path": path.relative_to(artifact_root).as_posix(),
                    "bytes": path.stat().st_size,
                    "sha256": _sha256(path),
                }
            )
    if not output.is_file():
        raise FileNotFoundError(f"expected export output was not created: {summary['output']}")
    manifest = {
        "format_version": 2,
        "profile": profile_name,
        "stage": stage,
        "design_resolution": summary["design_resolution"],
        "godot_version": godot_version,
        "fresh_engine_cache": True,
        "source_combined_sha256": source_fingerprint,
        "output": summary["output"],
        "files": files,
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return manifest_path


def write_web_archive(summary: dict[str, Any], root: Path = PROJECT_ROOT) -> tuple[Path, int, str]:
    output = root / str(summary["output"])
    artifact_root = output.parent
    archive_path = root / str(summary["archive"])
    try:
        html = output.read_text(encoding="utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ValueError(f"index.html is not valid UTF-8 at byte {exc.start}") from exc
    if not re.search(r"<meta\s+[^>]*charset\s*=\s*['\"]?utf-8", html, re.IGNORECASE):
        raise ValueError("index.html must declare UTF-8 with a meta charset")
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(
        archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in sorted(artifact_root.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(artifact_root).as_posix())
    with zipfile.ZipFile(archive_path) as archive:
        if "index.html" not in archive.namelist():
            archive_path.unlink()
            raise ValueError("Web archive must contain index.html at its root")
    archive_bytes = archive_path.stat().st_size
    max_bytes = int(summary["max_archive_bytes"])
    if archive_bytes > max_bytes:
        archive_path.unlink()
        raise ValueError(f"Web archive is {archive_bytes} bytes; limit is {max_bytes} bytes")
    return archive_path, archive_bytes, _sha256(archive_path)


def check(profile_name: str, require_adaptation_review: bool = True) -> tuple[bool, dict[str, Any]]:
    try:
        issues, summary = validate_profile(
            profile_name, require_adaptation_review=require_adaptation_review
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
        issues, summary = [str(exc)], {}
    if issues:
        print(f"[FAIL] package profile {profile_name}: {len(issues)} issue(s)")
        for issue in issues:
            print(f"  {issue}")
        print("[NEXT] update package_profiles.json after completing the required review in docs/PACKAGING.md")
        return False, summary
    matrix = ", ".join(f"{width}x{height}" for width, height in summary["test_resolutions"])
    print(
        f"[OK] package profile {profile_name}: design={summary['design_resolution'][0]}x"
        f"{summary['design_resolution'][1]}, matrix={matrix}, output={summary['output']}"
    )
    return True, summary


def _clean_artifact_root(output: Path) -> None:
    artifact_root = output.parent.resolve()
    build_root = (PROJECT_ROOT / "build").resolve()
    if artifact_root == build_root or not artifact_root.is_relative_to(build_root):
        raise ValueError("artifact directory must be a child of build/")
    if artifact_root.exists():
        shutil.rmtree(artifact_root)
    artifact_root.mkdir(parents=True)


def _remove_web_archive(summary: dict[str, Any]) -> None:
    archive_path = (PROJECT_ROOT / str(summary["archive"])).resolve()
    build_root = (PROJECT_ROOT / "build").resolve()
    if archive_path.parent == build_root and archive_path.suffix.lower() == ".zip":
        archive_path.unlink(missing_ok=True)
        return
    raise ValueError("Web archive must be a .zip directly under build/")


def clean_engine_caches(root: Path = PROJECT_ROOT) -> None:
    root = root.resolve()
    for name in (".godot", ".import"):
        cache = (root / name).resolve()
        if cache.parent != root or cache.name != name:
            raise ValueError(f"unsafe engine cache path: {cache}")
        if cache.exists():
            shutil.rmtree(cache)


def _godot_version(godot: str) -> str:
    result = subprocess.run(
        [godot, "--version"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        env=project_cli.process_environment(),
    )
    output = (result.stdout + result.stderr).decode("utf-8", errors="strict").strip()
    if result.returncode != 0 or not output:
        raise ValueError("cannot read Godot version")
    return output.splitlines()[0]


def prepare_fresh_inputs(godot: str) -> tuple[bool, str, str]:
    try:
        clean_engine_caches()
        godot_version = _godot_version(godot)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] fresh build preparation: {exc}")
        return False, "", ""
    steps = (
        project_cli.generate_data,
        project_cli.generate_assets,
        lambda: project_cli.run_tool("release_manifest.py", "build"),
        lambda: project_cli.checks(godot, include_smoke=True),
    )
    if not all(step() for step in steps):
        return False, "", ""
    try:
        fingerprint = str(release_manifest_tool.build_manifest()["combined_sha256"])
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] source fingerprint: {exc}")
        return False, "", ""
    print(f"[OK] fresh source fingerprint: {fingerprint}")
    return True, fingerprint, godot_version


def export(profile_name: str, godot_hint: str, stage: str) -> bool:
    valid, summary = check(profile_name, require_adaptation_review=stage == "release")
    if not valid:
        return False
    godot = project_cli.find_godot(godot_hint)
    if not godot:
        print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
        return False
    prepared, source_fingerprint, godot_version = prepare_fresh_inputs(godot)
    if not prepared:
        return False
    profile = load_profiles()["profiles"][profile_name]
    output = PROJECT_ROOT / summary["output"]
    try:
        if profile_name == "webapp":
            _remove_web_archive(summary)
        _clean_artifact_root(output)
    except (OSError, ValueError) as exc:
        print(f"[FAIL] prepare artifact directory: {exc}")
        return False
    command = [
        godot,
        "--headless",
        "--language",
        "en",
        "--path",
        str(PROJECT_ROOT),
        "--export-release",
        profile["preset"],
        str(output),
    ]
    if not project_cli.run_command(command, f"export {stage} {profile_name}", scan_output=True):
        return False
    try:
        current_fingerprint = str(release_manifest_tool.build_manifest()["combined_sha256"])
        if current_fingerprint != source_fingerprint:
            raise ValueError("source files changed while packaging; export is invalid")
        manifest_path = write_artifact_manifest(
            profile_name,
            stage,
            summary,
            source_fingerprint,
            godot_version,
        )
        if profile_name == "webapp":
            archive_path, archive_bytes, archive_sha256 = write_web_archive(summary)
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile) as exc:
        print(f"[FAIL] package artifact: {exc}")
        return False
    print(f"[OK] artifact manifest: {manifest_path.relative_to(PROJECT_ROOT).as_posix()}")
    if profile_name == "webapp":
        print(
            f"[OK] Web archive: {archive_path.relative_to(PROJECT_ROOT).as_posix()}, "
            f"bytes={archive_bytes}, sha256={archive_sha256}"
        )
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("candidate", "check", "export"))
    parser.add_argument("profile", choices=("webapp", "exe"))
    parser.add_argument("--godot", default="", help="path to a Godot 4 executable")
    args = parser.parse_args(argv)
    if args.command == "check":
        ok = check(args.profile)[0]
    else:
        stage = "candidate" if args.command == "candidate" else "release"
        ok = export(args.profile, args.godot, stage)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
