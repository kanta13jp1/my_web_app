#!/usr/bin/env python3
"""Audit `[[file]]` crosslinks in memory/ — Win版#132 part 138.

SECOND_BRAIN 原則 #2 (Autonomous Ingest & Linking) ベースライン測定:
- 各 memory/*.md (root のみ) で `[[<name>]]` 形式の wiki-link 出現数を集計
- 0 link file = orphan candidate (= 入っていく link なし / 出ていく link なし)
- ≥10 link file = healthy (Karpathy 流 10-15 link 推奨)
- inbound link 数も集計 (= 別 file から自分が参照されている回数)

Usage:
    PYTHONUTF8=1 python scripts/audit_memory_crosslinks.py
    PYTHONUTF8=1 python scripts/audit_memory_crosslinks.py --json

Output:
    docs/audit-reports/memory_crosslinks_YYYYMMDD.md
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MEMORY_DIR = REPO / "memory"
REPORT_DIR = REPO / "docs" / "audit-reports"

WIKI_LINK_RE = re.compile(r"\[\[([^\[\]\n]+?)\]\]")


def collect_files() -> list[Path]:
    """memory/ root の .md file のみ (= subdirectory 除外)."""
    return sorted(p for p in MEMORY_DIR.glob("*.md") if p.is_file())


def extract_links(content: str) -> list[str]:
    """`[[name]]` を全抽出 (= dedupe せず raw count)."""
    return [m.strip() for m in WIKI_LINK_RE.findall(content)]


def main() -> int:
    json_mode = "--json" in sys.argv

    files = collect_files()
    if not files:
        print("ERROR: no memory/*.md files found", file=sys.stderr)
        return 1

    # Step 1: per-file outbound link count
    outbound: dict[str, list[str]] = {}
    for fp in files:
        content = fp.read_text(encoding="utf-8", errors="replace")
        links = extract_links(content)
        outbound[fp.name] = links

    # Step 2: inbound count (= ほかから自分の stem を [[<stem>]] で参照されている数)
    file_stems = {fp.stem for fp in files}
    inbound: dict[str, int] = {fp.name: 0 for fp in files}
    for fname, links in outbound.items():
        for link in links:
            # `[[stem]]` または `[[stem|alias]]` の前半を取り出す
            target = link.split("|", 1)[0].strip()
            if target in file_stems:
                inbound[f"{target}.md"] += 1

    # Step 3: classify
    healthy = []  # outbound >= 10
    moderate = []  # outbound 1-9
    orphan_outbound = []  # outbound == 0
    isolated = []  # outbound == 0 AND inbound == 0

    for fp in files:
        ob = len(outbound[fp.name])
        ib = inbound[fp.name]
        if ob >= 10:
            healthy.append((fp.name, ob, ib))
        elif ob >= 1:
            moderate.append((fp.name, ob, ib))
        else:
            orphan_outbound.append((fp.name, ob, ib))
            if ib == 0:
                isolated.append((fp.name, ob, ib))

    total = len(files)
    summary = {
        "audit_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_files": total,
        "healthy_outbound_10plus": len(healthy),
        "moderate_outbound_1_9": len(moderate),
        "orphan_outbound_0": len(orphan_outbound),
        "isolated_in_0_out_0": len(isolated),
        "healthy_pct": round(100 * len(healthy) / total, 1),
        "moderate_pct": round(100 * len(moderate) / total, 1),
        "orphan_pct": round(100 * len(orphan_outbound) / total, 1),
        "isolated_pct": round(100 * len(isolated) / total, 1),
    }

    if json_mode:
        print(
            json.dumps(
                {
                    "summary": summary,
                    "healthy": healthy,
                    "moderate": moderate,
                    "orphan_outbound": orphan_outbound,
                    "isolated": isolated,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    # Step 4: write report
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORT_DIR / f"memory_crosslinks_{datetime.now().strftime('%Y%m%d')}.md"

    lines = [
        f"# memory/ crosslinks audit — {summary['audit_date']}",
        "",
        "> SECOND_BRAIN 原則 #2 (Autonomous Ingest & Linking) ベースライン.",
        "> Karpathy 流 = 1 file あたり 10-15 outbound `[[link]]` 推奨.",
        "",
        "## summary",
        "",
        f"- total memory/ root .md files: **{total}**",
        f"- healthy (outbound ≥ 10): **{summary['healthy_outbound_10plus']}** ({summary['healthy_pct']}%)",
        f"- moderate (outbound 1-9): **{summary['moderate_outbound_1_9']}** ({summary['moderate_pct']}%)",
        f"- orphan-outbound (outbound = 0): **{summary['orphan_outbound_0']}** ({summary['orphan_pct']}%)",
        f"- **isolated** (in = 0, out = 0): **{summary['isolated_in_0_out_0']}** ({summary['isolated_pct']}%) ← 最優先 fix",
        "",
        "## healthy (outbound ≥ 10)",
        "",
        "| file | outbound | inbound |",
        "| --- | ---: | ---: |",
    ]
    for name, ob, ib in healthy:
        lines.append(f"| `{name}` | {ob} | {ib} |")

    lines += [
        "",
        "## isolated (in=0 / out=0) — Karpathy 流 priority fix",
        "",
        "| file | (= どこからも参照されず / どこへも link 張らず) |",
        "| --- | --- |",
    ]
    for name, _ob, _ib in isolated:
        lines.append(f"| `{name}` | — |")

    lines += [
        "",
        "## moderate (outbound 1-9) — augment 候補",
        "",
        "| file | outbound | inbound |",
        "| --- | ---: | ---: |",
    ]
    for name, ob, ib in moderate:
        lines.append(f"| `{name}` | {ob} | {ib} |")

    lines += [
        "",
        "## orphan-outbound (outbound = 0 / inbound > 0) — 「読まれているが繋いでいない」",
        "",
        "| file | inbound |",
        "| --- | ---: |",
    ]
    for name, _ob, ib in orphan_outbound:
        if ib > 0:
            lines.append(f"| `{name}` | {ib} |")

    lines += [
        "",
        "## 推奨 next action",
        "",
        f"1. **isolated {summary['isolated_in_0_out_0']} 件**: 関連 atomic notes 10+ を追加 → SECOND_BRAIN #2 違反解消",
        f"2. **orphan-outbound {summary['orphan_pct']}%**: `[[link]]` 慣習が未定着 / 全 file に最低 1 link 追加",
        f"3. **healthy {summary['healthy_pct']}% を 50%+ へ**: baseline 改善目標",
        "",
        "## audit script",
        "",
        f"`PYTHONUTF8=1 python scripts/audit_memory_crosslinks.py`",
        "",
        "*Win版#132 part 138 / 2026-05-05 / SECOND_BRAIN baseline 5.0/7 → audit 第 1 例*",
        "",
    ]

    report_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"[OK] audit complete: {report_path}")
    print(f"  total: {total} / healthy: {len(healthy)} / moderate: {len(moderate)} / orphan-out: {len(orphan_outbound)} / isolated: {len(isolated)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
