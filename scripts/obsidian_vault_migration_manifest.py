#!/usr/bin/env python3
"""Create a local-only migration manifest for an Obsidian vault.

The scanner never performs network requests or copies vault files. Credential
candidates and excluded configuration/instruction paths are classified from
their path only: they are not opened or hashed. Markdown output contains
structure (properties, wikilinks, embeds, callout/task counts), never note body
text or property values.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile
from typing import Any, Iterable


SCHEMA_VERSION = 1
READ_CHUNK_BYTES = 1024 * 1024

PRUNED_DIRECTORIES = {".git"}
SYSTEM_DIRECTORIES = {".obsidian"}
SCRIPT_DIRECTORIES = {"scripts"}
TEMPLATE_DIRECTORIES = {"templates"}
MIGRATION_METADATA_DIRECTORIES = {"_control", "_source"}
INSTRUCTION_FILE_NAMES = {
    "agents.md",
    "claude.md",
    "codex.md",
}
SENSITIVE_NOTE_STEMS = {
    "accounts_list",
    "debt_management",
    "financial_records",
    "housing_records",
    "legal_and_business_tasks",
    "subscription_list",
}
CREDENTIAL_SUFFIXES = {
    ".cer",
    ".crt",
    ".env",
    ".jks",
    ".key",
    ".p12",
    ".pem",
    ".pfx",
}
CREDENTIAL_NAME_HINT = re.compile(
    r"(?i)(?:credential|oauth|private[-_ ]?key|secret|service[-_ ]?account|token)"
)
ATTACHMENT_SUFFIXES = {
    ".avif",
    ".bmp",
    ".csv",
    ".doc",
    ".docx",
    ".gif",
    ".heic",
    ".jpeg",
    ".jpg",
    ".m4a",
    ".mov",
    ".mp3",
    ".mp4",
    ".ogg",
    ".pdf",
    ".png",
    ".ppt",
    ".pptx",
    ".svg",
    ".tif",
    ".tiff",
    ".tsv",
    ".wav",
    ".webm",
    ".webp",
    ".xls",
    ".xlsx",
    ".zip",
}

WIKILINK = re.compile(r"(!?)\[\[([^\[\]]+?)\]\]")
EXTERNAL_LINK = re.compile(r"(?<!!)\[[^\]\r\n]+\]\(https?://[^)\s]+(?:\s+[^)]*)?\)")
CALLOUT = re.compile(r"(?im)^\s*>\s*\[!([a-z0-9_-]+)\]")
TASK = re.compile(r"(?im)^\s*[-*+]\s+\[([ x])\]\s+")
FRONTMATTER_KEY = re.compile(r"^([^\s#][^:\r\n]*?)\s*:")


@dataclass(frozen=True)
class VaultEntry:
    path: Path
    relative_path: str
    size_bytes: int
    is_symlink: bool = False


def _arguments(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--sensitive-note",
        action="append",
        default=[],
        help=(
            "Additional Markdown filename or stem that must require manual "
            "review. May be repeated."
        ),
    )
    parser.add_argument(
        "--credential-path",
        action="append",
        default=[],
        help=(
            "Known credential path relative to the vault. It is classified "
            "without being opened or hashed. May be repeated."
        ),
    )
    parser.add_argument(
        "--fail-on-review",
        action="store_true",
        help="Return exit code 2 when review-required or credential files exist.",
    )
    return parser.parse_args(argv)


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _validate_paths(vault: Path, output: Path) -> tuple[Path, Path]:
    vault = vault.expanduser().resolve(strict=True)
    if not vault.is_dir():
        raise ValueError(f"vault is not a directory: {vault}")
    if vault.is_symlink():
        raise ValueError("symlink vault roots are not scanned")

    output = output.expanduser().resolve()
    if _is_relative_to(output, vault):
        raise ValueError("output must be outside the vault to keep it read-only")
    return vault, output


def _walk_vault(vault: Path) -> Iterable[VaultEntry]:
    def visit(directory: Path, relative_directory: PurePosixPath) -> Iterable[VaultEntry]:
        with os.scandir(directory) as iterator:
            entries = sorted(iterator, key=lambda entry: entry.name.casefold())
        for entry in entries:
            relative = relative_directory / entry.name
            relative_path = relative.as_posix()
            if entry.is_symlink():
                stat = entry.stat(follow_symlinks=False)
                yield VaultEntry(
                    path=Path(entry.path),
                    relative_path=relative_path,
                    size_bytes=stat.st_size,
                    is_symlink=True,
                )
                continue
            if entry.is_dir(follow_symlinks=False):
                if entry.name.casefold() in PRUNED_DIRECTORIES:
                    continue
                yield from visit(Path(entry.path), relative)
                continue
            if entry.is_file(follow_symlinks=False):
                stat = entry.stat(follow_symlinks=False)
                yield VaultEntry(
                    path=Path(entry.path),
                    relative_path=relative_path,
                    size_bytes=stat.st_size,
                )

    return visit(vault, PurePosixPath())


def _path_parts(entry: VaultEntry) -> tuple[str, ...]:
    return tuple(part.casefold() for part in PurePosixPath(entry.relative_path).parts)


def _classify(
    entry: VaultEntry,
    sensitive_note_stems: set[str],
    credential_paths: set[str],
) -> tuple[str, str, str]:
    parts = _path_parts(entry)
    path = entry.path
    name = path.name.casefold()
    suffix = path.suffix.casefold()
    stem = path.stem.casefold()

    if entry.is_symlink:
        return "symlink", "exclude", "symlink_not_followed"
    if any(part in SYSTEM_DIRECTORIES for part in parts[:-1]):
        return "system_config", "exclude", "obsidian_configuration"
    if any(part.startswith(".") for part in parts):
        return "hidden_path", "exclude", "hidden_or_backup_path"
    if any(part in SCRIPT_DIRECTORIES for part in parts[:-1]):
        return "script", "exclude", "executable_or_automation"
    if any(part in TEMPLATE_DIRECTORIES for part in parts[:-1]):
        return "template", "exclude", "template_requires_separate_review"
    if any(part in MIGRATION_METADATA_DIRECTORIES for part in parts[:-1]):
        return "migration_metadata", "exclude", "raw_or_control_migration_data"
    if name in INSTRUCTION_FILE_NAMES:
        return "instruction", "exclude", "agent_or_workspace_instruction"
    if entry.relative_path.casefold() in credential_paths:
        return "credential_candidate", "exclude", "explicit_credential_path"
    if suffix in CREDENTIAL_SUFFIXES or CREDENTIAL_NAME_HINT.search(name):
        return "credential_candidate", "exclude", "credential_candidate_path"
    if suffix == ".json":
        return "structured_data", "exclude", "json_requires_separate_review"
    if suffix == ".md" and stem in sensitive_note_stems:
        return "note", "review_required", "sensitive_note_policy"
    if suffix == ".md":
        return "note", "auto_stage", "markdown_note"
    if suffix in ATTACHMENT_SUFFIXES:
        return "attachment", "auto_stage", "supported_attachment"
    return "unsupported", "exclude", "unsupported_file_type"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(READ_CHUNK_BYTES):
            digest.update(chunk)
    return digest.hexdigest()


def _frontmatter_keys(lines: list[str]) -> tuple[bool, list[str]]:
    if not lines or lines[0].strip() != "---":
        return False, []
    keys: set[str] = set()
    for line in lines[1:]:
        if line.strip() == "---":
            return True, sorted(keys, key=str.casefold)
        if line.startswith((" ", "\t")):
            continue
        match = FRONTMATTER_KEY.match(line)
        if match:
            keys.add(match.group(1).strip())
    return False, []


def _link_target(raw: str) -> str:
    target = raw.split("|", 1)[0].strip()
    return target


def _read_markdown_metadata(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    frontmatter_present, property_keys = _frontmatter_keys(text.splitlines())

    link_counts: Counter[tuple[str, bool]] = Counter()
    for match in WIKILINK.finditer(text):
        target = _link_target(match.group(2))
        if target:
            link_counts[(target, bool(match.group(1)))] += 1
    links = [
        {
            "target": target,
            "embedded": embedded,
            "occurrences": count,
        }
        for (target, embedded), count in sorted(
            link_counts.items(), key=lambda item: (item[0][0].casefold(), item[0][1])
        )
    ]

    callout_types = Counter(match.group(1).casefold() for match in CALLOUT.finditer(text))
    tasks = [match.group(1).casefold() for match in TASK.finditer(text)]
    return {
        "frontmatter_present": frontmatter_present,
        "property_keys": property_keys,
        "wikilinks": links,
        "external_link_count": len(EXTERNAL_LINK.findall(text)),
        "callout_types": dict(sorted(callout_types.items())),
        "task_count": len(tasks),
        "completed_task_count": sum(value == "x" for value in tasks),
    }


def _record_for(
    entry: VaultEntry,
    sensitive_note_stems: set[str],
    credential_paths: set[str],
) -> dict[str, Any]:
    category, action, reason = _classify(
        entry, sensitive_note_stems, credential_paths
    )
    inspect_content = category == "note" and action != "exclude"
    hash_content = action != "exclude" and category in {"note", "attachment"}
    record: dict[str, Any] = {
        "relative_path": entry.relative_path,
        "category": category,
        "migration_action": action,
        "reason": reason,
        "size_bytes": entry.size_bytes,
        "content_inspected": inspect_content,
        "sha256": _sha256(entry.path) if hash_content else None,
    }
    if inspect_content:
        record["markdown"] = _read_markdown_metadata(entry.path)
    return record


def _target_base(target: str) -> str:
    return target.split("#", 1)[0].split("^", 1)[0].strip().replace("\\", "/")


def _target_indexes(
    records: list[dict[str, Any]],
) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    exact: dict[str, dict[str, Any]] = {}
    by_stem: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        relative = PurePosixPath(record["relative_path"])
        exact[relative.as_posix().casefold()] = record
        exact[relative.with_suffix("").as_posix().casefold()] = record
        by_stem[relative.stem.casefold()].append(record)
    return exact, by_stem


def _resolve_link(
    source_path: str,
    target: str,
    exact: dict[str, dict[str, Any]],
    by_stem: dict[str, list[dict[str, Any]]],
) -> tuple[dict[str, Any] | None, bool]:
    base = _target_base(target)
    if not base:
        return exact.get(source_path.casefold()), False
    source_parent = PurePosixPath(source_path).parent
    candidates = [
        PurePosixPath(base).as_posix().casefold(),
        (source_parent / base).as_posix().casefold(),
    ]
    for candidate in candidates:
        if candidate in exact:
            return exact[candidate], False
    stem_matches = by_stem.get(PurePosixPath(base).stem.casefold(), [])
    if len(stem_matches) == 1:
        return stem_matches[0], False
    return None, len(stem_matches) > 1


def _resolve_graph(records: list[dict[str, Any]]) -> tuple[int, set[str]]:
    exact, by_stem = _target_indexes(records)
    unresolved = 0
    referenced_attachments: set[str] = set()
    attachment_sources: dict[str, set[str]] = defaultdict(set)

    for record in records:
        markdown = record.get("markdown")
        if markdown is None:
            continue
        resolved_links: list[dict[str, Any]] = []
        for link in markdown["wikilinks"]:
            target_record, ambiguous = _resolve_link(
                record["relative_path"], link["target"], exact, by_stem
            )
            resolved_path = (
                target_record["relative_path"] if target_record is not None else None
            )
            is_resolved = target_record is not None
            if not is_resolved:
                unresolved += link["occurrences"]
            resolved_links.append(
                {
                    **link,
                    "resolved": is_resolved,
                    "ambiguous": ambiguous,
                    "resolved_relative_path": resolved_path,
                    "target_migration_action": (
                        target_record["migration_action"]
                        if target_record is not None
                        else None
                    ),
                }
            )
            if (
                link["embedded"]
                and target_record is not None
                and target_record["category"] == "attachment"
            ):
                referenced_attachments.add(target_record["relative_path"])
                attachment_sources[target_record["relative_path"]].add(
                    record["relative_path"]
                )
        markdown["wikilinks"] = resolved_links

    for record in records:
        if record["category"] == "attachment":
            record["referenced_by"] = sorted(
                attachment_sources.get(record["relative_path"], set()),
                key=str.casefold,
            )
    return unresolved, referenced_attachments


def build_manifest(
    vault: Path,
    *,
    additional_sensitive_notes: Iterable[str] = (),
    credential_paths: Iterable[str] = (),
) -> dict[str, Any]:
    sensitive_note_stems = set(SENSITIVE_NOTE_STEMS)
    sensitive_note_stems.update(
        Path(value).stem.casefold() for value in additional_sensitive_notes
    )
    normalized_credential_paths = {
        PurePosixPath(value.replace("\\", "/")).as_posix().casefold()
        for value in credential_paths
    }
    entries = [
        _record_for(entry, sensitive_note_stems, normalized_credential_paths)
        for entry in _walk_vault(vault)
    ]
    entries.sort(key=lambda entry: entry["relative_path"].casefold())
    unresolved_links, referenced_attachments = _resolve_graph(entries)

    action_counts = Counter(entry["migration_action"] for entry in entries)
    category_counts = Counter(entry["category"] for entry in entries)
    attachment_paths = {
        entry["relative_path"]
        for entry in entries
        if entry["category"] == "attachment"
        and entry["migration_action"] != "exclude"
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "local_only": True,
        "vault_name": vault.name,
        "source_absolute_path_included": False,
        "policy": {
            "network_requests": False,
            "vault_files_copied": False,
            "note_body_or_property_values_included": False,
            "excluded_files_opened_or_hashed": False,
        },
        "entries": entries,
        "summary": {
            "file_count": len(entries),
            "action_counts": dict(sorted(action_counts.items())),
            "category_counts": dict(sorted(category_counts.items())),
            "review_required_count": action_counts["review_required"],
            "credential_candidate_count": category_counts["credential_candidate"],
            "unresolved_wikilink_occurrences": unresolved_links,
            "unreferenced_attachment_count": len(
                attachment_paths - referenced_attachments
            ),
        },
    }


def _write_manifest(manifest: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", suffix=".tmp", dir=output.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(rendered)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, output)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def main(argv: list[str] | None = None) -> int:
    args = _arguments(argv)
    try:
        vault, output = _validate_paths(args.vault, args.output)
        manifest = build_manifest(
            vault,
            additional_sensitive_notes=args.sensitive_note,
            credential_paths=args.credential_path,
        )
        _write_manifest(manifest, output)
    except (OSError, ValueError) as error:
        print(f"Obsidian vault manifest failed: {error}", file=sys.stderr)
        return 1

    print(json.dumps(manifest["summary"], ensure_ascii=False, sort_keys=True))
    needs_review = (
        manifest["summary"]["review_required_count"] > 0
        or manifest["summary"]["credential_candidate_count"] > 0
    )
    return 2 if args.fail_on_review and needs_review else 0


if __name__ == "__main__":
    raise SystemExit(main())
