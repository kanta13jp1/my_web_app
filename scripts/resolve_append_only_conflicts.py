#!/usr/bin/env python3
"""Detect and safely auto-resolve git merge conflicts in append-only documents."""

from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

try:
    from check_roadmap_append_only import PLACEHOLDER_MARKERS
except ModuleNotFoundError:
    from scripts.check_roadmap_append_only import PLACEHOLDER_MARKERS


APPEND_ONLY_PATH_PATTERNS: tuple[str, ...] = (
    "docs/GROWTH_STRATEGY_ROADMAP.md",
    "docs/LOCAL_PERSISTENCE_RETIREMENT_ROADMAP.md",
    "docs/QUARTERLY_ROADMAP.md",
    "docs/EDGE_FUNCTION_LIST.md",
    "docs/WORKTREE_REGISTRY.md",
    "docs/roadmap/*.md",
    "docs/roadmaps/*.md",
    "docs/technical/*ROADMAP*.md",
    "docs/ai-tool-changelog/*.md",
)

OURS_MARKER = "<<<<<<<"
BASE_MARKER = "|||||||"
SEP_MARKER = "======="
THEIRS_MARKER = ">>>>>>>"


class ConflictParseError(ValueError):
    """Raised when git conflict markers are malformed or unbalanced."""


@dataclass(frozen=True)
class ConflictHunk:
    start_line: int
    end_line: int
    ours_label: str
    theirs_label: str
    ours_lines: tuple[str, ...]
    base_lines: tuple[str, ...]
    theirs_lines: tuple[str, ...]


@dataclass(frozen=True)
class ConflictResolutionResult:
    resolved_text: str
    conflicts_found: int
    ours_lines_kept: int
    theirs_lines_kept: int
    duplicate_lines_skipped: int
    changed: bool
    hunks: tuple[ConflictHunk, ...]


@dataclass(frozen=True)
class FileResolutionReport:
    path: str
    status: str
    conflicts_found: int
    ours_lines_kept: int
    theirs_lines_kept: int
    duplicate_lines_skipped: int
    wrote_file: bool
    message: str


def normalize_path(path: str) -> str:
    normalized = path.replace("\ufeff", "").replace("\\", "/").strip()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


def is_append_only_path(path: str) -> bool:
    normalized = normalize_path(path)
    return any(
        fnmatch.fnmatchcase(normalized, pattern)
        for pattern in APPEND_ONLY_PATH_PATTERNS
    )


def _is_marker(line: str, marker: str) -> bool:
    if marker == SEP_MARKER:
        return line == SEP_MARKER
    return line == marker or line.startswith(marker + " ")


def has_conflict_markers(text: str) -> bool:
    for line in text.splitlines():
        if (
            _is_marker(line, OURS_MARKER)
            or _is_marker(line, BASE_MARKER)
            or _is_marker(line, SEP_MARKER)
            or _is_marker(line, THEIRS_MARKER)
        ):
            return True
    return False


def _merge_hunk_lines(
    ours_lines: list[str],
    theirs_lines: list[str],
    *,
    dedupe_blocks: bool,
) -> tuple[list[str], int, int, int]:
    if not dedupe_blocks:
        merged = [*ours_lines, *theirs_lines]
        return merged, len(ours_lines), len(theirs_lines), 0

    if ours_lines == theirs_lines:
        return list(ours_lines), len(ours_lines), 0, len(theirs_lines)

    seen_nonempty = {line.strip() for line in ours_lines if line.strip()}
    merged = list(ours_lines)
    kept_theirs: list[str] = []
    skipped = 0
    pending_blank = False

    for line in theirs_lines:
        stripped = line.strip()
        if not stripped:
            pending_blank = bool(merged and merged[-1].strip())
            continue
        if stripped in seen_nonempty:
            skipped += 1
            continue
        if pending_blank:
            kept_theirs.append("")
            pending_blank = False
        seen_nonempty.add(stripped)
        kept_theirs.append(line)

    merged.extend(kept_theirs)
    return merged, len(ours_lines), len(kept_theirs), skipped


