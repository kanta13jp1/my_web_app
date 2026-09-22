#!/usr/bin/env python3
"""Advisory checks for common AI-generated code anti-patterns.

The Claude Code PostToolUse hook calls this script for the file that was just
written or edited. Findings are intentionally advisory: deterministic format,
lint, test, and human-review gates remain authoritative.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


GENERATED_SUFFIXES = (".g.dart", ".freezed.dart", ".mocks.dart")
GHOST_STEM_SUFFIXES = ("_copy", "-copy", "_new", "-new", "_final", "-final", "_tmp", "-tmp")
PLACEHOLDER_PATTERNS = (
    (re.compile(r"\bUnimplementedError\s*\("), "unimplemented-stub", "UnimplementedError remains in the edited file"),
    (re.compile(r"\bNotImplementedError\s*\("), "unimplemented-stub", "NotImplementedError remains in the edited file"),
    (re.compile(r"\bTODO\s*:\s*(?:implement|implementation)\b", re.IGNORECASE), "implementation-todo", "implementation TODO remains in the edited file"),
)


@dataclass(frozen=True)
class Finding:
    code: str
    message: str
    line: int | None = None

    def render(self) -> str:
        location = f" line {self.line}" if self.line is not None else ""
        return f"[{self.code}]{location}: {self.message}"


def _is_generated(path: Path) -> bool:
    normalized = path.as_posix().lower()
    return (
        any(normalized.endswith(suffix) for suffix in GENERATED_SUFFIXES)
        or "/build/" in f"/{normalized}/"
        or "/.dart_tool/" in f"/{normalized}/"
    )


def _source_lines(text: str) -> list[tuple[int, str]]:
    lines: list[tuple[int, str]] = []
    in_block_comment = False
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw
        if in_block_comment:
            if "*/" not in line:
                continue
            line = line.split("*/", 1)[1]
            in_block_comment = False
        while "/*" in line:
            before, after = line.split("/*", 1)
            if "*/" in after:
                line = before + after.split("*/", 1)[1]
            else:
                line = before
                in_block_comment = True
                break
        line = line.split("//", 1)[0]
        if line.strip():
            lines.append((number, line))
    return lines


def _ghost_duplicate(path: Path) -> Finding | None:
    lowered = path.stem.lower()
    for suffix in GHOST_STEM_SUFFIXES:
        if not lowered.endswith(suffix):
            continue
        canonical_stem = path.stem[: -len(suffix)]
        canonical = path.with_name(canonical_stem + path.suffix)
        if canonical.exists():
            return Finding(
                "possible-ghost-file",
                f"{path.name} looks like a duplicate of existing {canonical.name}; edit the canonical file or explain why both are needed",
            )
    return None


def scan_file(path: Path, *, dynamic_threshold: int = 4) -> list[Finding]:
    if not path.exists() or not path.is_file() or _is_generated(path):
        return []
    if path.stat().st_size == 0:
        return [Finding("empty-file", "edited file is empty; confirm it is not a ghost artifact or accidental truncation")]

    findings: list[Finding] = []
    ghost = _ghost_duplicate(path)
    if ghost is not None:
        findings.append(ghost)

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return findings

    source_lines = _source_lines(text)
    if path.suffix.lower() == ".dart":
        dynamic_lines = [number for number, line in source_lines if re.search(r"\bdynamic\b", line)]
        if len(dynamic_lines) >= dynamic_threshold:
            findings.append(
                Finding(
                    "dynamic-overuse",
                    f"found dynamic on {len(dynamic_lines)} source lines (threshold {dynamic_threshold}); prefer typed models or document the boundary",
                    dynamic_lines[0],
                )
            )
    elif path.suffix.lower() in {".ts", ".tsx"}:
        for number, line in source_lines:
            if re.search(r"(?:\bas\s+any\b|:\s*any\b|<any>|any\[\])", line):
                findings.append(
                    Finding(
                        "explicit-any",
                        "explicit any weakens the type boundary; use unknown plus validation or add a narrow documented exception",
                        number,
                    )
                )
                if sum(item.code == "explicit-any" for item in findings) >= 5:
                    break

    for pattern, code, message in PLACEHOLDER_PATTERNS:
        for number, line in source_lines:
            if pattern.search(line):
                findings.append(Finding(code, message, number))
                break

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--dynamic-threshold", type=int, default=4)
    parser.add_argument("--strict", action="store_true", help="return non-zero when findings exist")
    args = parser.parse_args()

    path = args.path if args.path.is_absolute() else args.repo_root / args.path
    findings = scan_file(path.resolve(), dynamic_threshold=max(args.dynamic_threshold, 1))
    if findings:
        try:
            display_path = path.resolve().relative_to(args.repo_root.resolve())
        except ValueError:
            display_path = path.resolve()
        print(f"AI code anti-pattern review for {display_path.as_posix()}:")
        for finding in findings:
            print(f"- {finding.render()}")
        print("Resolve the finding or record why it is an intentional, reviewed exception.")
    return 1 if findings and args.strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
