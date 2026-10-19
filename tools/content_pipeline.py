#!/usr/bin/env python3
"""Validate classified design-data tables and build deterministic runtime JSON."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA = PROJECT_ROOT / "data" / "schema" / "data_schema.json"
DEFAULT_SOURCE = PROJECT_ROOT / "data" / "source"
DEFAULT_OUTPUT = PROJECT_ROOT / "data" / "generated"
CATALOG_NAME = "data_catalog.json"
MANIFEST_NAME = "data_manifest.json"
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_.-]*$")
SUPPORTED_TYPES = {"bool", "enum", "float", "id", "int", "ref", "res_path", "string"}


@dataclass(frozen=True)
class ValidationIssue:
    source: str
    table: str
    row: int
    field: str
    content_id: str
    expected: str
    actual: str
    suggestion: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "table": self.table,
            "row": self.row,
            "field": self.field,
            "content_id": self.content_id,
            "expected": self.expected,
            "actual": self.actual,
            "suggestion": self.suggestion,
        }

    def __str__(self) -> str:
        location = f"{self.source}:{self.row}:{self.field}"
        return (
            f"[{location}] table={self.table} id={self.content_id or '<unknown>'} "
            f"expected={self.expected}; actual={self.actual!r}; fix={self.suggestion}"
        )


class ContentValidationError(Exception):
    def __init__(self, issues: list[ValidationIssue]):
        self.issues = sorted(
            issues,
            key=lambda issue: (issue.source, issue.row, issue.field, issue.actual),
        )
        super().__init__(f"content validation failed with {len(self.issues)} issue(s)")


def _read_utf8(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="strict")


def _load_schema(schema_path: Path) -> dict[str, Any]:
    try:
        schema = json.loads(_read_utf8(schema_path))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read schema {schema_path}: {exc}") from exc

    if not isinstance(schema, dict) or not isinstance(schema.get("tables"), dict):
        raise ValueError("schema must contain a 'tables' object")
    if not isinstance(schema.get("schema_version"), int):
        raise ValueError("schema_version must be an integer")

    for table_name, table_schema in schema["tables"].items():
        fields = table_schema.get("fields", [])
        if not isinstance(fields, list) or not fields:
            raise ValueError(f"table {table_name} must declare at least one field")
        names = [field.get("name") for field in fields]
        if any(not isinstance(name, str) or not name for name in names):
            raise ValueError(f"table {table_name} has a field without a name")
        if len(names) != len(set(names)):
            raise ValueError(f"table {table_name} has duplicate field names")
        unsupported = [
            field.get("type") for field in fields if field.get("type") not in SUPPORTED_TYPES
        ]
        if unsupported:
            raise ValueError(f"table {table_name} uses unsupported types: {unsupported}")
        primary_key = table_schema.get("primary_key", [])
        if not primary_key or any(key not in names for key in primary_key):
            raise ValueError(f"table {table_name} has an invalid primary_key")
        if not isinstance(table_schema.get("source"), str):
            raise ValueError(f"table {table_name} must declare a source CSV")
    return schema


def _issue(
    issues: list[ValidationIssue],
    source: str,
    table: str,
    row: int,
    field: str,
    content_id: str,
    expected: str,
    actual: Any,
    suggestion: str,
) -> None:
    issues.append(
        ValidationIssue(
            source=source,
            table=table,
            row=row,
            field=field,
            content_id=content_id,
            expected=expected,
            actual=str(actual),
            suggestion=suggestion,
        )
    )


def _normalize_value(
    raw_value: str,
    field_schema: dict[str, Any],
    context: dict[str, Any],
    issues: list[ValidationIssue],
) -> Any:
    field_name = field_schema["name"]
    value_type = field_schema["type"]
    required = bool(field_schema.get("required", False))
    value = raw_value if value_type == "string" else raw_value.strip()

    if not value.strip():
        if required:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"required {value_type}",
                actual=raw_value,
                suggestion="provide a non-empty value",
            )
        return ""

    if value_type == "int":
        try:
            parsed = int(value, 10)
        except ValueError:
            _issue(
                issues,
                **context,
                field=field_name,
                expected="base-10 integer",
                actual=raw_value,
                suggestion="replace the value with an integer such as 0 or 12",
            )
            return 0
        minimum = field_schema.get("min")
        maximum = field_schema.get("max")
        if minimum is not None and parsed < minimum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"integer >= {minimum}",
                actual=raw_value,
                suggestion=f"raise the value to at least {minimum}",
            )
        if maximum is not None and parsed > maximum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"integer <= {maximum}",
                actual=raw_value,
                suggestion=f"lower the value to at most {maximum}",
            )
        return parsed

    if value_type == "float":
        try:
            parsed_float = float(value)
        except ValueError:
            parsed_float = math.nan
        if not math.isfinite(parsed_float):
            _issue(
                issues,
                **context,
                field=field_name,
                expected="finite decimal number",
                actual=raw_value,
                suggestion="replace the value with a finite number such as 0.5 or 12",
            )
            return 0.0
        minimum = field_schema.get("min")
        maximum = field_schema.get("max")
        if minimum is not None and parsed_float < minimum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"number >= {minimum}",
                actual=raw_value,
                suggestion=f"raise the value to at least {minimum}",
            )
        if maximum is not None and parsed_float > maximum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"number <= {maximum}",
                actual=raw_value,
                suggestion=f"lower the value to at most {maximum}",
            )
        return parsed_float

    if value_type == "bool":
        normalized_bool = value.lower()
        if normalized_bool in {"true", "1", "yes"}:
            return True
        if normalized_bool in {"false", "0", "no"}:
            return False
        _issue(
            issues,
            **context,
            field=field_name,
            expected="boolean: true or false",
            actual=raw_value,
            suggestion="use true or false",
        )
        return False

    if value_type in {"id", "ref"} and not ID_PATTERN.fullmatch(value):
        _issue(
            issues,
            **context,
            field=field_name,
            expected="stable lowercase ID: [a-z][a-z0-9_.-]*",
            actual=raw_value,
            suggestion="use a stable lowercase ID; never use a display name as an ID",
        )

    if value_type == "enum":
        allowed = field_schema.get("values", [])
        if value not in allowed:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"one of {allowed}",
                actual=raw_value,
                suggestion="choose a declared enum value or update the schema and runtime handler",
            )
    if value_type == "res_path":
        if not value.startswith("res://") or ".." in value or "\\" in value:
            _issue(
                issues,
                **context,
                field=field_name,
                expected="normalized res:// path without traversal or backslashes",
                actual=raw_value,
                suggestion="use a project-relative path such as res://assets/runtime/ui/icon.svg",
            )
    return value


def _load_table(
    table_name: str,
    table_schema: dict[str, Any],
    source_dir: Path,
    issues: list[ValidationIssue],
) -> tuple[list[dict[str, Any]], list[int]]:
    source_name = table_schema["source"]
    source_path = source_dir / source_name
    field_schemas = table_schema["fields"]
    expected_fields = [field["name"] for field in field_schemas]
    rows: list[dict[str, Any]] = []
    row_numbers: list[int] = []

    if not source_path.is_file():
        _issue(
            issues,
            source_name,
            table_name,
            0,
            "<file>",
            "",
            "existing UTF-8 CSV file",
            "missing",
            f"create content/source/{source_name}",
        )
        return rows, row_numbers

    try:
        handle = source_path.open("r", encoding="utf-8", errors="strict", newline="")
    except (OSError, UnicodeError) as exc:
        _issue(
            issues,
            source_name,
            table_name,
            0,
            "<file>",
            "",
            "strict UTF-8 CSV",
            str(exc),
            "save the source as UTF-8 without BOM",
        )
        return rows, row_numbers

    with handle:
        reader = csv.DictReader(handle)
        actual_fields = reader.fieldnames or []
        if actual_fields != expected_fields:
            _issue(
                issues,
                source_name,
                table_name,
                1,
                "<header>",
                "",
                ",".join(expected_fields),
                ",".join(actual_fields),
                "make the header exactly match schema field order",
            )
            return rows, row_numbers

        primary_key = table_schema["primary_key"]
        seen_keys: dict[tuple[Any, ...], int] = {}
        for row_number, raw_row in enumerate(reader, start=2):
            provisional_id = str(raw_row.get(primary_key[0], "")).strip()
            context = {
                "source": source_name,
                "table": table_name,
                "row": row_number,
                "content_id": provisional_id,
            }
            normalized = {
                field["name"]: _normalize_value(
                    str(raw_row.get(field["name"], "")), field, context, issues
                )
                for field in field_schemas
            }
            key = tuple(normalized.get(field) for field in primary_key)
            if key in seen_keys:
                _issue(
                    issues,
                    source_name,
                    table_name,
                    row_number,
                    "+".join(primary_key),
                    provisional_id,
                    "unique primary key",
                    key,
                    f"change the key; first declared on row {seen_keys[key]}",
                )
            else:
                seen_keys[key] = row_number
            rows.append(normalized)
            row_numbers.append(row_number)

    rows_with_lines = list(zip(rows, row_numbers, strict=True))
    rows_with_lines.sort(key=lambda pair: tuple(pair[0].get(key) for key in table_schema["primary_key"]))
    return [pair[0] for pair in rows_with_lines], [pair[1] for pair in rows_with_lines]


def _validate_references(
    schema: dict[str, Any],
    tables: dict[str, list[dict[str, Any]]],
    row_lines: dict[str, list[int]],
    issues: list[ValidationIssue],
) -> None:
    lookup: dict[tuple[str, str], set[Any]] = {}
    for table_name, table_schema in schema["tables"].items():
        for field in table_schema["fields"]:
            lookup[(table_name, field["name"])] = {
                row[field["name"]] for row in tables[table_name]
            }

    for table_name, table_schema in schema["tables"].items():
        primary_field = table_schema["primary_key"][0]
        source_name = table_schema["source"]
        for index, row in enumerate(tables[table_name]):
            content_id = str(row.get(primary_field, ""))
            for field in table_schema["fields"]:
                if field["type"] != "ref" or not row.get(field["name"]):
                    continue
                target = (field["table"], field["field"])
                if target not in lookup:
                    raise ValueError(f"schema reference targets unknown field: {target}")
                if row[field["name"]] not in lookup[target]:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        field["name"],
                        content_id,
                        f"existing {field['table']}.{field['field']} reference",
                        row[field["name"]],
                        "add the referenced row or correct the ID",
                    )


def _validate_constraints(
    schema: dict[str, Any],
    tables: dict[str, list[dict[str, Any]]],
    row_lines: dict[str, list[int]],
    issues: list[ValidationIssue],
) -> None:
    for constraint in schema.get("constraints", []):
        constraint_type = constraint.get("type")
        if constraint_type == "required_child":
            parent_table = constraint["parent_table"]
            parent_field = constraint["parent_field"]
            child_table = constraint["child_table"]
            child_field = constraint["child_field"]
            child_values = {row[child_field] for row in tables[child_table]}
            source_name = schema["tables"][parent_table]["source"]
            for index, row in enumerate(tables[parent_table]):
                value = row[parent_field]
                if value not in child_values:
                    _issue(
                        issues,
                        source_name,
                        parent_table,
                        row_lines[parent_table][index],
                        parent_field,
                        str(value),
                        f"at least one {child_table}.{child_field} child row",
                        value,
                        f"add a row to {schema['tables'][child_table]['source']}",
                    )
        elif constraint_type == "required_when":
            table_name = constraint["table"]
            source_name = schema["tables"][table_name]["source"]
            when_field = constraint["when_field"]
            expected_value = constraint["equals"]
            required_field = constraint["required_field"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                if row.get(when_field) == expected_value and not row.get(required_field):
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        required_field,
                        str(row.get(primary_field, "")),
                        f"non-empty value when {when_field}={expected_value}",
                        row.get(required_field, ""),
                        f"set {required_field} to a valid referenced ID",
                    )
        elif constraint_type == "typed_value":
            table_name = constraint["table"]
            type_field = constraint["type_field"]
            value_field = constraint["value_field"]
            source_name = schema["tables"][table_name]["source"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                value_type = str(row.get(type_field, ""))
                raw_value = str(row.get(value_field, ""))
                try:
                    if value_type == "int":
                        converted: Any = int(raw_value, 10)
                    elif value_type == "float":
                        converted = float(raw_value)
                        if not math.isfinite(converted):
                            raise ValueError("number must be finite")
                    elif value_type == "bool":
                        normalized = raw_value.strip().lower()
                        if normalized not in {"true", "false"}:
                            raise ValueError("boolean must be true or false")
                        converted = normalized == "true"
                    elif value_type == "string":
                        converted = raw_value
                    else:
                        raise ValueError(f"unsupported value_type {value_type}")
                    row[value_field] = converted
                except ValueError as exc:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        value_field,
                        str(row.get(primary_field, "")),
                        f"value compatible with {type_field}={value_type}",
                        raw_value,
                        str(exc),
                    )
        elif constraint_type == "numeric_range":
            table_name = constraint["table"]
            value_field = constraint["value_field"]
            minimum_field = constraint["minimum_field"]
            maximum_field = constraint["maximum_field"]
            source_name = schema["tables"][table_name]["source"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                value = float(row[value_field])
                minimum = float(row[minimum_field])
                maximum = float(row[maximum_field])
                if minimum > maximum or value < minimum or value > maximum:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        value_field,
                        str(row.get(primary_field, "")),
                        f"{minimum_field} <= {value_field} <= {maximum_field}",
                        value,
                        "fix the value or its declared range",
                    )
        else:
            raise ValueError(f"unsupported constraint: {constraint_type}")


def load_and_validate(
    schema_path: Path = DEFAULT_SCHEMA,
    source_dir: Path = DEFAULT_SOURCE,
) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]]]:
    schema = _load_schema(schema_path)
    issues: list[ValidationIssue] = []
    tables: dict[str, list[dict[str, Any]]] = {}
    row_lines: dict[str, list[int]] = {}

    for table_name in sorted(schema["tables"]):
        rows, lines = _load_table(
            table_name, schema["tables"][table_name], source_dir, issues
        )
        tables[table_name] = rows
        row_lines[table_name] = lines

    _validate_references(schema, tables, row_lines, issues)
    _validate_constraints(schema, tables, row_lines, issues)
    if issues:
        raise ContentValidationError(issues)
    return schema, tables


def _json_bytes(value: Any) -> bytes:
    text = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    return text.encode("utf-8", errors="strict")


def _source_fingerprints(schema_path: Path, source_dir: Path, schema: dict[str, Any]) -> list[dict[str, Any]]:
    paths = [schema_path]
    paths.extend(
        source_dir / schema["tables"][name]["source"] for name in sorted(schema["tables"])
    )
    fingerprints = []
    for path in paths:
        data = path.read_bytes()
        relative = path.relative_to(PROJECT_ROOT).as_posix() if path.is_relative_to(PROJECT_ROOT) else path.name
        fingerprints.append(
            {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        )
    return fingerprints


def build_outputs(
    schema_path: Path = DEFAULT_SCHEMA,
    source_dir: Path = DEFAULT_SOURCE,
) -> tuple[dict[str, bytes], dict[str, int]]:
    schema, tables = load_and_validate(schema_path, source_dir)
    catalog = {"schema_version": schema["schema_version"], "tables": tables}
    catalog_bytes = _json_bytes(catalog)
    source_files = _source_fingerprints(schema_path, source_dir, schema)
    combined = hashlib.sha256()
    for item in source_files:
        combined.update(item["path"].encode("utf-8"))
        combined.update(b"\0")
        combined.update(item["sha256"].encode("ascii"))
        combined.update(b"\n")
    manifest = {
        "format_version": 1,
        "schema_version": schema["schema_version"],
        "generator": "tools/content_pipeline.py",
        "catalog_sha256": hashlib.sha256(catalog_bytes).hexdigest(),
        "combined_source_sha256": combined.hexdigest(),
        "source_files": source_files,
    }
    counts = {table: len(rows) for table, rows in tables.items()}
    return {CATALOG_NAME: catalog_bytes, MANIFEST_NAME: _json_bytes(manifest)}, counts


def _write_outputs(output_dir: Path, outputs: dict[str, bytes]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        (output_dir / name).write_bytes(data)


def _check_outputs(output_dir: Path, outputs: dict[str, bytes]) -> list[str]:
    stale = []
    for name, expected in outputs.items():
        path = output_dir / name
        if not path.is_file() or path.read_bytes() != expected:
            stale.append(name)
    return stale


def _print_success(command: str, counts: dict[str, int], json_mode: bool) -> None:
    payload = {"status": "ok", "command": command, "table_rows": counts}
    if json_mode:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    else:
        summary = ", ".join(f"{name}={count}" for name, count in sorted(counts.items()))
        print(f"[OK] data {command}: {summary}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check", "validate"))
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    try:
        outputs, counts = build_outputs(args.schema, args.source)
        if args.command == "build":
            _write_outputs(args.output, outputs)
        elif args.command == "check":
            stale = _check_outputs(args.output, outputs)
            if stale:
                message = f"generated data is stale or missing: {', '.join(stale)}"
                if args.json:
                    print(json.dumps({"status": "error", "message": message}, ensure_ascii=False))
                else:
                    print(f"[FAIL] {message}\n[NEXT] python tools/project.py data")
                return 1
        _print_success(args.command, counts, args.json)
        return 0
    except ContentValidationError as exc:
        if args.json:
            print(
                json.dumps(
                    {"status": "error", "issues": [issue.as_dict() for issue in exc.issues]},
                    ensure_ascii=False,
                    sort_keys=True,
                )
            )
        else:
            print(f"[FAIL] {len(exc.issues)} data validation issue(s)")
            for issue in exc.issues:
                print(f"  {issue}")
        return 1
    except (OSError, UnicodeError, ValueError) as exc:
        payload = {"status": "error", "message": str(exc)}
        print(json.dumps(payload, ensure_ascii=False) if args.json else f"[FAIL] {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
