#!/usr/bin/env python3
"""Guard docs/GROWTH_STRATEGY_ROADMAP.md against destructive rewrites."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass


DEFAULT_PATH = "docs/GROWTH_STRATEGY_ROADMAP.md"
PLACEHOLDER_MARKERS = (
    "PLACEHOLDER_FULL_CONTENT",
    "TODO_FULL_CONTENT",
    "[[ROADMAP_CONTENT_PLACEHOLDER]]",
)


@dataclass(frozen=True)
class RoadmapStats:
    lines: int
    bytes: int
    placeholder_markers: tuple[str, ...]


@dataclass(frozen=True)
class RoadmapFinding:
    code: str
    message: str


def stats_for_text(text: str) -> RoadmapStats:
    markers = tuple(marker for marker in PLACEHOLDER_MARKERS if marker in text)
    return RoadmapStats(
        lines=len(text.splitlines()),
        bytes=len(text.encode("utf-8")),
        placeholder_markers=markers,
    )


def compare_roadmap_text(
    base_text: str,
    head_text: str,
    *,
    max_drop_ratio: float = 0.20,
    min_drop_lines: int = 100,
) -> list[RoadmapFinding]:
    base = stats_for_text(base_text)
    head = stats_for_text(head_text)
    findings: list[RoadmapFinding] = []

    if head.placeholder_markers:
        findings.append(
            RoadmapFinding(
                "placeholder",
                "ROADMAP contains placeholder marker(s): "
                + ", ".join(head.placeholder_markers),
            )
        )

    dropped_lines = base.lines - head.lines
    if base.lines > 0 and dropped_lines > 0:
        drop_ratio = dropped_lines / base.lines
        if dropped_lines >= min_drop_lines and drop_ratio > max_drop_ratio:
            findings.append(
                RoadmapFinding(
                    "line-drop",
                    (
                        "ROADMAP line count dropped from "
                        f"{base.lines} to {head.lines} "
                        f"({drop_ratio:.1%}, {dropped_lines} lines). "
                        "Use append-only edits or split/archive in a reviewed PR."
                    ),
                )
            )

    return findings


def git_show(ref: str, path: str) -> str | None:
    proc = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if proc.returncode == 0:
        return proc.stdout
    if "exists on disk, but not in" in proc.stderr or "Path" in proc.stderr:
        return None
    print(proc.stderr.strip(), file=sys.stderr)
    raise SystemExit(proc.returncode)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--head-ref", required=True)
    parser.add_argument("--path", default=DEFAULT_PATH)
    parser.add_argument("--max-drop-ratio", type=float, default=0.20)
    parser.add_argument("--min-drop-lines", type=int, default=100)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    base_text = git_show(args.base_ref, args.path)
    head_text = git_show(args.head_ref, args.path)

    if head_text is None:
        print(f"{args.path} is absent at head ref {args.head_ref}.")
        return 1
    if base_text is None:
        print(f"{args.path} is new at head ref {args.head_ref}; guard passed.")
        return 0

    base = stats_for_text(base_text)
    head = stats_for_text(head_text)
    print(
        f"{args.path}: base={base.lines} lines/{base.bytes} bytes, "
        f"head={head.lines} lines/{head.bytes} bytes"
    )

    findings = compare_roadmap_text(
        base_text,
        head_text,
        max_drop_ratio=args.max_drop_ratio,
        min_drop_lines=args.min_drop_lines,
    )
    if findings:
        print("ROADMAP append-only guard failed:")
        for finding in findings:
            print(f"- [{finding.code}] {finding.message}")
        return 1

    print("ROADMAP append-only guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
