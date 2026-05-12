#!/usr/bin/env python3
"""Build Knowledge Graph records from WBS and cross-instance task docs."""

from __future__ import annotations

import argparse
from pathlib import Path

from kg_index_common import (
    SourceRecord,
    add_common_args,
    finish,
    first_heading,
    github_blob_url,
    read_text,
    repo_relative,
)


WBS_GLOBS = [
    "docs/WBS*.md",
    "docs/BUSINESS_WBS*.md",
    "docs/cross-instance-prs/*.md",
]


def build_records(root: Path, limit: int) -> list[SourceRecord]:
    records: list[SourceRecord] = []
    seen: set[Path] = set()
    for pattern in WBS_GLOBS:
        for path in sorted(root.glob(pattern)):
            if len(records) >= limit:
                return records
            if path in seen or not path.is_file():
                continue
            seen.add(path)
            text = read_text(path)
            if not text.strip():
                continue
            relative = repo_relative(path, root)
            records.append(
                SourceRecord(
                    source_type="wbs",
                    source_id=relative,
                    title=first_heading(text, path.stem),
                    content=text,
                    source_url=github_blob_url(relative),
                    metadata={"path": relative, "source": "wbs-doc"},
                )
            )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    add_common_args(parser, default_output="wbs.jsonl")
    args = parser.parse_args()
    finish(build_records(Path(args.root), args.limit), args)


if __name__ == "__main__":
    main()
