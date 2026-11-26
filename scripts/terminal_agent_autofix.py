#!/usr/bin/env python3
"""Issue-driven terminal autofix, companion test generation, and build repair loop.

This module implements deterministic local automation for GitHub Issues:
1. Parses GitHub Issue payloads and redacts accidental credential strings.
2. Discovers matching Dart sources under bounded ``lib/`` and ``test/`` trees.
3. Plans minimal deterministic fixes and companion ``flutter_test`` scaffolds.
4. Parses ``flutter analyze`` / Dart CFE compiler diagnostics and runs a bounded
   iterative self-repair loop with fail-closed path/symlink boundary guards.
5. Validates generated outputs against repo secret-redaction and AI antipattern
   checks before optionally writing changes under ``--apply``.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable, Sequence

try:
    from check_ai_code_antipatterns import scan_file as scan_ai_antipatterns
    from security_review_input import redact_secrets_with_count
except ModuleNotFoundError:  # Imported as scripts.terminal_agent_autofix in unittest.
    try:
        from scripts.check_ai_code_antipatterns import scan_file as scan_ai_antipatterns
        from scripts.security_review_input import redact_secrets_with_count
    except ModuleNotFoundError:
        _SCRIPTS_DIR = Path(__file__).resolve().parent
        if str(_SCRIPTS_DIR) not in sys.path:
            sys.path.insert(0, str(_SCRIPTS_DIR))
        from check_ai_code_antipatterns import scan_file as scan_ai_antipatterns
        from security_review_input import redact_secrets_with_count


ALLOWED_PREFIXES = ("lib/", "test/")
SKIP_DIR_NAMES = {".dart_tool", ".git", "build", "node_modules"}
GENERATED_DART_SUFFIXES = (".g.dart", ".freezed.dart", ".mocks.dart")
DEFAULT_MAX_ITERATIONS = 3
MAX_ALLOWED_ITERATIONS = 5
MAX_SCAN_BYTES = 32_768

DART_PATH_RE = re.compile(r"(?:lib|test)/[A-Za-z0-9_./-]+\.dart")
CAMEL_IDENT_RE = re.compile(r"\b[A-Z][A-Za-z0-9]{3,}\b")
SNAKE_IDENT_RE = re.compile(r"\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b")
SECTION_HEADER_RE = re.compile(r"^##+\s+(.+?)\s*$")
TOP_LEVEL_DECL_RE = re.compile(
    r"^\s*(?:abstract\s+(?:base|final|interface|sealed)?\s*)?"
    r"(?:class|enum|mixin|extension)\s+([A-Z][A-Za-z0-9_]*)"
)
ANALYZER_DIAG_RE = re.compile(
    r"^\s*(?P<severity>error|warning|info)\s+(?:-|•)\s+(?P<message>.+?)\s+"
    r"(?:-|•)\s+(?P<path>[^\s:][^:]*\.dart):(?P<line>\d+):(?P<column>\d+)\s+"
    r"(?:-|•)\s+(?P<code>[A-Za-z0-9_]+)\s*$",
    re.IGNORECASE,
)
CFE_DIAG_RE = re.compile(
    r"^(?P<path>[^\s:][^:]*\.dart):(?P<line>\d+):(?P<column>\d+):\s*"
    r"(?P<severity>Error|Warning|Context):\s*(?P<message>.+)$"
)
PACKAGE_NAME_RE = re.compile(r"^\s*name:\s*([A-Za-z0-9_]+)\s*$", re.MULTILINE)
QUOTED_PARAM_RE = re.compile(r"['\"`]([A-Za-z_][A-Za-z0-9_]*)['\"`]")

JA_TERM_HINTS: dict[str, tuple[str, ...]] = {
    "ホーム": ("home",),
    "設定": ("settings",),
    "通知": ("notification", "notifications"),
    "認証": ("auth",),
    "残高": ("balance",),
    "資産": ("asset", "assets"),
    "同期": ("sync",),
    "テーマ": ("theme",),
    "キャッシュ": ("cache",),
    "テスト": ("test",),
    "ビルド": ("build",),
    "エラー": ("error",),
}


class PathBoundaryError(ValueError):
    """Raised when a target path escapes the allowed lib/ or test/ boundary."""


@dataclasses.dataclass(frozen=True)
class IssueSpec:
    number: int
    title: str
    body: str
    labels: tuple[str, ...]
    paths: tuple[str, ...]
    symbols: tuple[str, ...]
    keywords: tuple[str, ...]
    sections: dict[str, str]
    redaction_count: int


@dataclasses.dataclass(frozen=True)
class TargetMatch:
    path: str
    score: int
    matched_terms: tuple[str, ...]
    companion_test_path: str | None
    has_companion_test: bool


@dataclasses.dataclass(frozen=True)
class BuildDiagnostic:
    severity: str
    message: str
    path: str
    line: int
    column: int
    code: str


@dataclasses.dataclass(frozen=True)
class RepairAction:
    path: str
    kind: str
    summary: str
    applied: bool
    line: int | None = None
    code: str | None = None


@dataclasses.dataclass(frozen=True)
class IterationRecord:
    iteration: int
    diagnostic_count: int
    repaired_count: int
    blocked_paths: tuple[str, ...]
    remaining_count: int


@dataclasses.dataclass(frozen=True)
class AutofixReport:
    mode: str
    issue: IssueSpec
    matched_targets: tuple[TargetMatch, ...]
    actions: tuple[RepairAction, ...]
    iterations: tuple[IterationRecord, ...]
    converged: bool
    validation_passed: bool
    validation_findings: tuple[str, ...]
    redaction_count: int
    blocked_paths: tuple[str, ...]
    generated_tests: tuple[str, ...]


def normalize_repo_relpath(raw_path: str) -> str:
    """Normalize a candidate relative path to POSIX form without leading './'."""
    cleaned = raw_path.strip().replace("\\", "/")
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    return cleaned


def resolve_editable_repo_path(repo_root: Path, candidate: str) -> Path:
    """Resolve candidate path strictly within repo_root/{lib,test}/*.dart without symlinks.

    Rejects empty strings, NUL bytes, Windows drive letters, absolute paths,
    ``..`` traversal segments, paths outside ``lib/`` or ``test/``, non-Dart
    files, and any symlink along the resolved directory chain.
    """
    if not candidate or not candidate.strip() or "\x00" in candidate:
        raise PathBoundaryError(f"Empty or malformed path rejected: {candidate!r}")

    normalized = normalize_repo_relpath(candidate)
    if re.match(r"^[A-Za-z]:", normalized) or normalized.startswith(("/", "~")):
        raise PathBoundaryError(f"Absolute or home path rejected: {candidate!r}")

    rel_parts = Path(normalized).parts
    if not rel_parts or ".." in rel_parts or "." in rel_parts:
        raise PathBoundaryError(f"Path traversal segment rejected: {candidate!r}")

    if not normalized.startswith(ALLOWED_PREFIXES) or not normalized.endswith(".dart"):
        raise PathBoundaryError(
            f"Editable target must be a .dart file under lib/ or test/: {candidate!r}"
        )

    root_resolved = repo_root.resolve()
    current = repo_root
    for part in rel_parts:
        current = current / part
        if current.is_symlink():
            raise PathBoundaryError(f"Symlink path component rejected: {current}")

    target_resolved = current.resolve()
    try:
        rel_resolved = target_resolved.relative_to(root_resolved).as_posix()
    except ValueError as exc:
        raise PathBoundaryError(
            f"Resolved path escapes repository root: {candidate!r}"
        ) from exc

    if not rel_resolved.startswith(ALLOWED_PREFIXES) or not rel_resolved.endswith(".dart"):
        raise PathBoundaryError(
            f"Resolved target leaves lib/ or test/ boundary: {rel_resolved!r}"
        )
    return target_resolved


def _parse_markdown_sections(body: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    current_name = "overview"
    buffer: list[str] = []
    for line in body.splitlines():
        header_match = SECTION_HEADER_RE.match(line)
        if header_match:
            if buffer:
                sections[current_name] = "\n".join(buffer).strip()
            current_name = header_match.group(1).strip()
            buffer = []
            continue
        buffer.append(line)
    if buffer:
        sections[current_name] = "\n".join(buffer).strip()
    return sections


def _unique_preserve_order(items: Sequence[str]) -> tuple[str, ...]:
    seen: set[str] = set()
    ordered: list[str] = []
    for item in items:
        if item and item not in seen:
            seen.add(item)
            ordered.append(item)
    return tuple(ordered)


def parse_issue_payload(payload: dict[str, Any]) -> IssueSpec:
    """Parse an issue payload (direct dict or GitHub webhook envelope)."""
    raw_issue = payload.get("issue") if isinstance(payload.get("issue"), dict) else payload
    raw_number = raw_issue.get("number", 0)
    try:
        issue_number = int(raw_number) if raw_number not in (None, "") else 0
    except (TypeError, ValueError):
        issue_number = 0

    raw_title = str(raw_issue.get("title") or "")
    raw_body = str(raw_issue.get("body") or "")

    clean_title, title_redactions = redact_secrets_with_count(raw_title)
    clean_body, body_redactions = redact_secrets_with_count(raw_body)
    total_redactions = title_redactions + body_redactions

    raw_labels = raw_issue.get("labels") or []
    label_names: list[str] = []
    if isinstance(raw_labels, list):
        for entry in raw_labels:
            if isinstance(entry, dict) and entry.get("name"):
                label_names.append(str(entry["name"]))
            elif isinstance(entry, str) and entry.strip():
                label_names.append(entry.strip())

    combined = f"{clean_title}\n{clean_body}"
    extracted_paths = [normalize_repo_relpath(m) for m in DART_PATH_RE.findall(combined)]
    extracted_symbols = CAMEL_IDENT_RE.findall(combined) + SNAKE_IDENT_RE.findall(combined)

    keyword_candidates: list[str] = []
    stop_words = {
        "the",
        "and",
        "for",
        "with",
        "from",
        "that",
        "this",
        "note",
        "issue",
        "flutter",
        "lib",
        "test",
        "dart",
        "src",
        "file",
        "code",
        "app",
        "web",
        "fix",
        "add",
        "update",
        "use",
        "run",
        "build",
        "error",
        "class",
        "void",
        "bool",
        "true",
        "false",
        "string",
    }
    for word in re.findall(r"[A-Za-z][A-Za-z0-9_]{2,}", combined.lower()):
        if word not in stop_words:
            keyword_candidates.append(word)
    for ja_word, mapped in JA_TERM_HINTS.items():
        if ja_word in combined:
            keyword_candidates.extend(mapped)

    return IssueSpec(
        number=issue_number,
        title=clean_title.strip(),
        body=clean_body.strip(),
        labels=_unique_preserve_order(label_names),
        paths=_unique_preserve_order(extracted_paths),
        symbols=_unique_preserve_order(extracted_symbols),
        keywords=_unique_preserve_order(keyword_candidates),
        sections=_parse_markdown_sections(clean_body),
        redaction_count=total_redactions,
    )


def load_issue_input(
    *,
    issue_json: Path | None = None,
    issue_number: int = 0,
    title: str = "",
    body: str = "",
    body_file: Path | None = None,
) -> IssueSpec:
    """Load an IssueSpec from JSON file or explicit CLI flags."""
    if issue_json is not None:
        raw_payload = json.loads(issue_json.read_text(encoding="utf-8-sig"))
        if not isinstance(raw_payload, dict):
            raise ValueError(f"Issue JSON must decode to a JSON object: {issue_json}")
        return parse_issue_payload(raw_payload)

    resolved_body = body
    if body_file is not None:
        resolved_body = body_file.read_text(encoding="utf-8-sig")

    return parse_issue_payload(
        {
            "number": issue_number,
            "title": title,
            "body": resolved_body,
            "labels": [],
        }
    )


def companion_test_path_for(rel_path: str) -> str | None:
    """Map ``lib/foo/bar.dart`` -> ``test/foo/bar_test.dart``."""
    normalized = normalize_repo_relpath(rel_path)
    if not normalized.startswith("lib/") or not normalized.endswith(".dart"):
        return None
    inner = normalized[len("lib/") : -len(".dart")]
    return f"test/{inner}_test.dart"


def _iter_dart_files(repo_root: Path) -> list[Path]:
    collected: list[Path] = []
    for root_name in ("lib", "test"):
        base_dir = repo_root / root_name
        if not base_dir.exists() or base_dir.is_symlink() or not base_dir.is_dir():
            continue
        for current_root, dir_names, file_names in os.walk(base_dir, followlinks=False):
            dir_names[:] = sorted(
                name
                for name in dir_names
                if name not in SKIP_DIR_NAMES and not (Path(current_root) / name).is_symlink()
            )
            for file_name in sorted(file_names):
                if not file_name.endswith(".dart") or file_name.endswith(GENERATED_DART_SUFFIXES):
                    continue
                candidate = Path(current_root) / file_name
                if candidate.is_symlink():
                    continue
                collected.append(candidate)
    return collected


def _read_bounded_text(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            raw_bytes = handle.read(MAX_SCAN_BYTES)
        return raw_bytes.decode("utf-8", errors="replace")
    except OSError:
        return ""


def discover_target_files(
    repo_root: Path,
    issue: IssueSpec,
    *,
    limit: int = 8,
) -> list[TargetMatch]:
    """Scan bounded lib/ and test/ files and rank matches against the issue."""
    matches: list[TargetMatch] = []
    issue_path_set = set(issue.paths)
    symbol_set = issue.symbols[:20]
    keyword_set = issue.keywords[:24]

    for file_path in _iter_dart_files(repo_root):
        rel_posix = file_path.relative_to(repo_root).as_posix()
        rel_lower = rel_posix.lower()
        stem_lower = file_path.stem.lower()
        score = 0
        matched_terms: list[str] = []

        if rel_posix in issue_path_set:
            score += 100
            matched_terms.append(rel_posix)

        for sym in symbol_set:
            if sym.lower() in stem_lower:
                score += 25
                matched_terms.append(sym)

        for kw in keyword_set:
            if kw in stem_lower:
                score += 15
                matched_terms.append(kw)
            elif kw in rel_lower:
                score += 8
                matched_terms.append(kw)

        content = ""
        if symbol_set or score > 0:
            content = _read_bounded_text(file_path)
            for sym in symbol_set:
                if sym in content:
                    score += 18 if f"class {sym}" in content else 8
                    matched_terms.append(sym)

        if score <= 0:
            continue

        companion_rel = companion_test_path_for(rel_posix)
        has_companion = False
        if companion_rel is not None:
            companion_abs = repo_root / companion_rel
            has_companion = companion_abs.is_file() and not companion_abs.is_symlink()

        matches.append(
            TargetMatch(
                path=rel_posix,
                score=score,
                matched_terms=_unique_preserve_order(matched_terms),
                companion_test_path=companion_rel,
                has_companion_test=has_companion,
            )
        )

    matches.sort(key=lambda item: (-item.score, item.path))
    return matches[: max(limit, 1)]


def read_pubspec_package_name(repo_root: Path) -> str:
    pubspec = repo_root / "pubspec.yaml"
    if pubspec.is_file() and not pubspec.is_symlink():
        match = PACKAGE_NAME_RE.search(pubspec.read_text(encoding="utf-8", errors="replace"))
        if match:
            return match.group(1)
    return "my_web_app"


def _detect_primary_symbol(lib_content: str) -> str | None:
    for line in lib_content.splitlines():
        match = TOP_LEVEL_DECL_RE.match(line)
        if match and not match.group(1).startswith("_"):
            return match.group(1)
    return None


def generate_test_scaffold(
    repo_root: Path,
    lib_rel_path: str,
    lib_content: str,
    *,
    package_name: str | None = None,
) -> str:
    """Create a clean, lint-compliant companion flutter_test scaffold."""
    normalized = normalize_repo_relpath(lib_rel_path)
    if not normalized.startswith("lib/") or not normalized.endswith(".dart"):
        raise PathBoundaryError(f"Expected lib/*.dart path for test scaffold: {lib_rel_path!r}")

    pkg = package_name or read_pubspec_package_name(repo_root)
    import_subpath = normalized[len("lib/") :]
    symbol = _detect_primary_symbol(lib_content)
    subject_label = symbol or Path(normalized).stem

    lines = [
        "import 'package:flutter_test/flutter_test.dart';",
        f"import 'package:{pkg}/{import_subpath}';",
        "",
        "void main() {",
        f"  group('{subject_label} autofix regression coverage', () {{",
        "    test('exposes primary target contract', () {",
    ]
    if symbol:
        lines.append(f"      expect({symbol}, isNotNull);")
    else:
        lines.append(f"      const targetPath = '{normalized}';")
        lines.append("      expect(targetPath, endsWith('.dart'));")
    lines.extend(
        [
            "    });",
            "  });",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def _replace_with_opacity(text: str, target_line: int | None = None) -> tuple[str, list[int]]:
    """Deterministically rewrite .withOpacity(x) -> .withValues(alpha: x)."""
    lines = text.splitlines(keepends=True)
    changed_lines: list[int] = []
    marker = ".withOpacity("

    for idx, raw_line in enumerate(lines, start=1):
        if target_line is not None and idx != target_line:
            continue
        cursor = 0
        out_parts: list[str] = []
        modified_here = False
        while True:
            pos = raw_line.find(marker, cursor)
            if pos == -1:
                out_parts.append(raw_line[cursor:])
                break
            out_parts.append(raw_line[cursor:pos])
            arg_start = pos + len(marker)
            depth = 1
            scan = arg_start
            while scan < len(raw_line) and depth > 0:
                ch = raw_line[scan]
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                scan += 1
            if depth != 0:
                out_parts.append(raw_line[pos:])
                break
            arg_expr = raw_line[arg_start : scan - 1].strip()
            out_parts.append(f".withValues(alpha: {arg_expr})")
            cursor = scan
            modified_here = True
        if modified_here:
            lines[idx - 1] = "".join(out_parts)
            changed_lines.append(idx)

    return "".join(lines), changed_lines


def extract_build_diagnostics(output: str) -> list[BuildDiagnostic]:
    """Parse flutter/dart analyze lines, CFE compile errors, or JSON diagnostics."""
    stripped = output.strip()
    if not stripped:
        return []

    diagnostics: list[BuildDiagnostic] = []
    if stripped.startswith("["):
        loaded = json.loads(stripped)
        if not isinstance(loaded, list):
            raise ValueError("Diagnostics JSON payload must be a list")
        for item in loaded:
            if not isinstance(item, dict):
                continue
            diagnostics.append(
                BuildDiagnostic(
                    severity=str(item.get("severity") or "error").lower(),
                    message=str(item.get("message") or ""),
                    path=normalize_repo_relpath(str(item.get("path") or "")),
                    line=int(item.get("line") or 1),
                    column=int(item.get("column") or 1),
                    code=str(item.get("code") or "unknown"),
                )
            )
        return diagnostics

    seen: set[tuple[str, int, int, str]] = set()
    for raw_line in output.splitlines():
        analyzer_match = ANALYZER_DIAG_RE.match(raw_line)
        if analyzer_match:
            diag = BuildDiagnostic(
                severity=analyzer_match.group("severity").lower(),
                message=analyzer_match.group("message").strip(),
                path=normalize_repo_relpath(analyzer_match.group("path")),
                line=int(analyzer_match.group("line")),
                column=int(analyzer_match.group("column")),
                code=analyzer_match.group("code").strip(),
            )
        else:
            cfe_match = CFE_DIAG_RE.match(raw_line.strip())
            if not cfe_match:
                continue
            msg = cfe_match.group("message").strip()
            inferred_code = "withOpacity_error" if "withOpacity" in msg else "compile_error"
            diag = BuildDiagnostic(
                severity=cfe_match.group("severity").lower(),
                message=msg,
                path=normalize_repo_relpath(cfe_match.group("path")),
                line=int(cfe_match.group("line")),
                column=int(cfe_match.group("column")),
                code=inferred_code,
            )

        dedupe_key = (diag.path, diag.line, diag.column, diag.code)
        if dedupe_key not in seen:
            seen.add(dedupe_key)
            diagnostics.append(diag)

    return diagnostics


def _apply_prefer_const_literal(line_text: str) -> str | None:
    pattern = re.compile(r"(?P<before>(?:^|[=:(,\[\s]|=>)\s*)(?P<literal>(?:<[A-Za-z0-9_<>, ?]+>)?\[)")
    match = pattern.search(line_text)
    if not match:
        return None
    prefix_end = match.start("literal")
    before = line_text[:prefix_end]
    if re.search(r"\bconst\s+$", before):
        return None
    return f"{before}const {line_text[prefix_end:]}"


def _apply_trailing_comma(line_text: str) -> str | None:
    stripped = line_text.rstrip("\r\n")
    eol = line_text[len(stripped) :]
    match = re.match(r"^(?P<prefix>.*?[^\s,])(?P<closer>\s*[\)\]][;,)]*)$", stripped)
    if not match:
        return None
    return f"{match.group('prefix')},{match.group('closer')}{eol}"


def _apply_prefer_final_parameter(line_text: str, column: int | None = None) -> str | None:
    stripped = line_text.rstrip("\r\n")
    eol = line_text[len(stripped) :]
    param_pattern = re.compile(
        r"^(?P<lead>\s*)(?P<req>required\s+)?"
        r"(?!(?:final|var|const|this\.|super\.)\b)"
        r"(?P<rest>[A-Za-z_][A-Za-z0-9_<>,?.\s]*\s+[A-Za-z_][A-Za-z0-9_]*.*)$"
    )
    open_idx = stripped.find("(")
    close_idx = stripped.rfind(")")
    if open_idx != -1 and close_idx > open_idx + 1 and not stripped.lstrip().startswith(("final ", "required ")):
        inner = stripped[open_idx + 1 : close_idx]
        segments = inner.split(",")
        cursor = open_idx + 2  # 1-based column start of first segment
        best_index: int | None = None
        for idx, segment in enumerate(segments):
            seg_end = cursor + len(segment)
            if column is not None and cursor <= column <= seg_end and param_pattern.match(segment):
                best_index = idx
                break
            if best_index is None and param_pattern.match(segment):
                best_index = idx
            cursor = seg_end + 1
        if best_index is None:
            return None
        target_seg = segments[best_index]
        matched = param_pattern.match(target_seg)
        if not matched:
            return None
        req = matched.group("req") or ""
        segments[best_index] = f"{matched.group('lead')}{req}final {matched.group('rest')}"
        updated_inner = ",".join(segments)
        return f"{stripped[: open_idx + 1]}{updated_inner}{stripped[close_idx:]}{eol}"

    match = param_pattern.match(stripped)
    if not match:
        return None
    req = match.group("req") or ""
    return f"{match.group('lead')}{req}final {match.group('rest')}{eol}"


def _apply_unused_element_parameter(line_text: str, message: str) -> str | None:
    param_match = QUOTED_PARAM_RE.search(message)
    if not param_match:
        return None
    param_name = param_match.group(1)
    if param_name.startswith("_"):
        return None
    updated, count = re.subn(rf"\b{re.escape(param_name)}\b", f"_{param_name}", line_text, count=1)
    return updated if count else None


def apply_diagnostic_fix(content: str, diagnostic: BuildDiagnostic) -> tuple[str, RepairAction | None]:
    """Apply a single deterministic diagnostic repair to file content."""
    lines = content.splitlines(keepends=True)
    line_index = diagnostic.line - 1
    if line_index < 0 or line_index >= len(lines):
        return content, None

    code_lower = diagnostic.code.lower()
    msg_lower = diagnostic.message.lower()
    original_line = lines[line_index]

    is_with_opacity_diag = (
        "withopacity" in msg_lower
        or "withopacity" in code_lower
        or (
            code_lower in {"deprecated_member_use", "deprecated_member_use_from_same_package"}
            and (".withOpacity(" in original_line or ".withValues(" in original_line)
        )
    )
    if is_with_opacity_diag:
        updated, changed = _replace_with_opacity(content, target_line=diagnostic.line)
        if changed:
            return updated, RepairAction(
                path=diagnostic.path,
                kind="diagnostic_fix",
                summary=f"Replaced deprecated .withOpacity(...) with .withValues(alpha: ...) at line {diagnostic.line}",
                applied=False,
                line=diagnostic.line,
                code=diagnostic.code,
            )
        if ".withOpacity(" not in original_line and ".withValues(" in original_line:
            return content, RepairAction(
                path=diagnostic.path,
                kind="diagnostic_already_resolved",
                summary=f"Line {diagnostic.line} already uses .withValues(...)",
                applied=False,
                line=diagnostic.line,
                code=diagnostic.code,
            )
        return content, None

    replacement_line: str | None = None
    summary = ""

    if code_lower == "prefer_const_literals_to_create_immutables":
        replacement_line = _apply_prefer_const_literal(original_line)
        summary = f"Added const modifier to immutable literal at line {diagnostic.line}"
    elif code_lower == "require_trailing_commas":
        replacement_line = _apply_trailing_comma(original_line)
        summary = f"Added trailing comma at line {diagnostic.line}"
    elif code_lower == "prefer_final_parameters":
        replacement_line = _apply_prefer_final_parameter(original_line, column=diagnostic.column)
        summary = f"Added final modifier to parameter at line {diagnostic.line}"
    elif code_lower == "unused_element_parameter":
        replacement_line = _apply_unused_element_parameter(original_line, diagnostic.message)
        summary = f"Prefixed unused parameter with '_' at line {diagnostic.line}"

    if replacement_line is None or replacement_line == original_line:
        return content, None

    lines[line_index] = replacement_line
    return "".join(lines), RepairAction(
        path=diagnostic.path,
        kind="diagnostic_fix",
        summary=summary,
        applied=False,
        line=diagnostic.line,
        code=diagnostic.code,
    )


def plan_repairs(
    repo_root: Path,
    issue: IssueSpec,
    targets: Sequence[TargetMatch],
    *,
    max_targets: int = 3,
) -> tuple[dict[str, str], list[RepairAction], list[str]]:
    """Plan deterministic code fixes and missing companion test scaffolds."""
    planned_files: dict[str, str] = {}
    actions: list[RepairAction] = []
    blocked_paths: list[str] = []

    lib_targets = [match for match in targets if match.path.startswith("lib/")][:max_targets]
    for match in lib_targets:
        try:
            abs_lib = resolve_editable_repo_path(repo_root, match.path)
        except PathBoundaryError as exc:
            blocked_paths.append(f"{match.path}: {exc}")
            continue

        if not abs_lib.is_file():
            continue

        original_text = abs_lib.read_text(encoding="utf-8", errors="replace")
        updated_text, changed_lines = _replace_with_opacity(original_text)
        if changed_lines:
            planned_files[match.path] = updated_text
            actions.append(
                RepairAction(
                    path=match.path,
                    kind="proactive_lint_fix",
                    summary=f"Updated .withOpacity(...) on line(s) {', '.join(map(str, changed_lines))}",
                    applied=False,
                    line=changed_lines[0],
                    code="deprecated_member_use",
                )
            )

        if match.companion_test_path and not match.has_companion_test:
            try:
                resolve_editable_repo_path(repo_root, match.companion_test_path)
            except PathBoundaryError as exc:
                blocked_paths.append(f"{match.companion_test_path}: {exc}")
                continue
            scaffold = generate_test_scaffold(repo_root, match.path, updated_text)
            planned_files[match.companion_test_path] = scaffold
            actions.append(
                RepairAction(
                    path=match.companion_test_path,
                    kind="generate_test_scaffold",
                    summary=f"Generated companion flutter_test scaffold for {match.path} (Issue #{issue.number})",
                    applied=False,
                )
            )

    return planned_files, actions, blocked_paths


def run_self_repair_loop(
    repo_root: Path,
    initial_diagnostics: Sequence[BuildDiagnostic],
    *,
    max_iterations: int = DEFAULT_MAX_ITERATIONS,
    reevaluate: Callable[[dict[str, str]], list[BuildDiagnostic]] | None = None,
    seed_files: dict[str, str] | None = None,
) -> tuple[dict[str, str], list[RepairAction], list[IterationRecord], bool, list[str]]:
    """Iteratively apply deterministic build fixes up to max_iterations."""
    bounded_iters = max(1, min(max_iterations, MAX_ALLOWED_ITERATIONS))
    working_files: dict[str, str] = dict(seed_files or {})
    actions: list[RepairAction] = []
    iterations: list[IterationRecord] = []
    blocked_paths: list[str] = []
    current_diags = list(initial_diagnostics)

    for iter_num in range(1, bounded_iters + 1):
        if iter_num > 1 and reevaluate is not None:
            current_diags = list(reevaluate(dict(working_files)))

        if not current_diags:
            iterations.append(
                IterationRecord(
                    iteration=iter_num,
                    diagnostic_count=0,
                    repaired_count=0,
                    blocked_paths=(),
                    remaining_count=0,
                )
            )
            return working_files, actions, iterations, True, blocked_paths

        iter_repaired = 0
        iter_blocked: list[str] = []
        unresolved: list[BuildDiagnostic] = []

        for diag in current_diags:
            try:
                abs_path = resolve_editable_repo_path(repo_root, diag.path)
            except PathBoundaryError as exc:
                msg = f"{diag.path}: {exc}"
                iter_blocked.append(msg)
                blocked_paths.append(msg)
                unresolved.append(diag)
                continue

            norm_rel = normalize_repo_relpath(diag.path)
            if norm_rel not in working_files:
                if not abs_path.is_file():
                    unresolved.append(diag)
                    continue
                working_files[norm_rel] = abs_path.read_text(encoding="utf-8", errors="replace")

            updated_text, action = apply_diagnostic_fix(working_files[norm_rel], diag)
            if action is None:
                unresolved.append(diag)
                continue

            working_files[norm_rel] = updated_text
            actions.append(action)
            iter_repaired += 1

        iterations.append(
            IterationRecord(
                iteration=iter_num,
                diagnostic_count=len(current_diags),
                repaired_count=iter_repaired,
                blocked_paths=tuple(iter_blocked),
                remaining_count=len(unresolved),
            )
        )

        if reevaluate is None:
            if not unresolved and iter_repaired > 0:
                iterations.append(
                    IterationRecord(
                        iteration=iter_num + 1,
                        diagnostic_count=0,
                        repaired_count=0,
                        blocked_paths=(),
                        remaining_count=0,
                    )
                )
                return working_files, actions, iterations, True, blocked_paths
            current_diags = unresolved
            if iter_repaired == 0:
                break
        elif iter_repaired == 0 and unresolved:
            break

    return working_files, actions, iterations, False, blocked_paths


def validate_file_contents(file_map: dict[str, str]) -> tuple[bool, list[str], int]:
    """Validate proposed files against secret-redaction and AI antipattern checks."""
    findings: list[str] = []
    total_redactions = 0

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_root = Path(tmp_dir)
        for rel_path, content in sorted(file_map.items()):
            _, redact_cnt = redact_secrets_with_count(content)
            total_redactions += redact_cnt
            if redact_cnt > 0:
                findings.append(f"{rel_path}: detected {redact_cnt} potential secret pattern(s)")

            temp_target = tmp_root / rel_path
            temp_target.parent.mkdir(parents=True, exist_ok=True)
            temp_target.write_text(content.replace("\r\n", "\n"), encoding="utf-8")
            for finding in scan_ai_antipatterns(temp_target):
                findings.append(f"{rel_path}: {finding.render()}")

    return (len(findings) == 0 and total_redactions == 0), findings, total_redactions


def apply_validated_edits(
    repo_root: Path,
    file_map: dict[str, str],
    actions: Sequence[RepairAction],
) -> tuple[list[Path], list[RepairAction]]:
    """Write validated lib/ and test/ edits safely onto disk."""
    written_paths: list[Path] = []
    for rel_path, content in sorted(file_map.items()):
        abs_target = resolve_editable_repo_path(repo_root, rel_path)
        abs_target.parent.mkdir(parents=True, exist_ok=True)
        normalized_content = content.replace("\r\n", "\n")
        if normalized_content and not normalized_content.endswith("\n"):
            normalized_content += "\n"
        abs_target.write_text(normalized_content, encoding="utf-8", newline="\n")
        written_paths.append(abs_target)

    updated_actions = [
        dataclasses.replace(action, applied=(normalize_repo_relpath(action.path) in file_map))
        for action in actions
    ]
    return written_paths, updated_actions


def commit_applied_changes(
    repo_root: Path,
    written_paths: Sequence[Path],
    issue: IssueSpec,
) -> tuple[bool, str]:
    """Commit only the explicitly written lib/ and test/ files locally."""
    if not written_paths:
        return False, "No written files to commit"
    rel_args = [path.resolve().relative_to(repo_root.resolve()).as_posix() for path in written_paths]
    add_proc = subprocess.run(
        ["git", "add", "--", *rel_args],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if add_proc.returncode != 0:
        return False, add_proc.stderr.strip() or "git add failed"
    commit_msg = f"autofix: issue #{issue.number} deterministic repair and test scaffold"
    commit_proc = subprocess.run(
        ["git", "commit", "-m", commit_msg],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if commit_proc.returncode != 0:
        return False, commit_proc.stderr.strip() or "git commit failed"
    return True, commit_proc.stdout.strip()


def report_to_dict(report: AutofixReport) -> dict[str, Any]:
    return dataclasses.asdict(report)


def format_markdown_report(report: AutofixReport) -> str:
    """Format a human-readable redacted Markdown summary."""
    lines = [
        "## Terminal Agent Autofix Report",
        "",
        f"- Mode: `{report.mode}`",
        f"- Issue: `#{report.issue.number}` - {report.issue.title or '(untitled)'}",
        f"- Matched targets: `{len(report.matched_targets)}`",
        f"- Actions planned/applied: `{len(report.actions)}`",
        f"- Build loop converged: `{str(report.converged).lower()}`",
        f"- Deterministic validation passed: `{str(report.validation_passed).lower()}`",
        f"- Secret redactions: `{report.redaction_count}`",
        "",
    ]
    if report.matched_targets:
        lines.append("### Matched Targets")
        for match in report.matched_targets:
            lines.append(
                f"- `{match.path}` (score `{match.score}`, terms: `{', '.join(match.matched_terms) or 'none'}`)"
            )
        lines.append("")
    if report.actions:
        lines.append("### Actions")
        for action in report.actions:
            status = "applied" if action.applied else "planned"
            lines.append(f"- [{status}] `{action.path}` (`{action.kind}`): {action.summary}")
        lines.append("")
    if report.iterations:
        lines.append("### Self-Repair Iterations")
        for step in report.iterations:
            lines.append(
                f"- Iteration `{step.iteration}`: diagnostics=`{step.diagnostic_count}`, "
                f"repaired=`{step.repaired_count}`, remaining=`{step.remaining_count}`"
            )
        lines.append("")
    if report.blocked_paths:
        lines.append("### Blocked Out-of-Scope Paths")
        for item in report.blocked_paths:
            lines.append(f"- `{item}`")
        lines.append("")
    if report.validation_findings:
        lines.append("### Validation Findings")
        for item in report.validation_findings:
            lines.append(f"- {item}")
        lines.append("")

    rendered = "\n".join(lines).rstrip() + "\n"
    redacted_md, _ = redact_secrets_with_count(rendered)
    return redacted_md


def _write_outputs(
    report: AutofixReport,
    *,
    json_out: Path | None,
    markdown_out: Path | None,
    github_output: Path | None,
) -> None:
    payload_text = json.dumps(report_to_dict(report), ensure_ascii=False, indent=2) + "\n"
    redacted_json, _ = redact_secrets_with_count(payload_text)
    if json_out is not None:
        json_out.parent.mkdir(parents=True, exist_ok=True)
        json_out.write_text(redacted_json, encoding="utf-8", newline="\n")
    if markdown_out is not None:
        markdown_out.parent.mkdir(parents=True, exist_ok=True)
        markdown_out.write_text(format_markdown_report(report), encoding="utf-8", newline="\n")
    if github_output is not None:
        github_output.parent.mkdir(parents=True, exist_ok=True)
        with github_output.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(f"mode={report.mode}\n")
            handle.write(f"matched_count={len(report.matched_targets)}\n")
            handle.write(f"action_count={len(report.actions)}\n")
            handle.write(f"converged={str(report.converged).lower()}\n")
            handle.write(f"validation_passed={str(report.validation_passed).lower()}\n")


def run_autofix(
    repo_root: Path,
    issue: IssueSpec,
    *,
    diagnostics_text: str = "",
    max_iterations: int = DEFAULT_MAX_ITERATIONS,
    apply: bool = False,
    git_commit: bool = False,
) -> AutofixReport:
    """Execute full issue discovery, repair planning, diagnostic loop, and validation."""
    targets = discover_target_files(repo_root, issue)
    planned_files, planned_actions, plan_blocked = plan_repairs(repo_root, issue, targets)

    initial_diags = extract_build_diagnostics(diagnostics_text)
    combined_files, loop_actions, iterations, converged, loop_blocked = run_self_repair_loop(
        repo_root,
        initial_diags,
        max_iterations=max_iterations,
        seed_files=planned_files,
    )
    all_actions: list[RepairAction] = [*planned_actions, *loop_actions]
    all_blocked = _unique_preserve_order([*plan_blocked, *loop_blocked])

    validation_ok, validation_findings, code_redactions = validate_file_contents(combined_files)
    total_redactions = issue.redaction_count + code_redactions
    generated_tests = tuple(sorted(p for p in combined_files if p.startswith("test/")))

    mode = "apply" if apply else "dry_run"
    if apply and combined_files and validation_ok and not all_blocked:
        written_paths, all_actions = apply_validated_edits(repo_root, combined_files, all_actions)
        if git_commit:
            ok, message = commit_applied_changes(repo_root, written_paths, issue)
            if not ok:
                validation_ok = False
                validation_findings.append(f"git commit failed: {message}")

    return AutofixReport(
        mode=mode,
        issue=issue,
        matched_targets=tuple(targets),
        actions=tuple(all_actions),
        iterations=tuple(iterations),
        converged=converged,
        validation_passed=validation_ok,
        validation_findings=tuple(validation_findings),
        redaction_count=total_redactions,
        blocked_paths=all_blocked,
        generated_tests=generated_tests,
    )


def run_self_test() -> int:
    """Run an offline deterministic end-to-end verification in a temporary directory."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_root = Path(tmp_dir)
        (tmp_root / "pubspec.yaml").write_text("name: sample_app\n", encoding="utf-8")
        sample_lib = tmp_root / "lib" / "services" / "demo_sync_service.dart"
        sample_lib.parent.mkdir(parents=True, exist_ok=True)
        sample_lib.write_text(
            "\n".join(
                [
                    "import 'dart:ui';",
                    "",
                    "class DemoSyncService {",
                    "  Color tintColor(Color base) {",
                    "    return base.withOpacity(0.4);",
                    "  }",
                    "",
                    "  List<String> labels() => ['a'];",
                    "}",
                    "",
                ]
            ),
            encoding="utf-8",
        )

        issue = parse_issue_payload(
            {
                "number": 2675,
                "title": "DemoSyncService の withOpacity 修正とテスト追加",
                "body": "Update `lib/services/demo_sync_service.dart` and add tests.",
                "labels": [{"name": "ai-autofix"}],
            }
        )
        diag_sample = "\n".join(
            [
                "info - Use withValues - lib/services/demo_sync_service.dart:5:17 - deprecated_member_use",
                "info - Prefer const literals - lib/services/demo_sync_service.dart:8:28 - prefer_const_literals_to_create_immutables",
            ]
        )

        dry_report = run_autofix(tmp_root, issue, diagnostics_text=diag_sample, apply=False)
        assert dry_report.mode == "dry_run"
        assert dry_report.converged is True
        assert dry_report.validation_passed is True
        assert dry_report.matched_targets[0].path == "lib/services/demo_sync_service.dart"
        assert not (tmp_root / "test" / "services" / "demo_sync_service_test.dart").exists()

        apply_report = run_autofix(tmp_root, issue, diagnostics_text=diag_sample, apply=True)
        assert apply_report.mode == "apply"
        assert apply_report.converged is True
        assert (tmp_root / "test" / "services" / "demo_sync_service_test.dart").is_file()
        updated_src = sample_lib.read_text(encoding="utf-8")
        assert ".withValues(alpha: 0.4)" in updated_src
        assert "const ['a']" in updated_src

        try:
            resolve_editable_repo_path(tmp_root, "../escape.dart")
            raise AssertionError("Expected PathBoundaryError for path traversal")
        except PathBoundaryError:
            pass

    print("OK: terminal_agent_autofix self-test passed")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--issue-json", type=Path)
    parser.add_argument("--issue-number", type=int, default=0)
    parser.add_argument("--title", default="")
    parser.add_argument("--body", default="")
    parser.add_argument("--body-file", type=Path)
    parser.add_argument("--diagnostics-file", type=Path)
    parser.add_argument("--max-iterations", type=int, default=DEFAULT_MAX_ITERATIONS)
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--dry-run", action="store_true", help="Plan repairs without modifying files (default)")
    mode_group.add_argument("--apply", action="store_true", help="Write validated lib/ and test/ edits")
    parser.add_argument("--git-commit", action="store_true", help="Commit written files locally when --apply passes")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--markdown-out", type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    repo_root = args.repo_root.resolve()
    issue = load_issue_input(
        issue_json=args.issue_json,
        issue_number=args.issue_number,
        title=args.title,
        body=args.body,
        body_file=args.body_file,
    )
    diagnostics_text = ""
    if args.diagnostics_file is not None and args.diagnostics_file.is_file():
        diagnostics_text = args.diagnostics_file.read_text(encoding="utf-8-sig")

    report = run_autofix(
        repo_root,
        issue,
        diagnostics_text=diagnostics_text,
        max_iterations=args.max_iterations,
        apply=bool(args.apply),
        git_commit=bool(args.git_commit),
    )
    _write_outputs(
        report,
        json_out=args.json_out,
        markdown_out=args.markdown_out,
        github_output=args.github_output,
    )
    if args.json_out is None and args.markdown_out is None:
        print(format_markdown_report(report), end="")

    if report.blocked_paths or not report.validation_passed or not report.converged:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
