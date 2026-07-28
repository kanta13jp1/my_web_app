#!/usr/bin/env python3
"""inject-rules.txt 同期 — repo canonical (.claude/inject-rules.txt) と各 instance home (~/.claude/hooks/inject-rules.txt) の双方向 sync.

Win版#132 part 135 (2026-05-05).

設計:
- canonical (= repo .claude/inject-rules.txt) を git で管理 / 履歴保存
- home (= ~/.claude/hooks/inject-rules.txt) は毎ターン inject される実体
- canonical → home (= --apply / 標準): 他 instance や reactivation 時に同期
- home → canonical (= --reverse): 開発者が手元で編集 → repo へ push 用
- --verify: drift + Karpathy 80 行 KPI + rule 数 + critical keyword 検証

Usage:
    PYTHONUTF8=1 python scripts/sync_inject_rules.py             # dry-run diff
    PYTHONUTF8=1 python scripts/sync_inject_rules.py --apply     # canonical → home
    PYTHONUTF8=1 python scripts/sync_inject_rules.py --reverse   # home → canonical
    PYTHONUTF8=1 python scripts/sync_inject_rules.py --verify    # integrity check
    PYTHONUTF8=1 python scripts/sync_inject_rules.py --json      # JSON output

dependency-free (= stdlib のみ).
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CANONICAL_REL = ".claude/inject-rules.txt"
CANONICAL = REPO_ROOT / CANONICAL_REL
HOME = Path.home() / ".claude" / "hooks" / "inject-rules.txt"

# Karpathy 80 行 KPI
LINE_KPI = 80

# Critical rules (= 必ず存在すべき rule ID)
CRITICAL_RULES = [
    "[INSTANCE]",
    "[DART-FORMAT]",
    "[REBASE]",
    "[WORKDIR-ISOLATION]",
    "[STASH-SAFETY]",
    "[CAVEMAN]",
    "[WBS-SYNC]",
    "[INSTANCE-ROLES]",
    "[AI-TOOL-VERIFY]",
    "[SUBAGENT-GUARD]",
    "[CONCURRENCY]",
    "[AUTO-REPLY]",
    "[PHILOSOPHY-22]",
    "[AI-DEV-23]",
    "[AI-CHARACTER-24]",
    "[IMBUE-25]",
    "[COLLAB-26]",
    "[MCP-AUTH-27]",
    "[AI-VIDEO-29]",
    "[VIBE-30]",
    "[PLATFORM-31]",
    "[BRAIN-32]",
    "[INDIE-29]",
    "[SYNERGY-30]",
    "[OPS-28]",
    "[ROADMAP-LOG]",
    "[ISSUE-PRECHECK]",
    "[REAL-DATA]",
    "[EF-FIRST]",
    "[EF-CAP-50]",
    "[NO-SCOPE-CREEP]",
    "[UI-VERIFY]",
    "[CONSTRAINT-LOG]",
    "[SCHEDULE-WAKEUP]",
    "[COMPACTION-RESUME]",
    "[DYNAMIC-CLAIM]",
    "[WBS-DEDUP]",
    "[MEMORY-DECAY]",
    "[FLEET-OPS]",
]

EXPECTED_RULE_COUNT = 39


def read_text(path: Path) -> str | None:
    try:
        with path.open("r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def read_text_from_ref(ref: str) -> str | None:
    """Read the canonical rules out of a git ref without touching the working tree.

    Callers that run unattended (the daily scheduled sync) use this so they never
    need the checkout to be on a particular branch or clean. Reading a blob is
    safe no matter what branch the repo happens to be sitting on.
    """
    proc = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "show", f"{ref}:{CANONICAL_REL}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(content)


def hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def count_rules(text: str) -> int:
    return len(re.findall(r"^\[[A-Z][A-Z0-9_-]+\]", text, re.MULTILINE))


def list_rule_ids(text: str) -> list[str]:
    return re.findall(r"^\[[A-Z][A-Z0-9_-]+\]", text, re.MULTILINE)


def line_count(text: str) -> int:
    return len(text.splitlines())


def diff_unified(a: str, b: str, label_a: str, label_b: str) -> str:
    return "".join(difflib.unified_diff(
        a.splitlines(keepends=True),
        b.splitlines(keepends=True),
        fromfile=label_a,
        tofile=label_b,
        n=2,
    ))


def verify(text: str) -> dict:
    """Validate Karpathy KPI + rule count + critical rules + 80 行 KPI."""
    lines = line_count(text)
    rules = list_rule_ids(text)
    rule_count = len(rules)
    rule_set = set(rules)
    missing = [r for r in CRITICAL_RULES if r not in rule_set]

    issues: list[str] = []
    if lines > LINE_KPI:
        issues.append(f"line count {lines} > {LINE_KPI} (Karpathy KPI 違反)")
    if rule_count != EXPECTED_RULE_COUNT:
        issues.append(f"rule count {rule_count} != {EXPECTED_RULE_COUNT} (expected)")
    if missing:
        issues.append(f"missing critical rules: {missing}")

    return {
        "lines": lines,
        "rule_count": rule_count,
        "expected_rule_count": EXPECTED_RULE_COUNT,
        "line_kpi": LINE_KPI,
        "missing_critical_rules": missing,
        "kpi_pass": len(issues) == 0,
        "issues": issues,
    }


def cmd_dry_run(canonical: str, home: str | None) -> dict:
    if home is None:
        return {
            "mode": "dry-run",
            "home_exists": False,
            "canonical_lines": line_count(canonical),
            "action": "run --apply to create home file",
        }
    if hash_text(canonical) == hash_text(home):
        return {
            "mode": "dry-run",
            "drift": False,
            "canonical_lines": line_count(canonical),
            "home_lines": line_count(home),
            "action": "no sync needed (= identical)",
        }
    diff = diff_unified(home, canonical, "home (current)", "canonical (repo)")
    return {
        "mode": "dry-run",
        "drift": True,
        "canonical_lines": line_count(canonical),
        "home_lines": line_count(home),
        "diff_first_500_chars": diff[:500],
        "action": "run --apply (canonical→home) or --reverse (home→canonical)",
    }


def cmd_apply(canonical: str, source: str) -> dict:
    write_text(HOME, canonical)
    return {
        "mode": "apply",
        "source": source,
        "wrote": str(HOME),
        "lines": line_count(canonical),
    }


def cmd_reverse(home: str) -> dict:
    write_text(CANONICAL, home)
    return {
        "mode": "reverse",
        "wrote": str(CANONICAL),
        "lines": line_count(home),
        "next": "git diff .claude/inject-rules.txt → commit + push",
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--apply", action="store_true", help="canonical → home (sync)")
    g.add_argument("--reverse", action="store_true", help="home → canonical (= 開発者編集 push 用)")
    g.add_argument("--verify", action="store_true", help="integrity check (= 行数 / rule 数 / critical rule 残存)")
    ap.add_argument("--json", action="store_true", help="JSON output")
    ap.add_argument(
        "--from-ref",
        metavar="REF",
        help=(
            "canonical を作業ツリーでなく git ref から読む (例: origin/main)。"
            "作業ツリーに一切触れないので branch 状態や dirty 状態に依存しない (= 無人実行向け)。"
            "既定は作業ツリー読み (= 開発者のローカル編集をそのまま反映)"
        ),
    )
    args = ap.parse_args()

    if args.from_ref:
        if args.reverse:
            print("[error] --from-ref は --reverse と併用できません", file=sys.stderr)
            return 2
        canonical_source = args.from_ref
        canonical_text = read_text_from_ref(args.from_ref)
    else:
        canonical_source = str(CANONICAL)
        canonical_text = read_text(CANONICAL)

    home_text = read_text(HOME)

    if canonical_text is None:
        print(f"[error] canonical not found: {canonical_source}", file=sys.stderr)
        return 2

    if args.verify:
        result = {
            "canonical": verify(canonical_text),
            "home": verify(home_text) if home_text else {"error": "home not found"},
            "drift_between_canonical_and_home": (
                hash_text(canonical_text) != hash_text(home_text)
                if home_text else None
            ),
        }
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            ok = result["canonical"]["kpi_pass"]
            sym = "✅" if ok else "❌"
            print(f"{sym} canonical: lines={result['canonical']['lines']} rules={result['canonical']['rule_count']} kpi_pass={ok}")
            if result["canonical"]["issues"]:
                print(f"   issues: {result['canonical']['issues']}")
            if home_text:
                hok = result["home"]["kpi_pass"]
                hsym = "✅" if hok else "❌"
                print(f"{hsym} home:      lines={result['home']['lines']} rules={result['home']['rule_count']} kpi_pass={hok}")
                if result["home"]["issues"]:
                    print(f"   issues: {result['home']['issues']}")
                drift_sym = "✅" if not result["drift_between_canonical_and_home"] else "⚠️"
                print(f"{drift_sym} drift between canonical and home: {result['drift_between_canonical_and_home']}")
            else:
                print("⚠️ home not found (= run --apply to create)")
        return 0 if result["canonical"]["kpi_pass"] else 1

    if args.apply:
        result = cmd_apply(canonical_text, canonical_source)
    elif args.reverse:
        if home_text is None:
            print(f"[error] home not found: {HOME}", file=sys.stderr)
            return 2
        result = cmd_reverse(home_text)
    else:
        result = cmd_dry_run(canonical_text, home_text)

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for k, v in result.items():
            print(f"{k}: {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
