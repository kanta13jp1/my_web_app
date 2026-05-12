#!/usr/bin/env python3
"""instance_role_audit.py — 12 instance fleet 担当分担の monthly audit.

Win版#132 part 99 / 2026-04-30 / AI_FLEET_SYNERGY 原則 #1 (Strict Instance Routing) dogfood.

Logic:
  1. 過去 30 日の git log を instance 別に集計 (= commit author / co-author / branch から推定)
  2. CLAUDE.md routing matrix の想定役割と比較
  3. 乖離があれば警告 + GitHub Issue 化 (label: instance-routing-audit)
  4. レポートを docs/instance-role-audit/<YYYY-MM>.md に保存

Instance 別役割 (= CLAUDE.md / docs/MULTI_INSTANCE_FLEET.md):
  - vscode  : Flutter UI / EF
  - win     : docs / migration schema / 動画 pipeline
  - ps1     : Rule17 WF health
  - ps2     : T-1 dispatch (dev.to / Qiita)
  - ps3     : AI 大学 provider 追加
  - ps4     : 競合モニタリング / comparison_page seed
  - ps5     : EF migration / async safety
  - ps6     : horse-racing confidence terms
  - codex1  : 横断調査 / 修正 PR
  - codex2  : EF (Deno) / GHA workflow / CI 補助
  - web     : (= スマホ版 / GitHub MCP のみ)
  - mobile  : (= スマホ実機 UAT)

Output:
  - docs/instance-role-audit/<YYYY-MM>.md  (= commit 分布 + 乖離検出 + 推奨)

= zero-budget で動く (= git log のみ / 外部 API 不要)
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# instance 識別パターン (= commit message + branch から推定)
INSTANCE_PATTERNS: list[tuple[str, list[re.Pattern]]] = [
    ("vscode", [re.compile(r"\bVSCode版?\b", re.IGNORECASE),
                re.compile(r"\bvscode/?S?\d+\b", re.IGNORECASE)]),
    ("win",    [re.compile(r"\bWin版?#\d+", re.IGNORECASE),
                re.compile(r"\binstance-win\b")]),
    ("ps1",    [re.compile(r"\bPS#?1\b", re.IGNORECASE),
                re.compile(r"\bps1[/-]")]),
    ("ps2",    [re.compile(r"\bPS#?2\b", re.IGNORECASE),
                re.compile(r"\bps2[/-]")]),
    ("ps3",    [re.compile(r"\bPS#?3\b", re.IGNORECASE),
                re.compile(r"\bps3[/-]")]),
    ("ps4",    [re.compile(r"\bPS#?4\b", re.IGNORECASE),
                re.compile(r"\bps4[/-]")]),
    ("ps5",    [re.compile(r"\bPS#?5\b", re.IGNORECASE),
                re.compile(r"\bps5[/-]")]),
    ("ps6",    [re.compile(r"\bPS#?6\b", re.IGNORECASE),
                re.compile(r"\bps6[/-]")]),
    ("codex1", [re.compile(r"\bcodex#?1\b", re.IGNORECASE),
                re.compile(r"\bcodex/codex1[/-]")]),
    ("codex2", [re.compile(r"\bcodex#?2\b", re.IGNORECASE),
                re.compile(r"\bcodex/codex2[/-]")]),
]

EXPECTED_TERRITORY: dict[str, list[str]] = {
    # 各 instance の実 commit 文脈を反映 (= 2026-04-30 part 101 で Win 直接 audit に基づき更新)
    "vscode": [r"^lib/", r"^integration_test/", r"^test/", r"^web/"],
    "win":    [r"^docs/", r"^supabase/migrations/", r"^scripts/video/",
               r"^memory/", r"^\.claude/", r"^scripts/.*_audit\.py$",
               r"^scripts/ai_tool_changelog", r"^scripts/instance_role"],
    "ps1":    [r"^\.github/workflows/", r"^scripts/check_",
               r"^supabase/migrations/.*_ps1_", r"^docs/cross-instance-prs/",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md", r"^lib/pages/comparison_page"],
    "ps2":    [r"^docs/blog-drafts/", r"^docs/dev-to-drafts/",
               r"^scripts/blog_", r"^supabase/migrations/.*_ps2_",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md"],
    "ps3":    [r"^lib/pages/comparison", r"^supabase/migrations/.*ai_university",
               r"^supabase/migrations/.*_ps3_", r"^web/sitemap\.xml",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md"],
    "ps4":    [r"^lib/pages/comparison_page", r"^supabase/migrations/.*competitors",
               r"^supabase/migrations/.*_ps4_", r"^web/sitemap\.xml",
               r"^lib/pages/landing_page", r"^lib/pages/user_manual_page",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md"],
    "ps5":    [r"^supabase/functions/", r"^lib/pages/",
               r"^supabase/migrations/.*_ps5_",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md"],
    "ps6":    [r"^supabase/functions/tools-hub/", r"^scripts/.*horse_racing",
               r"^scripts/fetch_horse_racing", r"^lib/pages/horse_racing",
               r"^\.github/workflows/horse-racing",
               r"^supabase/migrations/.*_ps6_",
               r"^docs/GROWTH_STRATEGY_ROADMAP\.md"],
    "codex1": [r"^\.github/workflows/", r"^supabase/functions/",
               r"^supabase/migrations/", r"^scripts/"],
    "codex2": [r"^\.github/workflows/", r"^supabase/functions/",
               r"^scripts/", r"^supabase/migrations/.*codex"],
}


def git_log_30_days() -> list[dict[str, str]]:
    since = (datetime.utcnow() - timedelta(days=30)).strftime("%Y-%m-%d")
    fmt = "%H%x09%an%x09%s"
    try:
        r = subprocess.run(
            ["git", "log", f"--since={since}", f"--pretty=format:{fmt}",
             "--no-merges"],
            cwd=REPO_ROOT, check=True, capture_output=True, text=True,
            encoding="utf-8",
        )
    except subprocess.CalledProcessError:
        return []
    out: list[dict[str, str]] = []
    for line in r.stdout.splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            out.append({"sha": parts[0], "author": parts[1], "subject": parts[2]})
    return out


def files_changed(sha: str) -> list[str]:
    try:
        r = subprocess.run(
            ["git", "show", "--name-only", "--pretty=format:", sha],
            cwd=REPO_ROOT, check=True, capture_output=True, text=True,
            encoding="utf-8",
        )
        return [p for p in r.stdout.splitlines() if p.strip()]
    except subprocess.CalledProcessError:
        return []


def classify(commit: dict[str, str]) -> str:
    subj = commit["subject"]
    for inst, patterns in INSTANCE_PATTERNS:
        for p in patterns:
            if p.search(subj):
                return inst
    return "unknown"


def territory_match(inst: str, files: list[str]) -> tuple[int, int]:
    """expected territory にどれだけ match するか. returns (match, total)."""
    if inst not in EXPECTED_TERRITORY:
        return 0, len(files)
    pats = [re.compile(p) for p in EXPECTED_TERRITORY[inst]]
    match = sum(1 for f in files if any(p.search(f) for p in pats))
    return match, len(files)


def build_report(month: str, commits: list[dict[str, str]]) -> str:
    by_instance: dict[str, list[dict[str, str]]] = defaultdict(list)
    for c in commits:
        by_instance[classify(c)].append(c)

    lines: list[str] = []
    lines.append(f"# Instance Role Audit {month}\n")
    lines.append("")
    lines.append(
        "> Win版#132 part 99 / AI_FLEET_SYNERGY 原則 #1 (Strict Instance Routing) dogfood.\n"
        "> 過去 30 日の git log を instance 別に集計し、想定役割との乖離を検出.\n"
    )
    lines.append("")

    total = sum(len(v) for v in by_instance.values())
    lines.append(f"**total commits (last 30d)**: {total}\n")
    lines.append("")
    lines.append("## instance 別 commit 数")
    lines.append("")
    lines.append("| instance | commits | share | territory match | 乖離 |")
    lines.append("|---|---|---|---|---|")
    for inst in [
        "vscode", "win", "ps1", "ps2", "ps3", "ps4", "ps5", "ps6",
        "codex1", "codex2", "unknown",
    ]:
        cs = by_instance.get(inst, [])
        cnt = len(cs)
        share = (100.0 * cnt / total) if total else 0.0
        match_sum = 0
        total_files = 0
        for c in cs[:50]:  # 軽量化: 最大 50 commit
            m, t = territory_match(inst, files_changed(c["sha"]))
            match_sum += m
            total_files += t
        rate = (100.0 * match_sum / total_files) if total_files else 0.0
        warning = ""
        if inst != "unknown" and total_files > 0 and rate < 30:
            warning = "⚠️ low match"
        lines.append(
            f"| {inst} | {cnt} | {share:.1f}% | {rate:.1f}% ({match_sum}/{total_files}) | {warning} |"
        )

    lines.append("")
    lines.append("## 推奨 actions")
    lines.append("")
    lines.append("- 乖離 ⚠️ が出た instance は CLAUDE.md routing matrix 再確認")
    lines.append("- unknown が多すぎる場合 commit message convention 強化候補")
    lines.append("- share が 0% の instance は activity 低下 → ヘルスチェック")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append(f"*auto-generated by `scripts/instance_role_audit.py` for month {month}*")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--month", default=datetime.utcnow().strftime("%Y-%m"))
    p.add_argument("--output", default="")
    args = p.parse_args()

    out_path = (
        REPO_ROOT / args.output
        if args.output
        else REPO_ROOT / "docs" / "instance-role-audit" / f"{args.month}.md"
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)

    commits = git_log_30_days()
    if not commits:
        print("WARN: no commits in last 30 days (git log empty?)", file=sys.stderr)
    md = build_report(args.month, commits)
    out_path.write_text(md, encoding="utf-8")
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
