#!/usr/bin/env python3
"""Build Knowledge Graph records from NotebookLM intake artifacts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from kg_index_common import (
    SourceRecord,
    add_common_args,
    finish,
    first_heading,
    github_blob_url,
    read_text,
    repo_relative,
)


NOTEBOOK_ID = "54b6f2f2-6831-4376-b2dd-99a1a4bf90ec"
TEXT_EXTENSIONS = {".md", ".markdown", ".txt", ".json", ".jsonl"}


def json_to_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        parts: list[str] = []
        for key in ("title", "summary", "body", "content", "text"):
            item = value.get(key)
            if isinstance(item, str):
                parts.append(item)
        if parts:
            return "\n\n".join(parts)
    if isinstance(value, list):
        return "\n".join(json_to_text(item) for item in value)
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def read_artifact_text(path: Path) -> str:
    if path.suffix.lower() == ".json":
        return json_to_text(json.loads(read_text(path)))
    if path.suffix.lower() == ".jsonl":
        parts: list[str] = []
        for line in read_text(path).splitlines():
            if not line.strip():
                continue
            try:
                parts.append(json_to_text(json.loads(line)))
            except json.JSONDecodeError:
                parts.append(line)
        return "\n".join(parts)
    return read_text(path)


def build_records(root: Path, limit: int, notebook_id: str) -> list[SourceRecord]:
    intake = root / "docs" / "notebooklm-intake"
    records: list[SourceRecord] = []
    if not intake.exists():
        return records
    for path in sorted(intake.rglob("*")):
        if len(records) >= limit:
            break
        if not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        text = read_artifact_text(path)
        if not text.strip():
            continue
        relative = repo_relative(path, root)
        records.append(
            SourceRecord(
                source_type="notebooklm",
                source_id=f"{notebook_id}:{relative}",
                title=first_heading(text, path.stem),
                content=text,
                source_url=github_blob_url(relative),
                metadata={
                    "path": relative,
                    "notebook_id": notebook_id,
                    "source": "notebooklm-intake",
                },
            )
        )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--notebook-id", default=NOTEBOOK_ID)
    add_common_args(parser, default_output="notebooklm.jsonl")
    args = parser.parse_args()
    finish(build_records(Path(args.root), args.limit, args.notebook_id), args)


if __name__ == "__main__":
    main()