def resolve_conflict_text(
    text: str,
    *,
    dedupe_blocks: bool = True,
    check_placeholders: bool = True,
) -> ConflictResolutionResult:
    """Resolve all 2-way or diff3 git conflict blocks by retaining both sides."""
    had_trailing_newline = text.endswith("\n")
    lines = text.splitlines()
    out_lines: list[str] = []
    hunks: list[ConflictHunk] = []
    ours_total = 0
    theirs_total = 0
    skipped_total = 0

    state = "outside"
    start_line = 0
    ours_label = ""
    theirs_label = ""
    ours_buf: list[str] = []
    base_buf: list[str] = []
    theirs_buf: list[str] = []

    for line_no, line in enumerate(lines, start=1):
        if state == "outside":
            if _is_marker(line, OURS_MARKER):
                state = "ours"
                start_line = line_no
                ours_label = line[len(OURS_MARKER) :].strip()
                ours_buf = []
                base_buf = []
                theirs_buf = []
            elif (
                _is_marker(line, BASE_MARKER)
                or _is_marker(line, SEP_MARKER)
                or _is_marker(line, THEIRS_MARKER)
            ):
                raise ConflictParseError(
                    f"Unexpected conflict marker at line {line_no}: {line}"
                )
            else:
                out_lines.append(line)
        elif state == "ours":
            if _is_marker(line, BASE_MARKER):
                state = "base"
            elif _is_marker(line, SEP_MARKER):
                state = "theirs"
            elif _is_marker(line, OURS_MARKER) or _is_marker(line, THEIRS_MARKER):
                raise ConflictParseError(
                    f"Malformed conflict block opened at line {start_line} (line {line_no})"
                )
            else:
                ours_buf.append(line)
        elif state == "base":
            if _is_marker(line, SEP_MARKER):
                state = "theirs"
            elif _is_marker(line, OURS_MARKER) or _is_marker(line, THEIRS_MARKER):
                raise ConflictParseError(
                    f"Malformed diff3 block opened at line {start_line} (line {line_no})"
                )
            else:
                base_buf.append(line)
        elif state == "theirs":
            if _is_marker(line, THEIRS_MARKER):
                theirs_label = line[len(THEIRS_MARKER) :].strip()
                merged, o_cnt, t_cnt, skip_cnt = _merge_hunk_lines(
                    ours_buf,
                    theirs_buf,
                    dedupe_blocks=dedupe_blocks,
                )
                out_lines.extend(merged)
                ours_total += o_cnt
                theirs_total += t_cnt
                skipped_total += skip_cnt
                hunks.append(
                    ConflictHunk(
                        start_line=start_line,
                        end_line=line_no,
                        ours_label=ours_label,
                        theirs_label=theirs_label,
                        ours_lines=tuple(ours_buf),
                        base_lines=tuple(base_buf),
                        theirs_lines=tuple(theirs_buf),
                    )
                )
                state = "outside"
            elif _is_marker(line, OURS_MARKER) or _is_marker(line, BASE_MARKER):
                raise ConflictParseError(
                    f"Nested conflict marker inside block from line {start_line} (line {line_no})"
                )
            else:
                theirs_buf.append(line)

    if state != "outside":
        raise ConflictParseError(
            f"Unclosed git conflict block starting at line {start_line}"
        )

    resolved_text = "\n".join(out_lines)
    if resolved_text and had_trailing_newline:
        resolved_text += "\n"
    elif not lines and text:
        resolved_text = text

    if check_placeholders:
        found_markers = [m for m in PLACEHOLDER_MARKERS if m in resolved_text]
        if found_markers:
            raise ConflictParseError(
                "Resolved content contains forbidden placeholder markers: "
                + ", ".join(found_markers)
            )

    return ConflictResolutionResult(
        resolved_text=resolved_text,
        conflicts_found=len(hunks),
        ours_lines_kept=ours_total,
        theirs_lines_kept=theirs_total,
        duplicate_lines_skipped=skipped_total,
        changed=len(hunks) > 0,
        hunks=tuple(hunks),
    )


def detect_unmerged_git_files(repo_root: Path | None = None) -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=U"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "git diff --diff-filter=U failed")
    return [normalize_path(line) for line in proc.stdout.splitlines() if line.strip()]


