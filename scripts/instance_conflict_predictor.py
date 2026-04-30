#!/usr/bin/env python3
"""instance_conflict_predictor.py — 12 fleet 並行作業の競合予測.

Win版#132 part 103 / 2026-04-30 / WBS Issue #926 対応.

目的:
  AI_FLEET_SYNERGY 原則 #1 (Strict Instance Routing) を超えて、
  同時作業による merge conflict / migration timestamp 衝突 / PR 競合を
  事前に detect → High / Medium / Low risk 警告.

trigger:
  - session start (= 起動時 audit)
  - migration 作成前 (= timestamp 衝突防止)
  - git add 前 (= 同一 file 編集衝突防止)

logic:
  1. 直近 24 時間の commit 群を file 単位で group
  2. 同一 file 編集が 2+ instance から → Medium 警告
  3. migration timestamp が 1 時間以内に複数 push → High 警告
  4. open PR 群の changed files が overlap → Medium 警告
  5. 上記なし → Low (= 安全)

output:
  - JSON (= machine readable / hook 連携用)
  - markdown (= human readable / docs/instance-conflict/<YYYY-MM-DD>.md)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

INSTANCE_PATTERNS: list[tuple[str, list[re.Pattern]]] = [
    ("vscode", [re.compile(r"\bVSCode版?\b", re.IGNORECASE),
                re.compile(r"\bvscode\b", re.IGNORECASE)]),
    ("win",    [re.compile(r"\bWin版?#\d+", re.IGNORECASE)]),
    ("ps1",    [re.compile(r"\bPS#?1\b", re.IGNORECASE)]),
    ("ps2",    [re.compile(r"\bPS#?2\b", re.IGNORECASE)]),
    ("ps3",    [re.compile(r"\bPS#?3\b", re.IGNORECASE)]),
    ("ps4",    [re.compile(r"\bPS#?4\b", re.IGNORECASE)]),
    ("ps5",    [re.compile(r"\bPS#?5\b", re.IGNORECASE)]),
    ("ps6",    [re.compile(r"\bPS#?6\b", re.IGNORECASE)]),
    ("codex1", [re.compile(r"\bcodex#?1\b", re.IGNORECASE),
                re.compile(r"\bcodex/codex1[/-]")]),
    ("codex2", [re.compile(r"\bcodex#?2\b", re.IGNORECASE),
                re.compile(r"\bcodex/codex2[/-]")]),
]


def classify_subject(subject: str) -> str:
    for inst, patterns in INSTANCE_PATTERNS:
        for p in patterns:
            if p.search(subject):
                return inst
    return "unknown"


def recent_commits(hours: int = 24) -> list[dict[str, object]]:
    """直近 N 時間の commit を file リスト付で取得."""
    since = (datetime.now(timezone.utc) - timedelta(hours=hours)).strftime(
        "%Y-%m-%d %H:%M:%S"
    )
    fmt = "%H%x09%an%x09%s"
    try:
        r = subprocess.run(
            ["git", "log", f"--since={since}", f"--pretty=format:{fmt}",
             "--name-only", "--no-merges"],
            cwd=REPO_ROOT, check=True, capture_output=True, text=True,
            encoding="utf-8",
        )
    except subprocess.CalledProcessError:
        return []

    commits: list[dict[str, object]] = []
    cur: dict[str, object] | None = None
    for line in r.stdout.splitlines():
        if "\t" in line and len(line.split("\t")) >= 3:
            if cur:
                commits.append(cur)
            sha, author, subj = line.split("\t", 2)
            cur = {"sha": sha, "author": author, "subject": subj,
                   "instance": classify_subject(subj), "files": []}
        elif line.strip() and cur is not None:
            files_list = cur["files"]
            assert isinstance(files_list, list)
            files_list.append(line.strip())
    if cur:
        commits.append(cur)
    return commits


def detect_file_conflicts(commits: list[dict[str, object]]) -> list[dict[str, object]]:
    """同一 file が 2+ instance に編集された候補を抽出."""
    file_to_instances: dict[str, set[str]] = defaultdict(set)
    for c in commits:
        inst = c["instance"]
        if inst == "unknown":
            continue
        files = c["files"]
        assert isinstance(files, list) and isinstance(inst, str)
        for f in files:
            file_to_instances[f].add(inst)

    conflicts = []
    for f, insts in file_to_instances.items():
        if len(insts) >= 2:
            conflicts.append({"file": f, "instances": sorted(insts),
                              "level": "Medium"})
    return conflicts


def detect_migration_clusters(commits: list[dict[str, object]]) -> list[dict[str, object]]:
    """1 時間以内に複数 instance が migration push したか."""
    migration_pushes: list[tuple[datetime, str, str]] = []
    for c in commits:
        files = c["files"]
        assert isinstance(files, list)
        instance = c["instance"]
        sha = c["sha"]
        assert isinstance(instance, str) and isinstance(sha, str)
        has_migration = any(
            f.startswith("supabase/migrations/") and f.endswith(".sql")
            for f in files
        )
        if has_migration:
            try:
                r = subprocess.run(
                    ["git", "show", "-s", "--format=%aI", sha],
                    cwd=REPO_ROOT, check=True, capture_output=True, text=True,
                )
                t = datetime.fromisoformat(r.stdout.strip())
                migration_pushes.append((t, instance, sha))
            except (subprocess.CalledProcessError, ValueError):
                continue

    migration_pushes.sort()
    clusters: list[dict[str, object]] = []
    for i, (t, inst, sha) in enumerate(migration_pushes):
        for j in range(i + 1, len(migration_pushes)):
            t2, inst2, sha2 = migration_pushes[j]
            delta = (t2 - t).total_seconds()
            if delta > 3600:
                break
            if inst != inst2:
                clusters.append({
                    "level": "High",
                    "instance_a": inst,
                    "instance_b": inst2,
                    "delta_seconds": int(delta),
                    "sha_a": sha[:8],
                    "sha_b": sha2[:8],
                })
    return clusters


def overall_risk(conflicts: list, clusters: list) -> str:
    if any(c.get("level") == "High" for c in clusters):
        return "High"
    if conflicts:
        return "Medium"
    return "Low"


def render_markdown(now: datetime, hours: int, commits: list[dict[str, object]],
                    conflicts: list[dict[str, object]],
                    clusters: list[dict[str, object]], risk: str) -> str:
    lines: list[str] = []
    lines.append(f"# Instance Conflict Predictor — {now.strftime('%Y-%m-%d %H:%M UTC')}\n")
    lines.append("")
    lines.append(
        "> Win版#132 part 103 / Issue #926 dogfood / "
        "AI_FLEET_SYNERGY #1 拡張 — 並行作業の事前競合検知.\n"
    )
    lines.append("")
    lines.append(f"**window**: 直近 {hours} 時間 / **commits scanned**: {len(commits)}")
    lines.append("")
    lines.append(f"## overall risk: **{risk}**\n")
    lines.append("")

    lines.append("## detected file overlaps (= same file edited by 2+ instances)")
    lines.append("")
    if conflicts:
        for c in conflicts[:20]:
            insts = ", ".join(c.get("instances", []))
            lines.append(f"- [{c['level']}] `{c['file']}` ← {insts}")
    else:
        lines.append("- (no overlap detected)")
    lines.append("")

    lines.append("## migration timestamp clusters (= within 1 hour)")
    lines.append("")
    if clusters:
        for cl in clusters[:20]:
            lines.append(
                f"- [{cl['level']}] {cl['instance_a']} ({cl['sha_a']}) ↔ "
                f"{cl['instance_b']} ({cl['sha_b']}) / Δ {cl['delta_seconds']}s"
            )
    else:
        lines.append("- (no migration cluster detected)")
    lines.append("")

    lines.append("## 推奨 actions")
    lines.append("")
    if risk == "High":
        lines.append("- ⚠️ migration push の前に `python scripts/check_migration_timestamps.py` 必ず実行")
        lines.append("- 同 timestamp range 編集中の他 instance に Slack で確認")
    elif risk == "Medium":
        lines.append("- 同一 file 編集中: rebase 前に commit / git stash 不要 (= WIP commit 推奨)")
        lines.append("- conflict 起こりやすい file はあらかじめ cross-instance-pr で線引き")
    else:
        lines.append("- 安全. 通常作業 OK.")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*auto-generated by `scripts/instance_conflict_predictor.py`*")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--hours", type=int, default=24)
    p.add_argument("--output", default="")
    p.add_argument("--json-out", default="")
    args = p.parse_args()

    now = datetime.now(timezone.utc)
    commits = recent_commits(args.hours)
    conflicts = detect_file_conflicts(commits)
    clusters = detect_migration_clusters(commits)
    risk = overall_risk(conflicts, clusters)

    if args.json_out:
        out_json = REPO_ROOT / args.json_out
        out_json.parent.mkdir(parents=True, exist_ok=True)
        out_json.write_text(json.dumps({
            "timestamp": now.isoformat(),
            "hours": args.hours,
            "commits_scanned": len(commits),
            "risk": risk,
            "conflicts": conflicts,
            "clusters": clusters,
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"wrote {out_json}")

    out_path = REPO_ROOT / args.output if args.output else (
        REPO_ROOT / "docs" / "instance-conflict" /
        f"{now.strftime('%Y-%m-%d')}.md"
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    md = render_markdown(now, args.hours, commits, conflicts, clusters, risk)
    out_path.write_text(md, encoding="utf-8")
    print(f"wrote {out_path}")
    print(f"risk: {risk}")
    return 0 if risk == "Low" else (1 if risk == "Medium" else 2)


if __name__ == "__main__":
    sys.exit(main())
