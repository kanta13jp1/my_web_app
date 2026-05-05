#!/usr/bin/env python3
"""knowledge_vault_lint.py — memory/ + docs/ Lint (Win版#132 part 105 / 2026-05-01).

WBS Issues:
  - #976 Knowledge Vault Lint と index.md/log.md 自動メンテナンス
  - #1173 ナレッジベース 自動健康診断 (Lint) と孤立ページ検出機能

軸 dogfood:
  - SECOND_BRAIN #4 (定期 Lint + 孤児統合)
  - INDIE_DEV_VELOCITY #1 (Neuroscience-Inspired Memory)

検出項目:
  1. orphan files (= [[link]] 参照なし)
  2. broken backlinks (= [[link]] が存在 file 指していない)
  3. duplicate titles (= 同一 H1 が複数 file に)
  4. missing index entry (= file が memory/MEMORY.md に未登録)
  5. log.md 漏れ (= 重要 file が log.md に未記載)

output:
  - docs/knowledge-vault-lint/<YYYY-MM-DD>.md (= human readable)
  - JSON option (= hook integration)

= zero-budget で動く (= 外部 API 不要 / Markdown 解析のみ)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_DIR = Path("C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory")
DOCS_DIR = REPO_ROOT / "docs"

# memory dir が存在しなければ repo root の memory/ を fallback (= dev 環境)
if not MEMORY_DIR.exists():
    MEMORY_DIR = REPO_ROOT / "memory"


def collect_md_files(roots: list[Path]) -> list[Path]:
    """配下の *.md を再帰収集."""
    out: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for p in root.rglob("*.md"):
            # node_modules / .git 等除外
            # knowledge-vault-lint は本 script 自身の出力 (= [[xxx]] 例文を含む) で
            # scan すると大量 self-reference noise が出るため除外。
            if any(part in {".git", "node_modules", "build", "dist",
                            "knowledge-vault-lint"} for part in p.parts):
                continue
            if "knowledge-vault-lint" in p.parts:
                continue
            out.append(p)
    return out


WIKILINK = re.compile(r"\[\[([^\[\]|]+?)(?:\|[^\[\]]+?)?\]\]")
H1 = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)
PLACEHOLDER_LINKS = {
    "",
    "<file>",
    "file",
    "<related file>",
    "<related file 1>",
    "<related file 2>",
    "<this file>",
    ":space:",
    "file1",
    "file2",
    "file_name",
    "file_p",
    "file_q",
    "wikilink",
    "<関連 file 1>",
    "<関連 file 2>",
}


def normalize_link(link: str) -> str:
    """Return the comparable stem for an Obsidian-style wikilink."""
    link = link.strip().strip("/")
    link = link.split("#", 1)[0].strip()
    link = link.replace("\\", "/")
    return Path(link).stem if "/" in link else Path(link).stem


def is_placeholder_link(link: str) -> bool:
    raw = link.strip().lower()
    normalized = normalize_link(link).strip().lower()
    return raw in PLACEHOLDER_LINKS or normalized in PLACEHOLDER_LINKS


def calculate_health(total_files: int, memory_files_count: int, orphans_count: int,
                     broken_count: int, duplicate_count: int,
                     missing_index_count: int) -> int:
    """Scale health by vault size so large vaults do not stay pinned at 0."""
    total = max(1, total_files)
    indexable_memory = max(1, memory_files_count - 2)
    orphan_penalty = min(40.0, (orphans_count / total) * 40.0)
    broken_penalty = min(25.0, (broken_count / total) * 300.0)
    duplicate_penalty = min(15.0, duplicate_count * 0.5)
    missing_index_penalty = min(20.0, (missing_index_count / indexable_memory) * 25.0)
    health = 100 - (
        orphan_penalty + broken_penalty + duplicate_penalty + missing_index_penalty
    )
    return max(0, round(health))


def extract_links(text: str) -> set[str]:
    return {m.group(1).strip() for m in WIKILINK.finditer(text)}


def extract_h1(text: str) -> str | None:
    m = H1.search(text)
    return m.group(1).strip() if m else None


def detect_orphans(files: list[Path]) -> list[Path]:
    """他 file から [[link]] 参照されていない file."""
    referenced: set[str] = set()
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for link in extract_links(text):
            # link は basename (拡張子有無両方) を許容
            referenced.add(link)
            referenced.add(link + ".md")
            stem = Path(link).stem
            if stem:
                referenced.add(stem)

    orphans: list[Path] = []
    for f in files:
        # MEMORY.md / log.md / 設計 doc は orphan 扱いしない (= top-level reference)
        if f.name in {"MEMORY.md", "log.md", "README.md", "DESIGN.md",
                      "PHILOSOPHY.md", "CLAUDE.md"}:
            continue
        if f.suffix != ".md":
            continue
        if f.name not in referenced and f.stem not in referenced:
            orphans.append(f)
    return orphans


def detect_broken_links(files: list[Path]) -> list[tuple[Path, str]]:
    """[[link]] が指す file が存在しない."""
    file_names: set[str] = set()
    file_stems: set[str] = set()
    file_rel_stems: set[str] = set()
    for f in files:
        file_names.add(f.name)
        file_stems.add(f.stem)
        try:
            file_rel_stems.add(f.relative_to(REPO_ROOT).with_suffix("").as_posix())
        except ValueError:
            file_rel_stems.add(f.with_suffix("").as_posix())

    broken: list[tuple[Path, str]] = []
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for link in extract_links(text):
            if is_placeholder_link(link):
                continue
            target = normalize_link(link)
            rel_target = link.strip().replace("\\", "/").removesuffix(".md")
            if target in file_stems or link in file_names or rel_target in file_rel_stems:
                continue
            # 部分 match (= "memory/<file>" 形式) 許容
            if any(target in s for s in file_stems):
                continue
            broken.append((f, link))
    return broken


def detect_duplicate_titles(files: list[Path]) -> dict[str, list[Path]]:
    """同一 H1 を持つ file 群."""
    title_to_files: dict[str, list[Path]] = defaultdict(list)
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        h1 = extract_h1(text)
        if h1:
            # part 番号などを除去した正規化 title で grouping
            normalized = re.sub(r"\s+", " ", h1.strip().lower())
            title_to_files[normalized].append(f)
    return {t: fs for t, fs in title_to_files.items() if len(fs) > 1}


def detect_missing_index_entries(memory_files: list[Path], index_path: Path) -> list[Path]:
    """memory/*.md のうち MEMORY*.md (= 月次分割含む) に未登録のもの."""
    # MEMORY.md + MEMORY_<period>.md を全部読んで連結 (= [MEMORY-DECAY] 200+ 分割対応)
    memory_dir = index_path.parent
    idx_texts: list[str] = []
    if memory_dir.exists():
        for idx in sorted(memory_dir.glob("MEMORY*.md")):
            try:
                idx_texts.append(idx.read_text(encoding="utf-8", errors="replace"))
            except OSError:
                continue
    if not idx_texts:
        return []
    idx_text = "\n".join(idx_texts)
    missing: list[Path] = []
    for f in memory_files:
        if f.name in {"MEMORY.md", "log.md"} or f.name.startswith("MEMORY_"):
            continue
        if f.name not in idx_text and f.stem not in idx_text:
            missing.append(f)
    return missing


def render_markdown(now: datetime, memory_files: list[Path], docs_files: list[Path],
                    orphans: list[Path], broken: list[tuple[Path, str]],
                    dup_titles: dict[str, list[Path]],
                    missing_idx: list[Path]) -> str:
    lines: list[str] = []
    lines.append(f"# Knowledge Vault Lint — {now.strftime('%Y-%m-%d %H:%M UTC')}\n")
    lines.append("")
    lines.append(
        "> Win版#132 part 105 / Issues #976 + #1173 dogfood / "
        "SECOND_BRAIN #4 (定期 Lint) + INDIE #1 (Memory) 実装.\n"
    )
    lines.append("")
    lines.append(f"**memory files**: {len(memory_files)} / **docs files**: {len(docs_files)} / total: {len(memory_files) + len(docs_files)}")
    lines.append("")

    # Health Score 算出 (= 簡易 / 100 - issue count)
    total_files = len(memory_files) + len(docs_files)
    health = calculate_health(total_files, len(memory_files), len(orphans),
                              len(broken), len(dup_titles), len(missing_idx))
    lines.append(f"## Health Score: **{health}/100**\n")
    lines.append("")
    lines.append(f"- orphan files: {len(orphans)}")
    lines.append(f"- broken links: {len(broken)}")
    lines.append(f"- duplicate titles: {len(dup_titles)}")
    lines.append(f"- missing index entries: {len(missing_idx)}")
    lines.append("- scoring: size-normalized weighted penalties")
    lines.append("")

    lines.append("## Orphan files (= 他 file から [[link]] 参照なし)")
    lines.append("")
    if orphans:
        for f in orphans[:30]:
            lines.append(f"- `{f.relative_to(REPO_ROOT) if f.is_relative_to(REPO_ROOT) else f.name}`")
        if len(orphans) > 30:
            lines.append(f"- ... ({len(orphans) - 30} more)")
    else:
        lines.append("- (none)")
    lines.append("")

    lines.append("## Broken links (= [[link]] target 不在)")
    lines.append("")
    if broken:
        for f, link in broken[:30]:
            rel = f.relative_to(REPO_ROOT) if f.is_relative_to(REPO_ROOT) else f.name
            lines.append(f"- `{rel}` → `[[{link}]]`")
        if len(broken) > 30:
            lines.append(f"- ... ({len(broken) - 30} more)")
    else:
        lines.append("- (none)")
    lines.append("")

    lines.append("## Duplicate H1 titles")
    lines.append("")
    if dup_titles:
        for title, fs in list(dup_titles.items())[:15]:
            lines.append(f"- **{title}** ({len(fs)} files)")
            for f in fs[:5]:
                rel = f.relative_to(REPO_ROOT) if f.is_relative_to(REPO_ROOT) else f.name
                lines.append(f"  - `{rel}`")
    else:
        lines.append("- (none)")
    lines.append("")

    lines.append("## Missing index entries (= memory/MEMORY.md 未登録)")
    lines.append("")
    if missing_idx:
        for f in missing_idx[:30]:
            lines.append(f"- `{f.name}`")
        if len(missing_idx) > 30:
            lines.append(f"- ... ({len(missing_idx) - 30} more)")
    else:
        lines.append("- (none)")
    lines.append("")

    lines.append("## 推奨 actions")
    lines.append("")
    if health >= 90:
        lines.append("- ✅ Knowledge Vault は健全. 通常運用 OK.")
    elif health >= 70:
        lines.append("- 🟡 軽微な issue あり. 月次 maintenance で fix.")
    else:
        lines.append("- ⚠️ 大量 issue あり. 早期 cleanup 推奨.")
        lines.append("- orphan は MEMORY.md / log.md に登録 or削除")
        lines.append("- broken link は target 名 typo / file 移動を確認")
        lines.append("- duplicate title は part 番号など unique 化")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*auto-generated by `scripts/knowledge_vault_lint.py`*")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--memory-dir", default=str(MEMORY_DIR))
    p.add_argument("--output", default="")
    p.add_argument("--json-out", default="")
    args = p.parse_args()

    now = datetime.now(timezone.utc)
    memory_dir = Path(args.memory_dir)
    memory_files = collect_md_files([memory_dir]) if memory_dir.exists() else []
    docs_files = collect_md_files([DOCS_DIR])
    all_files = memory_files + docs_files

    orphans = detect_orphans(all_files)
    broken = detect_broken_links(all_files)
    dup_titles = detect_duplicate_titles(all_files)
    missing_idx = detect_missing_index_entries(memory_files, memory_dir / "MEMORY.md")
    health = calculate_health(len(all_files), len(memory_files), len(orphans),
                              len(broken), len(dup_titles), len(missing_idx))

    if args.json_out:
        out_json = REPO_ROOT / args.json_out
        out_json.parent.mkdir(parents=True, exist_ok=True)
        out_json.write_text(json.dumps({
            "timestamp": now.isoformat(),
            "memory_files": len(memory_files),
            "docs_files": len(docs_files),
            "health": health,
            "orphans": [str(f.name) for f in orphans],
            "broken_links": [(str(f.name), link) for f, link in broken],
            "duplicate_titles": {t: [str(x.name) for x in fs] for t, fs in dup_titles.items()},
            "missing_index": [str(f.name) for f in missing_idx],
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"wrote {out_json}")

    out_path = REPO_ROOT / args.output if args.output else (
        REPO_ROOT / "docs" / "knowledge-vault-lint" /
        f"{now.strftime('%Y-%m-%d')}.md"
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    md = render_markdown(now, memory_files, docs_files, orphans, broken,
                        dup_titles, missing_idx)
    out_path.write_text(md, encoding="utf-8")
    print(f"wrote {out_path}")
    print(f"health: {health}/100")
    return 0 if health >= 90 else (1 if health >= 70 else 2)


if __name__ == "__main__":
    sys.exit(main())
