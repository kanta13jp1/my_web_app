#!/usr/bin/env python3
"""Build a local-only, deduplicated manifest for explicit artifact inputs.

The helper reads only paths supplied on the command line, never opens tool UIs,
and never performs network requests. Findings contain rule IDs and counts, not
the matched secret or personal data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import re
import sys
import tempfile
from typing import Any, Iterable


SCHEMA_VERSION = 1
READ_CHUNK_BYTES = 1024 * 1024
DEFAULT_RISK_SCAN_BYTES = 10 * 1024 * 1024

SOURCE_TOOLS = (
    "chatgpt",
    "codex",
    "claude_code",
    "antigravity",
    "other_explicit_export",
)
INTAKE_METHODS = ("explicit_export", "local_workspace")
ARTIFACT_KINDS = (
    "image",
    "audio",
    "video",
    "design",
    "writing",
    "prompt",
    "idea",
    "game",
    "application",
    "template",
    "bundle",
)

TEXT_SUFFIXES = {
    ".csv",
    ".dart",
    ".env",
    ".html",
    ".json",
    ".md",
    ".py",
    ".sql",
    ".svg",
    ".toml",
    ".tsv",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}

SECRET_RULES = {
    "private_key": re.compile(r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"),
    "openai_api_key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"),
    "stripe_live_secret": re.compile(r"\bsk_live_[A-Za-z0-9]{16,}\b"),
    "github_token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    "aws_access_key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "credential_assignment": re.compile(
        r"(?im)^\s*(?:api[_-]?key|secret|password|passwd|token)\s*[:=]\s*"
        r"['\"]?[^\s'\"]{12,}"
    ),
}

PII_RULES = {
    "email_address": re.compile(
        r"\b[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
        r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\b"
    ),
    "japanese_phone": re.compile(
        r"(?<!\d)(?:0\d{1,4}[- ]?\d{1,4}[- ]?\d{3,4}|"
        r"\+81[- ]?\d{1,4}[- ]?\d{1,4}[- ]?\d{3,4})(?!\d)"
    ),
    "japanese_postal_code": re.compile(r"(?<!\d)\d{3}-\d{4}(?!\d)"),
    "japanese_my_number_candidate": re.compile(r"(?<!\d)\d{12}(?!\d)"),
}


def _arguments(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Scan explicitly supplied local files/directories and write a "
            "deduplicated, importable JSON manifest. No data is transmitted."
        )
    )
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--source-tool", required=True, choices=SOURCE_TOOLS)
    parser.add_argument(
        "--intake-method", required=True, choices=INTAKE_METHODS
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Manifest path, or '-' for stdout. Existing manifests are merged.",
    )
    parser.add_argument(
        "--max-risk-scan-bytes",
        type=int,
        default=DEFAULT_RISK_SCAN_BYTES,
        help="Maximum decoded bytes inspected per text-like file (default 10 MiB).",
    )
    parser.add_argument(
        "--artifact-kind",
        default="auto",
        choices=("auto", *ARTIFACT_KINDS),
        help=(
            "Product kind for all supplied paths. Use an explicit kind for "
            "designs, prompts, ideas, games, or other ambiguous file types."
        ),
    )
    parser.add_argument(
        "--fail-on-risk",
        action="store_true",
        help="Return exit code 2 when any block/review finding is present.",
    )
    args = parser.parse_args(argv)
    if args.source_tool == "chatgpt" and args.intake_method != "explicit_export":
        parser.error("ChatGPT intake is limited to explicit exports")
    if args.max_risk_scan_bytes < 0:
        parser.error("--max-risk-scan-bytes must be non-negative")
    return args


def _explicit_files(
    inputs: Iterable[Path], *, excluded_paths: set[Path] | None = None
) -> list[tuple[Path, str]]:
    excluded_paths = excluded_paths or set()
    files: list[tuple[Path, str]] = []
    for supplied in inputs:
        expanded = supplied.expanduser()
        if expanded.is_symlink():
            raise ValueError(f"symlink inputs are not scanned: {supplied}")
        path = expanded.resolve(strict=True)
        if path.is_file():
            if path not in excluded_paths:
                files.append((path, path.name))
            continue
        if not path.is_dir():
            raise ValueError(f"not a regular file or directory: {supplied}")
        for child in sorted(path.rglob("*"), key=lambda item: item.as_posix()):
            if (
                child.is_symlink()
                or not child.is_file()
                or child.resolve() in excluded_paths
            ):
                continue
            locator = (Path(path.name) / child.relative_to(path)).as_posix()
            files.append((child, locator))
    return sorted(files, key=lambda item: (item[1], item[0].as_posix()))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(READ_CHUNK_BYTES):
            digest.update(chunk)
    return digest.hexdigest()


def _mime_type(path: Path) -> str:
    guessed, encoding = mimetypes.guess_type(path.name, strict=False)
    if guessed:
        return f"{guessed}; encoding={encoding}" if encoding else guessed
    return "application/octet-stream"


def _artifact_kind(path: Path, mime_type: str) -> str:
    base_mime = mime_type.split(";", 1)[0]
    if base_mime.startswith("image/"):
        return "image"
    if base_mime.startswith("audio/"):
        return "audio"
    if base_mime.startswith("video/"):
        return "video"
    if path.suffix.lower() in {".md", ".pdf", ".txt"}:
        return "writing"
    if path.suffix.lower() in {".json", ".toml", ".yaml", ".yml"}:
        return "template"
    return "bundle"


def _is_text_like(path: Path, mime_type: str) -> bool:
    return (
        mime_type.startswith("text/")
        or mime_type.split(";", 1)[0]
        in {
            "application/json",
            "application/javascript",
            "application/sql",
            "application/xml",
        }
        or path.suffix.lower() in TEXT_SUFFIXES
        or path.name.lower().startswith(".env")
    )


def _read_risk_text(path: Path, limit: int) -> tuple[str, bool]:
    if limit == 0:
        return "", path.stat().st_size > 0
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    truncated = len(data) > limit
    return data[:limit].decode("utf-8", errors="ignore"), truncated


def _count_matches(pattern: re.Pattern[str], text: str) -> int:
    return sum(1 for _ in pattern.finditer(text))


def _risk_findings(
    path: Path,
    mime_type: str,
    source_tool: str,
    max_scan_bytes: int,
) -> tuple[list[dict[str, Any]], bool]:
    findings: list[dict[str, Any]] = []
    truncated = False
    if _is_text_like(path, mime_type):
        text, truncated = _read_risk_text(path, max_scan_bytes)
        for rule_id, pattern in SECRET_RULES.items():
            count = _count_matches(pattern, text)
            if count:
                findings.append(
                    {
                        "category": "secret",
                        "rule_id": rule_id,
                        "severity": "block",
                        "count": count,
                    }
                )
        for rule_id, pattern in PII_RULES.items():
            count = _count_matches(pattern, text)
            if count:
                findings.append(
                    {
                        "category": "pii",
                        "rule_id": rule_id,
                        "severity": "block",
                        "count": count,
                    }
                )

    base_mime = mime_type.split(";", 1)[0]
    if base_mime.startswith(("audio/", "video/")):
        findings.append(
            {
                "category": "rights",
                "rule_id": "face_voice_consent_review",
                "severity": "review",
                "count": 1,
            }
        )
    if source_tool == "chatgpt" and base_mime.startswith("audio/"):
        findings.append(
            {
                "category": "rights",
                "rule_id": "chatgpt_voice_output_standalone_audio",
                "severity": "block",
                "count": 1,
            }
        )
    if path.stat().st_size == 0:
        findings.append(
            {
                "category": "integrity",
                "rule_id": "empty_file",
                "severity": "block",
                "count": 1,
            }
        )
    return sorted(findings, key=lambda item: (item["category"], item["rule_id"])), truncated


def _entry(
    path: Path,
    locator: str,
    source_tool: str,
    intake_method: str,
    max_scan_bytes: int,
    artifact_kind: str,
) -> dict[str, Any]:
    mime_type = _mime_type(path)
    findings, truncated = _risk_findings(
        path, mime_type, source_tool, max_scan_bytes
    )
    return {
        "title": path.name,
        "artifact_sha256": _sha256(path),
        "mime_type": mime_type,
        "file_size_bytes": path.stat().st_size,
        "artifact_kind": (
            _artifact_kind(path, mime_type)
            if artifact_kind == "auto"
            else artifact_kind
        ),
        "provenance": [
            {
                "source_tool": source_tool,
                "intake_method": intake_method,
                "source_locator": locator,
            }
        ],
        "risk_scan": {
            "findings": findings,
            "scan_truncated": truncated,
            "matched_values_included": False,
        },
    }


def _load_existing(output: str) -> dict[str, Any]:
    if output == "-":
        return {"schema_version": SCHEMA_VERSION, "entries": []}
    path = Path(output)
    if not path.exists():
        return {"schema_version": SCHEMA_VERSION, "entries": []}
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != SCHEMA_VERSION or not isinstance(
        data.get("entries"), list
    ):
        raise ValueError("existing output is not an artifact intake v1 manifest")
    return data


def _merge_entry(existing: dict[str, Any], incoming: dict[str, Any]) -> None:
    provenance = {
        (
            item["source_tool"],
            item["intake_method"],
            item["source_locator"],
        ): item
        for item in existing.get("provenance", [])
    }
    for item in incoming["provenance"]:
        provenance[
            (item["source_tool"], item["intake_method"], item["source_locator"])
        ] = item
    existing["provenance"] = sorted(
        provenance.values(),
        key=lambda item: (
            item["source_tool"], item["intake_method"], item["source_locator"]
        ),
    )

    finding_map = {
        (item["category"], item["rule_id"], item["severity"]): item
        for item in existing.get("risk_scan", {}).get("findings", [])
    }
    for item in incoming["risk_scan"]["findings"]:
        key = (item["category"], item["rule_id"], item["severity"])
        prior = finding_map.get(key)
        if prior is None or item["count"] > prior["count"]:
            finding_map[key] = item
    existing["risk_scan"] = {
        "findings": sorted(
            finding_map.values(),
            key=lambda item: (item["category"], item["rule_id"]),
        ),
        "scan_truncated": bool(
            existing.get("risk_scan", {}).get("scan_truncated")
            or incoming["risk_scan"]["scan_truncated"]
        ),
        "matched_values_included": False,
    }


def build_manifest(args: argparse.Namespace) -> dict[str, Any]:
    manifest = _load_existing(args.output)
    by_hash = {
        entry["artifact_sha256"]: entry for entry in manifest.get("entries", [])
    }
    excluded_paths = (
        set()
        if args.output == "-"
        else {Path(args.output).expanduser().resolve()}
    )
    for path, locator in _explicit_files(
        args.paths, excluded_paths=excluded_paths
    ):
        incoming = _entry(
            path,
            locator,
            args.source_tool,
            args.intake_method,
            args.max_risk_scan_bytes,
            args.artifact_kind,
        )
        sha256 = incoming["artifact_sha256"]
        if sha256 in by_hash:
            if args.artifact_kind != "auto":
                by_hash[sha256]["artifact_kind"] = args.artifact_kind
            _merge_entry(by_hash[sha256], incoming)
        else:
            by_hash[sha256] = incoming

    entries = sorted(by_hash.values(), key=lambda item: item["artifact_sha256"])
    findings = [
        finding
        for entry in entries
        for finding in entry.get("risk_scan", {}).get("findings", [])
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "local_only": True,
        "entries": entries,
        "summary": {
            "unique_artifacts": len(entries),
            "blocked_artifacts": sum(
                any(finding["severity"] == "block" for finding in entry["risk_scan"]["findings"])
                for entry in entries
            ),
            "review_artifacts": sum(
                any(finding["severity"] == "review" for finding in entry["risk_scan"]["findings"])
                for entry in entries
            ),
            "finding_count": len(findings),
        },
    }


def _write_manifest(manifest: dict[str, Any], output: str) -> None:
    rendered = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    if output == "-":
        sys.stdout.write(rendered)
        return
    target = Path(output).expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.", suffix=".tmp", dir=target.parent
    )
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(rendered)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, target)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def main(argv: list[str] | None = None) -> int:
    try:
        args = _arguments(argv)
        manifest = build_manifest(args)
        _write_manifest(manifest, args.output)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"artifact intake failed: {error}", file=sys.stderr)
        return 1
    has_risk = manifest["summary"]["finding_count"] > 0
    return 2 if args.fail_on_risk and has_risk else 0


if __name__ == "__main__":
    raise SystemExit(main())
