#!/usr/bin/env python3
"""Karpathy Compile cycle — raw layer から wiki layer (= concepts + INDEX) を自動生成.

Win版#132 part 132 (2026-05-04) — Issue #1976 着地.
part 128 で識別した Karpathy 4 サイクル の唯一の gap (= Compile) を補完.

Karpathy 3 層 + 4 サイクルの自分株式会社 dogfood map:
- Layer 1 raw/   : memory/ + docs/competitor-reports/ + docs/cs-notes/ + NotebookLM list
- Layer 2 wiki/  : docs/ 12 軸 principle docs + docs/concepts/ + docs/INDEX.md
- Layer 3 schema : CLAUDE.md + ~/.claude/hooks/inject-rules.txt
- Cycle 1 Ingest : scripts/memory_ingest.py (part 111)
- Cycle 2 Compile: 本 script (part 132 / NEW)
- Cycle 3 Query  : notebooklm CLI
- Cycle 4 Lint   : scripts/knowledge_vault_lint.py (part 105)

設計:
- dependency-free (stdlib + subprocess for gh/notebooklm CLI)
- 概念抽出 = 名詞 / 専門用語 frequency (= Counter)
- 概念ページ生成 threshold = 2+ source 言及 (Karpathy 推奨)
- 概念名 = ケバブケース (= active-inference.md / lower-case-hyphen)
- 既存ファイルの上書き禁止 (= 人間編集された docs/* は触らない)
- 出力先 = docs/concepts/_compile_*.md (= prefix 付きで人間編集と分離)

Usage:
    PYTHONUTF8=1 python scripts/wiki_compile.py             # dry-run / plan
    PYTHONUTF8=1 python scripts/wiki_compile.py --apply     # write files
    PYTHONUTF8=1 python scripts/wiki_compile.py --days 30 --min-sources 3
    PYTHONUTF8=1 python scripts/wiki_compile.py --json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable


# ──────────────────────────────────────────────────────────────────────
# Paths + defaults
# ──────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_SOURCES = [
    ("memory", "memory/project_*.md"),
    ("competitor", "docs/competitor-reports/*.md"),
    ("cs-notes", "docs/cs-notes/*.md"),
    ("incident", "docs/incident-reports/*.md"),
    ("daily-report", "docs/daily-reports/*.md"),
]
WIKI_DIR = REPO_ROOT / "docs" / "concepts"
INDEX_FILE = REPO_ROOT / "docs" / "INDEX.md"

# 概念抽出: カタカナ複合語 / 英数字専門語 / 漢字 2+ chars をターゲット
RE_KATAKANA = re.compile(r"[゠-ヿーー]{4,30}")
RE_ENGLISH_TERM = re.compile(r"[A-Z][A-Za-z0-9_+\-]{2,30}\b|[a-z][a-z0-9_]{4,30}\.[a-z0-9_]{2,15}")
RE_KANJI_PHRASE = re.compile(r"[一-鿿]{3,12}")
RE_BULLET = re.compile(r"^[\s\-\*\d\.\)]*")
RE_CODE_FENCE = re.compile(r"^```")
RE_FRONTMATTER = re.compile(r"^---\s*$")

# 概念抽出の除外語 (= 一般語 / 過去 emit ノイズ)
STOPWORDS = {
    # 日本語一般
    "について", "ため", "こと", "もの", "ここで", "あれば", "として", "など",
    "という", "した", "する", "して", "した場合", "の場合",
    # ラテン文字一般
    "true", "false", "null", "main", "import", "export", "function", "class",
    "const", "value", "array", "string", "number", "boolean",
    # 自分株式会社内省
    "自分株式会社", "Win版", "memory", "ROADMAP", "commit", "push", "rebase",
    "Issue", "Phase", "dogfood",
}

# ケバブケース変換 (= ascii 専用 / 日本語は SHA-1 short hash)
RE_HASH = re.compile(r"[^a-z0-9-]")


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────

def read_text(path: Path, max_bytes: int = 50_000) -> str:
    """Read first max_bytes of file (= memo file cap to avoid massive read)."""
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as f:
            return f.read(max_bytes)
    except OSError:
        return ""


def strip_codeblocks_and_frontmatter(text: str) -> str:
    """Remove ```...``` codeblocks + YAML frontmatter (= 概念抽出ノイズ排除)."""
    lines = text.splitlines()
    out: list[str] = []
    in_code = False
    in_frontmatter = False
    for i, line in enumerate(lines):
        if i == 0 and RE_FRONTMATTER.match(line):
            in_frontmatter = True
            continue
        if in_frontmatter:
            if RE_FRONTMATTER.match(line):
                in_frontmatter = False
            continue
        if RE_CODE_FENCE.match(line):
            in_code = not in_code
            continue
        if not in_code:
            out.append(line)
    return "\n".join(out)


def extract_concepts(text: str) -> list[str]:
    """1 ファイルから概念候補語を抽出. ノイズ除去 + 重複は呼び出し側."""
    cleaned = strip_codeblocks_and_frontmatter(text)
    raw: list[str] = []
    raw.extend(RE_KATAKANA.findall(cleaned))
    raw.extend(RE_ENGLISH_TERM.findall(cleaned))
    raw.extend(RE_KANJI_PHRASE.findall(cleaned))
    return [w for w in raw if w not in STOPWORDS and len(w) >= 3]


def kebab(name: str) -> str:
    """概念名 → ケバブケース ascii 化. 日本語は短縮 hash 付与."""
    lowered = name.lower()
    ascii_only = RE_HASH.sub("-", lowered).strip("-")
    if ascii_only and ascii_only.replace("-", ""):
        return ascii_only[:40]
    # 全 non-ascii → SHA1 short
    import hashlib
    h = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return f"jp-{h}"


def days_old(path: Path) -> int:
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return 999
    return int((dt.datetime.now().timestamp() - mtime) // 86400)


# ──────────────────────────────────────────────────────────────────────
# Compile
# ──────────────────────────────────────────────────────────────────────

def compile_concepts(days: int, min_sources: int) -> tuple[
    dict[str, dict[str, int]], dict[str, list[Path]]
]:
    """Scan raw layer + extract concepts.

    Returns:
      (concept_freq_per_layer, concept_source_paths)
        concept_freq_per_layer[concept] = {"memory": N, "competitor": M, ...}
        concept_source_paths[concept] = [Path(...), ...]
    """
    freq: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    sources: dict[str, list[Path]] = defaultdict(list)

    for layer, glob in RAW_SOURCES:
        for path in REPO_ROOT.glob(glob):
            if days > 0 and days_old(path) > days:
                continue
            text = read_text(path)
            if not text:
                continue
            words = extract_concepts(text)
            local_count = Counter(words)
            for w, c in local_count.items():
                # 同 file 内 2+ 出現で ようやく 1 source カウント (= ノイズ排除)
                if c < 2:
                    continue
                freq[w][layer] += 1
                if path not in sources[w]:
                    sources[w].append(path)

    # min_sources 以上 出現する概念のみ残す
    qualified = {
        w: layers for w, layers in freq.items()
        if sum(layers.values()) >= min_sources
    }
    qualified_sources = {w: sources[w] for w in qualified}
    return qualified, qualified_sources


def render_concept_page(
    name: str, layers: dict[str, int], paths: list[Path]
) -> str:
    """1 概念の wiki page を render."""
    total = sum(layers.values())
    today = dt.date.today().isoformat()
    layer_str = ", ".join(f"{k}: {v}" for k, v in sorted(layers.items()))
    src_lines = []
    for p in paths[:10]:
        rel = p.relative_to(REPO_ROOT).as_posix()
        src_lines.append(f"- [{rel}]({rel})")
    return (
        f"# {name}\n\n"
        f"> auto-generated by `scripts/wiki_compile.py` (= Karpathy Compile cycle / Win版#132 part 132).\n"
        f"> Last compile: {today}.\n"
        f"> 人間編集禁止 (= 上書きされる).\n\n"
        f"## 統計\n\n"
        f"- 総出現 source 数: **{total}**\n"
        f"- レイヤー別: {layer_str}\n\n"
        f"## 出典 (= raw layer 言及あり / 直近 30 日)\n\n"
        + "\n".join(src_lines) + "\n\n"
        f"## 関連\n\n"
        f"- [INDEX](../INDEX.md) — マスターインデックス\n"
        f"- Karpathy 4 サイクル: docs/SECOND_BRAIN_PRINCIPLES.md\n"
        f"- 移行ログ: docs/MULTI_INSTANCE_FLEET.md\n"
    )


def render_index(concepts: dict[str, dict[str, int]]) -> str:
    """全概念のマスターインデックス."""
    today = dt.date.today().isoformat()
    sorted_concepts = sorted(
        concepts.items(),
        key=lambda kv: (-sum(kv[1].values()), kv[0]),
    )
    lines = [
        "# 概念マスターインデックス (auto-generated)",
        "",
        "> auto-generated by `scripts/wiki_compile.py` (= Karpathy Compile cycle).",
        f"> Last compile: {today}.",
        "> 人間編集禁止 (= 上書きされる).",
        "",
        f"## 概念数: {len(concepts)}",
        "",
        "| 概念 | 総出現 | レイヤー |",
        "| --- | ---:| --- |",
    ]
    for name, layers in sorted_concepts:
        slug = kebab(name)
        total = sum(layers.values())
        layer_str = " ".join(f"{k}={v}" for k, v in sorted(layers.items()))
        lines.append(f"| [{name}](concepts/{slug}.md) | {total} | {layer_str} |")
    lines.append("")
    lines.append("## 関連")
    lines.append("")
    lines.append("- Karpathy 4 サイクル: `docs/SECOND_BRAIN_PRINCIPLES.md`")
    lines.append("- script: `scripts/wiki_compile.py`")
    lines.append("- workflow: `.github/workflows/wiki-compile-cron.yml` (= 候補)")
    return "\n".join(lines) + "\n"


# ──────────────────────────────────────────────────────────────────────
# Apply
# ──────────────────────────────────────────────────────────────────────

def apply_pages(
    concepts: dict[str, dict[str, int]],
    sources: dict[str, list[Path]],
    apply: bool,
    limit: int,
) -> tuple[int, int]:
    """Write concept pages + INDEX.md. Return (pages_written, skipped)."""
    if apply:
        WIKI_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped = 0
    for name, layers in sorted(
        concepts.items(), key=lambda kv: -sum(kv[1].values())
    )[:limit]:
        slug = kebab(name)
        page = WIKI_DIR / f"{slug}.md"
        body = render_concept_page(name, layers, sources.get(name, []))
        if apply:
            page.write_text(body, encoding="utf-8")
            written += 1
        else:
            written += 1  # plan
        if name not in sources:
            skipped += 1

    index_body = render_index(concepts)
    if apply:
        INDEX_FILE.write_text(index_body, encoding="utf-8")
    return written, skipped


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--days", type=int, default=30,
                    help="raw layer scan 期間 (default 30 日 / 0 = 全期間)")
    ap.add_argument("--min-sources", type=int, default=2,
                    help="概念 page 生成の最小 source 数 (default 2 / Karpathy 推奨)")
    ap.add_argument("--apply", action="store_true",
                    help="ファイル書込 (default = dry-run plan)")
    ap.add_argument("--limit", type=int, default=200,
                    help="生成する concept ページの上限 (default 200)")
    ap.add_argument("--json", action="store_true",
                    help="JSON summary 出力")
    args = ap.parse_args()

    print(f"[scan] raw layer: days={args.days} min_sources={args.min_sources}",
          file=sys.stderr)
    concepts, sources = compile_concepts(args.days, args.min_sources)

    written, skipped = apply_pages(concepts, sources, args.apply, args.limit)

    summary = {
        "mode": "apply" if args.apply else "dry-run",
        "concepts_total": len(concepts),
        "pages_planned_or_written": written,
        "skipped_no_sources": skipped,
        "limit": args.limit,
        "days": args.days,
        "min_sources": args.min_sources,
        "wiki_dir": str(WIKI_DIR.relative_to(REPO_ROOT)),
        "index_file": str(INDEX_FILE.relative_to(REPO_ROOT)),
    }

    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print()
        print(f"概念総数: {summary['concepts_total']}")
        print(f"生成ページ数 (= dry-run 計画 / apply 書込): {summary['pages_planned_or_written']}")
        print(f"出力先: {summary['wiki_dir']}/ + {summary['index_file']}")
        if not args.apply:
            print()
            print("[dry-run] --apply で実書込")

    return 0


if __name__ == "__main__":
    sys.exit(main())
