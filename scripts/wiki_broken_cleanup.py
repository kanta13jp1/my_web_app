#!/usr/bin/env python3
"""wiki_broken_cleanup.py — broken `[[wikilink]]` 真陽性 cleanup helper.

Win版#132 part 142 / 2026-05-05.

knowledge_vault_lint.py の broken_links 出力 (= 真陽性) を 4 カテゴリに分けて
backtick 化する (= [[xxx]] → `xxx` で wikilink 解析対象外にする) helper。

Categories:
  A. dead memory file refs (= file 不在の [[stem]] / MEMORY.md / log.md 内)
  B. placeholder example refs (= [[file]] / [[<this file>]] / [[wikilink]] 等)
  C. repo path refs (= [[scripts/foo.py]] / [[lib/.../foo.dart]])

dry-run 対応 / 既存 backup 上書き禁止 / dependency-free。

dogfood:
  - SECOND_BRAIN #4 (Lint → 自動 cleanup)
  - INDIE_DEV_VELOCITY #1 (Memory)
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MEMORY_DIR = Path(
    "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory"
)
if not DEFAULT_MEMORY_DIR.exists():
    DEFAULT_MEMORY_DIR = REPO_ROOT / "memory"

PLACEHOLDER_PAT = re.compile(
    r"\[\[("
    r"file|file_name|file_p|file_q|file1|file2|filename|wikilink"
    r"|<file>|<this file>|memory/<file>\.md|:space:"
    r"|<[^>\[\]]+>"
    r")\]\]"
)
REPO_PATH_PAT = re.compile(
    r"\[\[((?:scripts|lib|supabase|docs|web|test|memory)/[^\[\]\|]+)\]\]"
)
GENERIC_WIKI = re.compile(r"\[\[([^\[\]\|]+?)\]\]")


def patch_dead_refs(text: str, dead_stems: set[str]) -> tuple[str, int]:
    count = 0

    def sub(m: re.Match[str]) -> str:
        nonlocal count
        body = m.group(1).strip()
        clean = body[:-3] if body.endswith(".md") else body
        if clean in dead_stems:
            count += 1
            return f"`{body}`"
        return m.group(0)

    return GENERIC_WIKI.sub(sub, text), count


def patch_placeholder_refs(text: str) -> tuple[str, int]:
    count = 0

    def sub(m: re.Match[str]) -> str:
        nonlocal count
        count += 1
        return f"`{m.group(1)}`"

    return PLACEHOLDER_PAT.sub(sub, text), count


def patch_repo_path_refs(text: str) -> tuple[str, int]:
    count = 0

    def sub(m: re.Match[str]) -> str:
        nonlocal count
        count += 1
        return f"`{m.group(1)}`"

    return REPO_PATH_PAT.sub(sub, text), count


def collect_dead_stems(broken: list[tuple[str, str]], existing_stems: set[str]) -> set[str]:
    """broken_links list から file 不在 = 真 dead な stem を抽出."""
    dead: set[str] = set()
    for _src, link in broken:
        body = link.strip()
        clean = body[:-3] if body.endswith(".md") else body
        # placeholder / repo path / 既存 stem 除外
        if PLACEHOLDER_PAT.fullmatch(f"[[{body}]]"):
            continue
        if REPO_PATH_PAT.fullmatch(f"[[{body}]]"):
            continue
        if clean in existing_stems:
            continue
        dead.add(clean)
    return dead


def process_file(
    path: Path, dead_stems: set[str], dry_run: bool
) -> dict:
    if not path.exists():
        return {"status": "missing"}
    original = path.read_text(encoding="utf-8")
    text = original
    counts = {"dead": 0, "placeholder": 0, "repo_path": 0}
    text, counts["dead"] = patch_dead_refs(text, dead_stems)
    text, counts["placeholder"] = patch_placeholder_refs(text)
    text, counts["repo_path"] = patch_repo_path_refs(text)
    if text == original:
        return {"status": "noop", "counts": counts}
    if not dry_run:
        backup = path.with_suffix(path.suffix + ".backup_part142_broken_cleanup")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(text, encoding="utf-8")
    return {"status": "patched", "counts": counts}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--lint-json", required=True)
    p.add_argument("--memory-dir", default=str(DEFAULT_MEMORY_DIR))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    data = json.loads(Path(args.lint_json).read_text(encoding="utf-8"))
    mem_dir = Path(args.memory_dir)

    # 全 md file の stem set (= 既存 file / dead 判定の基準)
    existing_stems: set[str] = set()
    for root in [mem_dir, REPO_ROOT / "docs"]:
        if not root.exists():
            continue
        for f in root.rglob("*.md"):
            if any(part in {".git", "node_modules", "build", "dist",
                            "knowledge-vault-lint"} for part in f.parts):
                continue
            existing_stems.add(f.stem)

    dead_stems = collect_dead_stems(data["broken_links"], existing_stems)

    # broken link source file 一覧から target を抽出
    src_names: set[str] = {f for f, _l in data["broken_links"]}

    candidates: list[Path] = []
    for name in src_names:
        # mem dir 直下 + sub dir + repo docs
        for root in [mem_dir, REPO_ROOT / "docs"]:
            if not root.exists():
                continue
            for f in root.rglob(name):
                if any(part in {".git", "node_modules", "build", "dist",
                                "knowledge-vault-lint"} for part in f.parts):
                    continue
                candidates.append(f)

    # uniquify (resolved path)
    seen: set[Path] = set()
    unique: list[Path] = []
    for f in candidates:
        rp = f.resolve()
        if rp in seen:
            continue
        seen.add(rp)
        unique.append(f)

    print(f"dead stems detected   : {len(dead_stems)}")
    print(f"candidate files       : {len(unique)}")
    print()

    total = {"dead": 0, "placeholder": 0, "repo_path": 0}
    patched_files = 0
    for f in unique:
        result = process_file(f, dead_stems, args.dry_run)
        if result["status"] == "patched":
            patched_files += 1
            for k, v in result["counts"].items():
                total[k] += v
            tag = "DRY" if args.dry_run else "PATCH"
            try:
                rel = f.relative_to(REPO_ROOT)
            except ValueError:
                rel = f.name
            print(f"  [{tag}] {rel}: {result['counts']}")

    print()
    print(f"files patched : {patched_files}")
    print(f"replacements  : {total}")
    print(f"total fixes   : {sum(total.values())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
