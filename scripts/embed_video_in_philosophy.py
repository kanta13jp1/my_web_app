#!/usr/bin/env python3
"""Auto-embed a new _Video entry into lib/pages/philosophy_page.dart.

Used by .github/workflows/notebooklm-video-pipeline.yml Step 8 to close the
NotebookLM → YouTube → Flutter embed loop without manual editing.

Usage:
    python scripts/embed_video_in_philosophy.py \
        --video-id Zclp_zK9cYM \
        --label "番外: AnthropicのClaude Apps 解説 (D variant)" \
        --duration 7:10 \
        --description "NotebookLM Deep Research + intro/outro + ..."

    # Dry-run (prints diff without writing):
    python scripts/embed_video_in_philosophy.py --video-id ... --dry-run
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DEFAULT_FILE = Path("lib/pages/philosophy_page.dart")
ARRAY_OPEN = "const _videos = ["
ARRAY_CLOSE = "];"
VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{10,12}$")
DURATION_PATTERN = re.compile(r"^\d{1,2}:\d{2}$")


def dart_string(value: str) -> str:
    """Wrap a python string as a Dart single-quoted literal, escaping quotes."""
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def split_description(description: str, prefix_indent: str = "        ", max_len: int = 90) -> str:
    """Split a long description across multiple Dart string literals joined by space.

    Mirrors existing entries (e.g. video #1) where description spans 2-3 lines using
    implicit string concatenation:
        description: 'first chunk '
            'second chunk',
    """
    if len(description) + len(prefix_indent) <= max_len:
        return dart_string(description)

    chunks: list[str] = []
    remaining = description
    while remaining:
        if len(remaining) <= max_len:
            chunks.append(remaining)
            break
        cut = remaining.rfind(" ", 0, max_len)
        if cut <= 0:
            cut = max_len
        chunks.append(remaining[:cut].rstrip())
        remaining = remaining[cut:].lstrip()

    parts = [dart_string(chunks[0] + " ")]
    for c in chunks[1:-1]:
        parts.append(dart_string(c + " "))
    parts.append(dart_string(chunks[-1]))
    joiner = f"\n{prefix_indent}"
    return joiner.join(parts)


def render_entry(video_id: str, label: str, duration: str, description: str) -> str:
    desc_dart = split_description(description)
    return (
        "  _Video(\n"
        f"    id: {dart_string(video_id)},\n"
        f"    label: {dart_string(label)},\n"
        f"    duration: {dart_string(duration)},\n"
        f"    description: {desc_dart},\n"
        "  ),\n"
    )


def embed(file_text: str, entry: str, video_id: str) -> str:
    if f"id: '{video_id}'" in file_text:
        raise SystemExit(
            f"video id '{video_id}' already present in _videos array — refusing to duplicate."
        )

    open_idx = file_text.find(ARRAY_OPEN)
    if open_idx < 0:
        raise SystemExit(f"could not find '{ARRAY_OPEN}' in file")

    close_idx = file_text.find(ARRAY_CLOSE, open_idx)
    if close_idx < 0:
        raise SystemExit("could not find closing '];' for _videos array")

    return file_text[:close_idx] + entry + file_text[close_idx:]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Embed a _Video entry into philosophy_page.dart")
    p.add_argument("--video-id", required=True, help="YouTube video ID (10-12 chars)")
    p.add_argument("--label", required=True, help="Display label, e.g. '番外: ... (D variant)'")
    p.add_argument("--duration", required=True, help="Duration as M:SS or MM:SS")
    p.add_argument("--description", required=True, help="Description shown under the player")
    p.add_argument("--file", default=str(DEFAULT_FILE), help="Target Dart file (default: %(default)s)")
    p.add_argument("--dry-run", action="store_true", help="Print result to stdout, do not write")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if not VIDEO_ID_PATTERN.match(args.video_id):
        print(f"invalid --video-id '{args.video_id}' (expected 10-12 [A-Za-z0-9_-])", file=sys.stderr)
        return 2
    if not DURATION_PATTERN.match(args.duration):
        print(f"invalid --duration '{args.duration}' (expected M:SS or MM:SS)", file=sys.stderr)
        return 2

    target = Path(args.file)
    if not target.exists():
        print(f"file not found: {target}", file=sys.stderr)
        return 2

    text = target.read_text(encoding="utf-8")
    entry = render_entry(args.video_id, args.label, args.duration, args.description)
    new_text = embed(text, entry, args.video_id)

    if args.dry_run:
        sys.stdout.write(entry)
        print(f"\n[dry-run] would insert above into {target}", file=sys.stderr)
        return 0

    target.write_text(new_text, encoding="utf-8")
    print(f"embedded video '{args.video_id}' into {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
