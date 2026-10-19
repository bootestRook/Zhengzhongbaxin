#!/usr/bin/env python3
"""Export and query the exact scripting API of an installed Godot editor."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

if __package__:
    from tools import project as project_cli
else:
    import project as project_cli


API_ROOT = project_cli.PROJECT_ROOT / ".godot" / "api_reference"
NAMED_TAGS = {"method", "constructor", "operator", "member", "signal", "constant", "theme_item"}


class ApiError(RuntimeError):
    pass


def _engine_version(godot: str) -> str:
    result = subprocess.run(
        [godot, "--version"],
        cwd=project_cli.PROJECT_ROOT,
        capture_output=True,
        env=project_cli.process_environment(),
    )
    output = (result.stdout + result.stderr).decode("utf-8", errors="strict")
    match = re.search(r"\d+\.\d+(?:\.\d+)?", output)
    if result.returncode != 0 or match is None:
        raise ApiError(f"cannot read Godot version: {output.strip()}")
    return match.group(0)


def export_api(godot_hint: str) -> Path:
    godot = project_cli.find_godot(godot_hint)
    if not godot:
        raise ApiError("Godot 4 not found; set GODOT_BIN or use --godot")
    version = _engine_version(godot)
    target = API_ROOT / version
    target.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            godot,
            "--headless",
            "--language",
            "en",
            "--path",
            str(project_cli.PROJECT_ROOT),
            "--doctool",
            str(target),
        ],
        cwd=project_cli.PROJECT_ROOT,
        capture_output=True,
        env=project_cli.process_environment(),
    )
    output = (result.stdout + result.stderr).decode("utf-8", errors="strict")
    xml_files = list(target.rglob("*.xml"))
    if result.returncode != 0 or not xml_files:
        raise ApiError(f"Godot API export failed: {output.strip()}")
    size = sum(path.stat().st_size for path in xml_files)
    print(f"[OK] Godot {version} API: classes={len(xml_files)}, bytes={size}, cache={target}")
    return target


def _cache(version: str) -> Path:
    if version:
        target = API_ROOT / version
        if any(target.rglob("*.xml")):
            return target
        raise ApiError(f"API cache not found for Godot {version}; run export first")
    candidates = sorted(path for path in API_ROOT.glob("*") if path.is_dir() and any(path.rglob("*.xml")))
    if len(candidates) == 1:
        return candidates[0]
    available = ", ".join(path.name for path in candidates) or "none"
    raise ApiError(f"select --version; available caches: {available}")


def _params(element: ET.Element) -> str:
    params = sorted(element.findall("param"), key=lambda item: int(item.get("index", "0")))
    formatted: list[str] = []
    for param in params:
        value = f"{param.get('name', '?')}: {param.get('type', 'Variant')}"
        if param.get("enum"):
            value += f" [{param.get('enum')}]"
        if param.get("default") is not None:
            value += f" = {param.get('default')}"
        formatted.append(value)
    return ", ".join(formatted)


def _entry(class_name: str, element: ET.Element) -> str:
    name = element.get("name", "?")
    if element.tag in {"method", "constructor", "operator"}:
        result = element.find("return")
        return_type = result.get("type", "void") if result is not None else class_name
        qualifiers = f" [{element.get('qualifiers')}]" if element.get("qualifiers") else ""
        return f"{class_name}.{name}({_params(element)}) -> {return_type}{qualifiers}"
    if element.tag == "signal":
        return f"signal {class_name}.{name}({_params(element)})"
    if element.tag in {"member", "theme_item"}:
        default = f" = {element.get('default')}" if element.get("default") is not None else ""
        return f"{class_name}.{name}: {element.get('type', 'Variant')}{default}"
    value = f" = {element.get('value')}" if element.get("value") is not None else ""
    enum = f" [{element.get('enum')}]" if element.get("enum") else ""
    return f"const {class_name}.{name}{enum}{value}"


def _class_file(cache: Path, class_name: str) -> Path | None:
    wanted = class_name.casefold()
    return next((path for path in cache.rglob("*.xml") if path.stem.casefold() == wanted), None)


def query_cache(cache: Path, term: str, limit: int = 20) -> list[str]:
    if "." in term:
        class_name, member = term.split(".", 1)
        path = _class_file(cache, class_name)
        if path is None:
            return []
        root = ET.parse(path).getroot()
        matches = [
            element
            for element in root.iter()
            if element.tag in NAMED_TAGS and member.casefold() in element.get("name", "").casefold()
        ]
        matches.sort(key=lambda element: (element.get("name", "").casefold() != member.casefold(), element.get("name", "")))
        return [_entry(root.get("name", class_name), element) for element in matches[:limit]]

    path = _class_file(cache, term)
    if path is not None:
        root = ET.parse(path).getroot()
        counts = {
            "methods": len(root.findall("./methods/method")),
            "members": len(root.findall("./members/member")),
            "signals": len(root.findall("./signals/signal")),
            "constants": len(root.findall("./constants/constant")),
        }
        inherits = f" inherits {root.get('inherits')}" if root.get("inherits") else ""
        return [f"class {root.get('name')}{inherits}", " ".join(f"{key}={value}" for key, value in counts.items())]

    matches: list[tuple[bool, str]] = []
    wanted = term.casefold()
    for xml_path in cache.rglob("*.xml"):
        root = ET.parse(xml_path).getroot()
        class_name = root.get("name", xml_path.stem)
        for element in root.iter():
            name = element.get("name", "")
            if element.tag in NAMED_TAGS and wanted in name.casefold():
                matches.append((name.casefold() != wanted, _entry(class_name, element)))
    matches.sort()
    return [entry for _, entry in matches[:limit]]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    export_parser = subparsers.add_parser("export", help="export the installed engine API into .godot/")
    export_parser.add_argument("--godot", default="", help="path to a Godot 4 executable")
    query_parser = subparsers.add_parser("query", help="query Class, Class.member, or a member name")
    query_parser.add_argument("term")
    query_parser.add_argument("--version", default="")
    query_parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args(argv)
    try:
        if args.command == "export":
            export_api(args.godot)
        else:
            results = query_cache(_cache(args.version), args.term, max(1, args.limit))
            if not results:
                raise ApiError(f"no API match: {args.term}")
            print("\n".join(results))
    except (ApiError, ET.ParseError, UnicodeDecodeError) as exc:
        print(f"[FAIL] {exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
