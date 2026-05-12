#!/usr/bin/env python3
"""wiki_dup_h1_cleanup.py — duplicate H1 30 件 unique 化 helper.

Win版#132 part 142 / 2026-05-05.

knowledge_vault_lint.py の duplicate_titles 出力から H1 重複を解消する:

  Type A — same basename in different dirs:
    A1 archive: docs/archive/<file> → H1 += " [Archive]"
    A2 done   : cross-instance-prs/done/<file> → H1 += " [Done]"
    A3 blog   : docs/blog/{cross-post,github-pages,zenn}/<file> → H1 += " [<dir>]"
    A4 generic: keep first, append " [<parent-dir>]" to rest

  Type B — generic template H1 across files:
    H1 += " — <filename-stem>"

dry-run 対応 / backup 自動作成 / dependency-free。
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

# Win コンソールの cp932 で日本語 H1 出力を救済 (= em dash 等で UnicodeEncodeError 回避)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent.parent
H1_LINE = re.compile(r"^(#\s+)(.+?)\s*$", re.MULTILINE)

# 「canonical」と判定する path keyword (= H1 patch しない)
CANONICAL_HINTS = (
    "blog-drafts",  # オリジナル draft
    "user-docs",    # active user doc
    "roadmaps",     # active roadmap (vs archive/roadmaps)
    "technical",    # active (vs archive/technical)
)
# 「重複側」と判定する path keyword + suffix
NONCANONICAL_RULES: list[tuple[str, str]] = [
    ("docs/archive/", "[Archive]"),
    ("cross-instance-prs/done/", "[Done]"),
    ("blog/cross-post/", "[Cross-Post]"),
    ("blog/github-pages/", "[GitHub Pages]"),
    ("blog/zenn/", "[Zenn]"),
    ("competitor-reports/", "[Competitor Report]"),
]


def normalize_posix(p: Path) -> str:
    return p.as_posix().lower()


def pick_suffix(path: Path) -> str | None:
    pp = normalize_posix(path)
    for keyword, suffix in NONCANONICAL_RULES:
        if keyword in pp:
            return suffix
    return None


def patch_h1(path: Path, suffix: str, dry_run: bool) -> bool:
    """First H1 に suffix を追記 (= 既に suffix が付いていたら skip)."""
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    m = H1_LINE.search(text)
    if not m:
        return False
    current_h1 = m.group(2).strip()
    if suffix.lower() in current_h1.lower():
        return False  # already patched
    new_h1 = f"{current_h1} {suffix}"
    new_text = text[: m.start(2)] + new_h1 + text[m.end(2):]
    if not dry_run:
        backup = path.with_suffix(path.suffix + ".backup_part142_dup_cleanup")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(new_text, encoding="utf-8")
    return True


def resolve_paths(name: str, search_roots: list[Path]) -> list[Path]:
    found: list[Path] = []
    for root in search_roots:
        if not root.exists():
            continue
        for p in root.rglob(name):
            if any(part in {".git", "node_modules", "build", "dist",
                            "knowledge-vault-lint"} for part in p.parts):
                continue
            found.append(p)
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lint-json", required=True)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data = json.loads(Path(args.lint_json).read_text(encoding="utf-8"))
    dup_groups: dict[str, list[str]] = data["duplicate_titles"]

    search_roots = [REPO_ROOT / "docs", REPO_ROOT / "lib", REPO_ROOT / "scripts"]

    type_a_patched = 0  # path-rule based
    type_b_patched = 0  # filename-stem based
    skipped = 0

    for title, file_names in dup_groups.items():
        # ユニーク basename 集計 (= type 判定)
        unique_names = set(file_names)
        if len(unique_names) == 1:
            # Type A: 同名 file が複数 path にある
            name = file_names[0]
            paths = resolve_paths(name, search_roots)
            if len(paths) < 2:
                continue
            # Suffix 適用 candidate を抽出
            for p in paths:
                suffix = pick_suffix(p)
                if suffix is None:
                    continue
                if patch_h1(p, suffix, args.dry_run):
                    type_a_patched += 1
                    print(f"  [A] {p.relative_to(REPO_ROOT)}: H1 += {suffix}")
                else:
                    skipped += 1
        else:
            # Type B: 異 basename / 同 H1 (= template H1)
            for name in unique_names:
                paths = resolve_paths(name, search_roots)
                for p in paths:
                    stem = p.stem
                    suffix = f"— {stem}"
                    if patch_h1(p, suffix, args.dry_run):
                        type_b_patched += 1
                        print(f"  [B] {p.relative_to(REPO_ROOT)}: H1 += {suffix}")
                    else:
                        skipped += 1

    print()
    print(f"Type A (path suffix)    : {type_a_patched} files patched")
    print(f"Type B (stem suffix)    : {type_b_patched} files patched")
    print(f"skipped (already / noop): {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
