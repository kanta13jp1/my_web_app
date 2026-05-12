#!/usr/bin/env python3
"""Build Knowledge Graph records from public docs markdown files."""

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


def build_records(root: Path, limit: int) -> list[SourceRecord]:
    docs_root = root / "docs"
    records: list[SourceRecord] = []
    if not docs_root.exists():
        return records
    for path in sorted(docs_root.rglob("*.md")):
        if len(records) >= limit:
            break
        relative = repo_relative(path, root)
        parts = set(path.parts)
        if ".git" in parts or "node_modules" in parts:
            continue
        text = read_text(path)
        if not text.strip():
            continue
        records.append(
            SourceRecord(
                source_type="doc",
                source_id=relative,
                title=first_heading(text, path.stem),
                content=text,
                source_url=github_blob_url(relative),
                metadata={"path": relative},
            )
        )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    add_common_args(parser, default_output="docs.jsonl")
    args = parser.parse_args()
    finish(build_records(Path(args.root), args.limit), args)


if __name__ == "__main__":
    main()