def resolve_file(
    path: Path,
    *,
    repo_root: Path | None = None,
    write: bool = False,
    allow_any: bool = False,
    dedupe_blocks: bool = True,
) -> FileResolutionReport:
    if repo_root is not None:
        try:
            rel_path = normalize_path(str(path.resolve().relative_to(repo_root.resolve())))
        except ValueError:
            rel_path = normalize_path(str(path))
    else:
        rel_path = normalize_path(str(path))

    if not path.exists():
        return FileResolutionReport(
            path=rel_path,
            status="missing",
            conflicts_found=0,
            ours_lines_kept=0,
            theirs_lines_kept=0,
            duplicate_lines_skipped=0,
            wrote_file=False,
            message="File not found",
        )

    raw_bytes = path.read_bytes()
    text = raw_bytes.decode("utf-8-sig").replace("\r\n", "\n")

    if not has_conflict_markers(text):
        return FileResolutionReport(
            path=rel_path,
            status="clean",
            conflicts_found=0,
            ours_lines_kept=0,
            theirs_lines_kept=0,
            duplicate_lines_skipped=0,
            wrote_file=False,
            message="No conflict markers",
        )

    if not allow_any and not is_append_only_path(rel_path):
        return FileResolutionReport(
            path=rel_path,
            status="rejected_non_append_only",
            conflicts_found=0,
            ours_lines_kept=0,
            theirs_lines_kept=0,
            duplicate_lines_skipped=0,
            wrote_file=False,
            message="Refused union merge on non-append-only file without --allow-any",
        )

    try:
        result = resolve_conflict_text(text, dedupe_blocks=dedupe_blocks)
    except ConflictParseError as exc:
        return FileResolutionReport(
            path=rel_path,
            status="error",
            conflicts_found=0,
            ours_lines_kept=0,
            theirs_lines_kept=0,
            duplicate_lines_skipped=0,
            wrote_file=False,
            message=str(exc),
        )

    wrote = False
    if write and result.changed:
        path.write_bytes(result.resolved_text.encode("utf-8"))
        wrote = True

    return FileResolutionReport(
        path=rel_path,
        status="resolved" if wrote else "would_resolve",
        conflicts_found=result.conflicts_found,
        ours_lines_kept=result.ours_lines_kept,
        theirs_lines_kept=result.theirs_lines_kept,
        duplicate_lines_skipped=result.duplicate_lines_skipped,
        wrote_file=wrote,
        message=(
            f"Resolved {result.conflicts_found} conflict(s) "
            f"(ours={result.ours_lines_kept}, theirs={result.theirs_lines_kept}, "
            f"skipped_dups={result.duplicate_lines_skipped})"
        ),
    )


def discover_append_only_files(repo_root: Path) -> list[Path]:
    proc = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", errors="replace").strip())
    paths: list[Path] = []
    for entry in proc.stdout.decode("utf-8", errors="replace").split("\0"):
        if entry and is_append_only_path(entry):
            paths.append(repo_root / entry)
    return sorted(paths)


