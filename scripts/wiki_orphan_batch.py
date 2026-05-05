#!/usr/bin/env python3
"""wiki_orphan_batch.py — Top-N project_* orphans を MEMORY index へ batch wikilink 化.

Win版#132 part 142 / 2026-05-05.

knowledge_vault_lint.py の JSON 出力から `project_YYYYMMDD_*.md` orphan を上位 N 件抽出し、
それぞれの H1 / frontmatter description を要約として `| [[stem]] | summary |` 行を
appropriate な MEMORY index ファイルへ追記する。

- May 2026 entries → MEMORY.md
- Apr 2026 entries → MEMORY_202604.md
- それ以外 → MEMORY.md (catch-all)

zero-budget / dependency-free (= 標準ライブラリのみ).

usage:
  python scripts/wiki_orphan_batch.py \\
      --lint-json docs/knowledge-vault-lint/2026-05-05.json \\
      --top 50 \\
      [--memory-dir <dir>] \\
      [--marker "<!-- orphan-batch part 142 -->"] \\
      [--dry-run]

`--lint-json` を `auto` にすると今日の日付の最新 JSON を探す。

dogfood:
  - SECOND_BRAIN #4 (Lint → 自動 cleanup)
  - INDIE_DEV_VELOCITY #1 (Memory)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MEMORY_DIR = Path(
    "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory"
)
if not DEFAULT_MEMORY_DIR.exists():
    DEFAULT_MEMORY_DIR = REPO_ROOT / "memory"

H1 = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)
DESC = re.compile(r"^description:\s*(.+?)\s*$", re.MULTILINE)


def summarize(path: Path) -> str:
    """frontmatter description 優先 → H1 → filename stem."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return path.stem
    head = text[:2000]
    m = DESC.search(head)
    if m:
        return m.group(1).strip()[:300]
    h1 = H1.search(head)
    if h1:
        return h1.group(1).strip()[:300]
    return path.stem


def append_index(index_path: Path, marker: str, rows: list[str], dry_run: bool) -> int:
    """index 末尾に marker + rows を追記。同一 marker が既存なら何もしない。"""
    if not rows:
        return 0
    text = index_path.read_text(encoding="utf-8") if index_path.exists() else ""
    if marker in text:
        print(f"  skip {index_path.name}: marker already present")
        return 0
    block = "\n".join(rows)
    new_text = text.rstrip() + "\n\n" + marker + "\n" + block + "\n"
    if not dry_run:
        index_path.write_text(new_text, encoding="utf-8")
    return len(rows)


def resolve_lint_json(arg: str) -> Path:
    if arg == "auto":
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        candidates = sorted(
            (REPO_ROOT / "docs" / "knowledge-vault-lint").glob(f"{today}*.json"),
            reverse=True,
        )
        if not candidates:
            raise SystemExit(f"no lint JSON found for {today}")
        return candidates[0]
    return Path(arg)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--lint-json", default="auto", help='lint JSON path or "auto"')
    p.add_argument("--top", type=int, default=50)
    p.add_argument("--memory-dir", default=str(DEFAULT_MEMORY_DIR))
    p.add_argument(
        "--marker",
        default=f"<!-- orphan-batch {datetime.now(timezone.utc).strftime('%Y-%m-%d')} -->",
    )
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    lint_path = resolve_lint_json(args.lint_json)
    data = json.loads(lint_path.read_text(encoding="utf-8"))
    mem_dir = Path(args.memory_dir)

    project_orphans = sorted(
        [o for o in data["orphans"] if o.startswith("project_")],
        reverse=True,
    )[: args.top]

    may_rows: list[str] = []
    apr_rows: list[str] = []
    other_rows: list[str] = []

    for fname in project_orphans:
        fpath = mem_dir / fname
        if not fpath.exists():
            continue
        row = f"| [[{fpath.stem}]] | {summarize(fpath)} |"
        if fname.startswith("project_202605"):
            may_rows.append(row)
        elif fname.startswith("project_202604"):
            apr_rows.append(row)
        else:
            other_rows.append(row)

    print(f"lint JSON       : {lint_path.name}")
    print(f"top-{args.top} project orphans considered")
    print(f"  May 2026  : {len(may_rows)}")
    print(f"  Apr 2026  : {len(apr_rows)}")
    print(f"  other     : {len(other_rows)}")
    if args.dry_run:
        print("(dry-run) no files written")
        return 0

    written_main = append_index(
        mem_dir / "MEMORY.md", args.marker, may_rows + other_rows, args.dry_run
    )
    written_apr = append_index(
        mem_dir / "MEMORY_202604.md", args.marker, apr_rows, args.dry_run
    )
    print(f"MEMORY.md           += {written_main}")
    print(f"MEMORY_202604.md    += {written_apr}")
    print(f"total batched       : {written_main + written_apr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
