#!/usr/bin/env python3
"""Build Knowledge Graph records from curated memory/vault notes."""

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


TEXT_EXTENSIONS = {".md", ".markdown", ".txt", ".json", ".jsonl"}


def build_records(root: Path, limit: int) -> list[SourceRecord]:
    vault = root / "memory" / "vault"
    records: list[SourceRecord] = []
    if not vault.exists():
        return records
    for path in sorted(vault.rglob("*")):
        if len(records) >= limit:
            break
        if not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        text = read_text(path)
        if not text.strip():
            continue
        relative = repo_relative(path, root)
        records.append(
            SourceRecord(
                source_type="memory",
                source_id=relative,
                title=first_heading(text, path.stem),
                content=text,
                source_url=github_blob_url(relative),
                metadata={"path": relative, "source": "memory-vault"},
            )
        )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    add_common_args(parser, default_output="memory.jsonl")
    args = parser.parse_args()
    finish(build_records(Path(args.root), args.limit), args)


if __name__ == "__main__":
    main()
