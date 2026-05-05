#!/usr/bin/env python3
"""Convert memory index table filename cells into Obsidian wikilinks.

This handles older rows such as:

  | feedback_success_20260411_daily.md | summary |

and converts them to:

  | [[feedback_success_20260411_daily]] | summary |

The goal is to make existing MEMORY indexes visible in Obsidian graph view
without editing the atomic notes themselves.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MEMORY_DIR = Path(
    "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory"
)
if not DEFAULT_MEMORY_DIR.exists():
    DEFAULT_MEMORY_DIR = REPO_ROOT / "memory"

PLAIN_MD_CELL = re.compile(
    r"^(\|\s*)(?!\[\[)(?!\*\*)([A-Za-z0-9][A-Za-z0-9_.-]+)\.md(\s*\|)",
    re.MULTILINE,
)
BOLD_MD_CELL = re.compile(
    r"^(\|\s*)\*\*([A-Za-z0-9][A-Za-z0-9_.-]+)\.md\*\*(\s*\|)",
    re.MULTILINE,
)


def migrate_file(path: Path, dry_run: bool) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    converted = 0

    def plain_repl(match: re.Match[str]) -> str:
        nonlocal converted
        converted += 1
        return f"{match.group(1)}[[{match.group(2)}]]{match.group(3)}"

    def bold_repl(match: re.Match[str]) -> str:
        nonlocal converted
        converted += 1
        return f"{match.group(1)}[[{match.group(2)}]]{match.group(3)}"

    new_text = PLAIN_MD_CELL.sub(plain_repl, text)
    new_text = BOLD_MD_CELL.sub(bold_repl, new_text)
    if converted and not dry_run:
        path.write_text(new_text, encoding="utf-8")
    return converted


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-dir", default=str(DEFAULT_MEMORY_DIR))
    parser.add_argument(
        "--indexes",
        nargs="*",
        default=["MEMORY.md", "MEMORY_202604.md"],
        help="Index files inside --memory-dir to migrate.",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    memory_dir = Path(args.memory_dir)
    total = 0
    for index_name in args.indexes:
        path = memory_dir / index_name
        if not path.exists():
            print(f"skip missing: {path}")
            continue
        count = migrate_file(path, args.dry_run)
        total += count
        print(f"{index_name}: {count}")
    print(f"total: {total}")
    if args.dry_run:
        print("(dry-run) no files written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