def build_markdown_report(reports: Iterable[FileResolutionReport], mode: str) -> str:
    report_list = list(reports)
    lines = [
        "## Append-Only Conflict Resolution Report",
        "",
        f"- Mode: `{mode}`",
        f"- Checked files: {len(report_list)}",
        "",
        "| Path | Status | Conflicts | Ours lines | Theirs lines | Skipped dup | Message |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for item in report_list:
        lines.append(
            f"| `{item.path}` | `{item.status}` | {item.conflicts_found} | "
            f"{item.ours_lines_kept} | {item.theirs_lines_kept} | "
            f"{item.duplicate_lines_skipped} | {item.message} |"
        )
    lines.append("")
    return "\n".join(lines)


def run_self_test() -> tuple[bool, str]:
    two_way = (
        "# Roadmap\n"
        "- base\n"
        "<<<<<<< HEAD\n"
        "- entry from instance A\n"
        "- shared item\n"
        "=======\n"
        "- shared item\n"
        "- entry from instance B\n"
        ">>>>>>> origin/main\n"
        "- footer\n"
    )
    res = resolve_conflict_text(two_way)
    if (
        res.conflicts_found != 1
        or "- entry from instance A" not in res.resolved_text
        or "- entry from instance B" not in res.resolved_text
        or res.resolved_text.count("- shared item") != 1
    ):
        return False, "Self-test failed: 2-way merge/dedupe mismatch"

    diff3 = (
        "<<<<<<< HEAD\n"
        "- A\n"
        "||||||| base\n"
        "- old\n"
        "=======\n"
        "- B\n"
        ">>>>>>> branch\n"
    )
    res_diff3 = resolve_conflict_text(diff3)
    if "- old" in res_diff3.resolved_text or "- A" not in res_diff3.resolved_text or "- B" not in res_diff3.resolved_text:
        return False, "Self-test failed: diff3 base stripping mismatch"

    try:
        resolve_conflict_text("<<<<<<< HEAD\n- unclosed\n")
        return False, "Self-test failed: unclosed marker did not raise"
    except ConflictParseError:
        pass

    if is_append_only_path("lib/main.dart") or not is_append_only_path("docs/GROWTH_STRATEGY_ROADMAP.md"):
        return False, "Self-test failed: append-only path allowlist check failed"

    return True, "Self-test passed: 2-way union, diff3, fail-closed parser, and allowlist verified."


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="Files to inspect or resolve")
    parser.add_argument("--files", nargs="*", default=[], help="Additional file paths")
    parser.add_argument("--from-git", action="store_true", help="Inspect unmerged git index files")
    parser.add_argument("--scan-tracked", action="store_true", help="Check all tracked append-only files")
    parser.add_argument("--check", action="store_true", help="Fail if any conflict markers exist")
    parser.add_argument("--dry-run", action="store_true", help="Report fixes without writing files")
    parser.add_argument("--write", action="store_true", help="Write resolved content back to disk")
    parser.add_argument("--allow-any", action="store_true", help="Allow non-allowlisted file paths")
    parser.add_argument("--no-dedupe-blocks", action="store_true", help="Retain duplicate entries verbatim")
    parser.add_argument("--repo-root", default=".", help="Repository root path")
    parser.add_argument("--json-out", default="", help="Optional JSON report path")
    parser.add_argument("--markdown-out", default="", help="Optional Markdown report path")
    parser.add_argument("--self-test", action="store_true", help="Run built-in verification checks")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.self_test:
        ok, message = run_self_test()
        print(message)
        return 0 if ok else 1

    repo_root = Path(args.repo_root).resolve()
    targets: list[Path] = []
    seen_targets: set[Path] = set()

    def add_target(candidate: Path) -> None:
        resolved = candidate if candidate.is_absolute() else (repo_root / candidate)
        if resolved not in seen_targets:
            seen_targets.add(resolved)
            targets.append(resolved)

    for raw in [*args.paths, *args.files]:
        add_target(Path(raw))

    if args.from_git:
        for rel in detect_unmerged_git_files(repo_root):
            add_target(repo_root / rel)

    if args.scan_tracked:
        for tracked in discover_append_only_files(repo_root):
            add_target(tracked)

    if not targets and not args.dry_run and not args.check and not args.scan_tracked:
        for rel in detect_unmerged_git_files(repo_root):
            add_target(repo_root / rel)

    should_write = bool(args.write) and not args.dry_run and not args.check
    mode = "check" if args.check else ("dry-run" if args.dry_run or not should_write else "write")

    reports = [
        resolve_file(
            target,
            repo_root=repo_root,
            write=should_write,
            allow_any=args.allow_any,
            dedupe_blocks=not args.no_dedupe_blocks,
        )
        for target in targets
    ]

    if args.json_out:
        payload = {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "mode": mode,
            "reports": [asdict(item) for item in reports],
        }
        Path(args.json_out).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    if args.markdown_out:
        Path(args.markdown_out).write_text(
            build_markdown_report(reports, mode),
            encoding="utf-8",
        )

    for item in reports:
        print(f"[{item.status}] {item.path}: {item.message}")

    blocking_statuses = {"error", "rejected_non_append_only", "missing"}
    if args.check:
        blocking_statuses.add("would_resolve")

    if any(item.status in blocking_statuses for item in reports):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
