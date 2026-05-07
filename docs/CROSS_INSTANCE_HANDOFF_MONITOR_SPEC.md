# Cross-Instance Hand-off Auto-Ping Cron 設計仕様書

> **作成**: Win版#132 part 169 / 2026-05-07
> **From**: Win Claude (= architect / design)
> **To**: Win Codex (= GHA workflow + Python script 実装)
> **優先度**: medium (= Phase 6 自走化 / Win Claude session 主要 manual work 自動化 / 期限なし)
> **関連**: part 162-168 累積 6 hand-off streams / part 167 ping trigger schedule 確立 / Phase 1→2 自走化分離 dogfood 第 9 例

---

## 1. 背景 + ゴール

### Phase 1 (= 手動 / 現状)

Win Claude session で毎セッション以下を手動実行:

1. `gh pr list --search "<6 keyword OR>"` で hand-off PR query (= 30 sec)
2. 0 件 or 進捗確認
3. 期限 7 日前 trigger 該当 hand-off に status comment ping
4. ROADMAP append + commit

= 1 session **5-10 分** の manual triage / ~3-5 hand-off active 状態が標準。

### Phase 2 (= 自走化 / 本 spec の対象)

GHA cron + Python script で daily monitor:
- `docs/cross-instance-prs/<date>_<topic>_handoff_part<N>.md` 全 active scan
- 各 hand-off の Issue # + 期限 + keyword 抽出
- `gh pr list` で keyword match PR 確認
- ping trigger date 該当 (= 期限残 7 日 / 起票後 1 week 経過 dormant) → Issue に自動 status comment
- idempotent (= 同 week 再 ping skip)

### ゴール

- Win Claude session の手動 triage **5-10 min/session 削減**
- ping trigger の漏れ防止 (= 5/14 等の calendar trigger を auto-fire)
- Codex 進捗の visibility 向上 (= daily Issue update で fleet visible)

---

## 2. アーキテクチャ判断

### 2.1 既存 GHA pattern

| Workflow | 役割 | 本 spec との関係 |
|----------|------|----------------|
| `wbs-staleness-audit.yml` | WBS task の updated_at audit | **同 pattern** (= cron + Python + Issue comment) |
| `codex-backlog-check.yml` | stale Codex branches + conflicted PR | **異 scope** (= branch ベース / 本 spec は hand-off doc ベース) |
| `dormant-instance-grace-cron.yml` (part 165 hand-off / Codex 実装待ち) | dormant label issue auto-grace | **同 pattern + complementary scope** |
| `notebooklm-issue-crosscheck.yml` | NotebookLM × Issue cross-check | **異 scope** (= NB intake) |

→ `wbs-staleness-audit.yml` の structure をベース。

### 2.2 hand-off doc 検出 logic

```
For each file in docs/cross-instance-prs/<YYYYMMDD>_codex_*_handoff_part<N>.md:
    if file.mtime > now - 30 days:  # active hand-off only
        parse:
          - Issue # (from "Issue [#NNNN](" pattern)
          - 期限 (from "期限 YYYY-MM-DD" pattern)
          - keyword (from filename _<topic>_handoff or body title)

For each active hand-off:
    days_since_handoff = (now - file.created_at).days
    days_until_deadline = (deadline - now).days

    # Find matching PR
    matching_prs = gh pr list --search "<keyword>"
    if matching_prs is empty:
        # No PR yet
        if days_since_handoff >= 7 OR days_until_deadline <= 7:
            # Trigger ping
            check_last_ping_comment(issue, this_week)
            if not pinged_this_week:
                post_ping_comment(issue, hand-off, status, deadline_remaining)
    else:
        # PR exists
        post_progress_status_if_changed_since_last_run()
```

### 2.3 ping comment template

```markdown
## Codex hand-off auto-ping (week N / cron)

[docs/cross-instance-prs/<file>](docs/cross-instance-prs/<file>) hand-off の Codex 実装 PR が未確認です。

### Status

- Hand-off 起票日: {handoff_created_at}
- 期限: {deadline} (残 {days_remaining} 日)
- {urgency}: {trigger_reason} (= 起票後 7 日経過 OR 期限残 7 日)

### 推奨 action

- Win Codex 着手済なら **draft PR を作成して visibility 確保**
- 設計に修正必要なら hand-off doc に comment + Win Claude triage role が再 spec
- skip する場合は本 Issue に reason note

cc @kanta13jp1
```

### 2.4 idempotent gate

- 「直近 7 日に本 cron 由来 ping comment が投稿されている」場合 skip
- detection: comment body に `## Codex hand-off auto-ping (week` heading 含み + comment author == bot user
- 1 week / 1 hand-off = max 1 ping (= comment spam 防止)

### 2.5 safety gate

- `dry_run=true` workflow_dispatch option default
- `MAX_PINGS_PER_RUN=3` cap (= 1 回で最大 3 hand-off ping / cumulative 1 day max)
- comment author auto-detection (= 自分への ping 防止 / [AUTO-REPLY] rule respect)

---

## 3. 成果物 (= 3 file)

### 3.1 `.github/workflows/cross-instance-handoff-monitor-cron.yml` (= 新規)

```yaml
name: Cross-Instance Hand-off Auto-Ping Cron

on:
  schedule:
    # 毎日 03:00 UTC = 12:00 JST
    - cron: '0 3 * * *'
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run (no actual ping)'
        required: false
        default: 'true'
        type: choice
        options: ['true', 'false']

permissions:
  contents: read
  issues: write
  pull-requests: read

env:
  HANDOFF_DIR: 'docs/cross-instance-prs'
  ACTIVE_DAYS: 30   # only scan files mtime within 30 days
  PING_TRIGGER_DAYS: 7
  MAX_PINGS_PER_RUN: 3

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
      - name: Run hand-off monitor
        env:
          GH_TOKEN: ${{ secrets.GH_PAT || secrets.GITHUB_TOKEN }}
          DRY_RUN: ${{ github.event.inputs.dry_run || 'true' }}
        run: python scripts/cross_instance_handoff_monitor.py --apply=$([ "$DRY_RUN" = "false" ] && echo true || echo false)
```

### 3.2 `scripts/cross_instance_handoff_monitor.py` (= 新規 / dependency-free)

```python
"""Cross-instance hand-off auto-ping cron.

Scans docs/cross-instance-prs/<file>.md for active hand-offs,
checks if matching Codex PR exists, posts ping comment when:
  - 7+ days since hand-off creation AND no PR found
  - OR <= 7 days until deadline AND no PR found
Idempotent: skips if same hand-off pinged within last 7 days.

Usage:
    python scripts/cross_instance_handoff_monitor.py --apply=false  # dry-run
    python scripts/cross_instance_handoff_monitor.py --apply=true   # actual ping
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

HANDOFF_DIR = Path(os.environ.get("HANDOFF_DIR", "docs/cross-instance-prs"))
ACTIVE_DAYS = int(os.environ.get("ACTIVE_DAYS", "30"))
PING_TRIGGER_DAYS = int(os.environ.get("PING_TRIGGER_DAYS", "7"))
MAX_PINGS_PER_RUN = int(os.environ.get("MAX_PINGS_PER_RUN", "3"))

ISSUE_PATTERN = re.compile(r"Issue \[?#(\d+)\]?")
DEADLINE_PATTERN = re.compile(r"期限\s*[:：]?\s*(\d{4}-\d{2}-\d{2})")
KEYWORD_PATTERN = re.compile(r"_codex_([\w_]+)_handoff_part\d+\.md")
PING_HEADER = "## Codex hand-off auto-ping (week"

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

def parse_handoff(file_path):
    """Extract issue#, deadline, keyword from hand-off doc."""
    text = file_path.read_text(encoding="utf-8", errors="ignore")
    issue_m = ISSUE_PATTERN.search(text)
    deadline_m = DEADLINE_PATTERN.search(text)
    keyword_m = KEYWORD_PATTERN.search(file_path.name)
    if not issue_m or not keyword_m:
        return None
    return {
        "file": str(file_path.relative_to(Path("."))),
        "issue": int(issue_m.group(1)),
        "deadline": deadline_m.group(1) if deadline_m else None,
        "keyword": keyword_m.group(1).replace("_", " "),
    }

def find_matching_pr(keyword):
    raw = gh("pr", "list", "--state", "open", "--search", keyword,
            "--json", "number,title,headRefName", "--limit", "5")
    return json.loads(raw)

def has_recent_ping(issue, since_days=7):
    raw = gh("api", f"repos/kanta13jp1/my_web_app/issues/{issue}/comments")
    comments = json.loads(raw)
    cutoff = datetime.now(timezone.utc) - timedelta(days=since_days)
    for c in comments:
        body = c.get("body", "")
        created = datetime.fromisoformat(c["created_at"].replace("Z", "+00:00"))
        if PING_HEADER in body and created > cutoff:
            return True
    return False

def post_ping(issue, info, days_since, days_until_deadline, dry_run):
    week = datetime.now().isocalendar().week
    body = f"""## Codex hand-off auto-ping (week {week} / cron)

[{info['file']}]({info['file']}) hand-off の Codex 実装 PR が未確認です。

### Status

- Hand-off 起票日: {info.get('mtime', 'unknown')}
- 期限: {info.get('deadline', '期限なし')}
- 起票後 {days_since} 日経過 / 期限まで {days_until_deadline if days_until_deadline is not None else 'N/A'} 日

### 推奨 action

- Win Codex 着手済なら **draft PR を作成して visibility 確保**
- 設計に修正必要なら hand-off doc に comment + Win Claude triage role が再 spec
- skip する場合は本 Issue に reason note

cc @kanta13jp1
"""
    if dry_run:
        print(f"DRY: ping #{issue} ({info['keyword']}, {days_since}d / {days_until_deadline}d)")
    else:
        subprocess.run(["gh", "issue", "comment", str(issue), "--body", body],
                       check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", default="false")
    args = parser.parse_args()
    apply = args.apply.lower() == "true"
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=ACTIVE_DAYS)

    pings = 0
    for file_path in sorted(HANDOFF_DIR.glob("*_codex_*_handoff_part*.md")):
        mtime = datetime.fromtimestamp(file_path.stat().st_mtime, tz=timezone.utc)
        if mtime < cutoff:
            continue
        info = parse_handoff(file_path)
        if not info:
            continue
        info["mtime"] = mtime.strftime("%Y-%m-%d")

        days_since = (now - mtime).days
        days_until_deadline = None
        if info["deadline"]:
            deadline_dt = datetime.strptime(info["deadline"], "%Y-%m-%d").replace(tzinfo=timezone.utc)
            days_until_deadline = (deadline_dt - now).days

        # Check if PR exists
        prs = find_matching_pr(info["keyword"])
        if prs:
            print(f"OK: #{info['issue']} ({info['keyword']}) has PR(s) {[p['number'] for p in prs]}")
            continue

        # Trigger conditions
        trigger = (days_since >= PING_TRIGGER_DAYS or
                   (days_until_deadline is not None and days_until_deadline <= PING_TRIGGER_DAYS))
        if not trigger:
            continue

        # Idempotent gate
        if has_recent_ping(info["issue"]):
            print(f"SKIP: #{info['issue']} ({info['keyword']}) recently pinged")
            continue

        # Cap
        if pings >= MAX_PINGS_PER_RUN:
            print(f"CAP: max {MAX_PINGS_PER_RUN} pings reached, skipping rest")
            break

        post_ping(info["issue"], info, days_since, days_until_deadline, dry_run=not apply)
        pings += 1

    print(f"pings={pings} apply={apply}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### 3.3 `docs/cross-instance-prs/20260507_codex_handoff_monitor_cron_handoff_part169.md` (= hand-off / 別 file)

別 file (= 後述 §6)。

---

## 4. 受け入れ条件 (= Definition of Done)

- [ ] `.github/workflows/cross-instance-handoff-monitor-cron.yml` 新規 (= daily 03:00 UTC + workflow_dispatch dry_run)
- [ ] `scripts/cross_instance_handoff_monitor.py` 新規 (= dependency-free / argparse + gh + json + datetime + re + pathlib)
- [ ] `permissions: issues: write, pull-requests: read` 設定
- [ ] dry-run smoke test: `gh workflow run cross-instance-handoff-monitor-cron.yml -f dry_run=true` で 6 active hand-off (= part 162-168 累積) 全 scan + 期限残 / status 確認
- [ ] apply smoke test: 5/14 を simulate (= file mtime back-date) で実 ping 確認
- [ ] idempotent gate test: 同 week 内で 2 度実行 → 2 度目 skip 確認
- [ ] cap test: MAX_PINGS_PER_RUN=3 で 4+ trigger でも 3 件で stop
- [ ] PR description に本 spec link + 受け入れ条件 checklist

---

## 5. 4 軸 alignment

- **PHILOSOPHY-22 9/9 ✅** (= mentor + 6 部署 / IPO 信頼 = fleet visibility 自動化 / Win Claude session 5-10 min/day 削減)
- **AI-DEV-23 7/7 ✅** ([EF-FIRST] 不要 / dependency-free / observability via action log + Issue comment)
- **VIBE-30 7/7 ✅** (MVP scope 厳守 / dry-run default / safety cap / idempotent gate)
- **INDIE-29 7/7 ✅** (shipping 速度: spec 1 + script 1 + workflow 1 = 1 PR / 1 day 完結想定)
- **SYNERGY-30 7/7 ✅** (cross-instance-pr / Win Claude design → Win Codex 実装 routing / Phase 6 自走化第 9 例)
- **BRAIN-32 7/7 ✅** (memory pattern → 自動化 dogfood / triage default flow → cron 移行)
- **PLATFORM-31 7/7 ✅** ([EF-CAP-50] 維持 / 新 EF なし)

---

## 6. Codex 振分 5 質問 matrix (= [INSTANCE-ROLES])

| # | 質問 | 答 | 担当 |
|---|------|-----|------|
| Q1 | Architecture / 設計 needed? | YES (= 本 spec で完了 / hand-off) | Win Claude (本 spec) |
| Q2 | UI/UX design? | NO | — |
| Q3 | NotebookLM intake / triage? | NO | — |
| Q4 | AI 大学 / 競合 update? | NO | — |
| Q5 | Mobile UAT / video? | NO | — |
| **Implementation** (GHA workflow + Python script) | **Win Codex** |

---

## 7. 注意事項

- **[NO-SCOPE-CREEP]**: 本 cron は cross-instance hand-off ping のみ対象。code review / PR auto-merge は別 cron。
- **dry-run default**: 初回数週間は `dry_run=true` 維持推奨 (= ping spam 回避)。
- **safety cap**: `MAX_PINGS_PER_RUN=3` で 1 day 1 cron run 最大 3 ping / 6 active hand-off の場合 2 day で 1 巡。
- **idempotent gate**: 同 week 内 2 度 ping 防止 (= comment header detection)。
- **frequency**: daily (= 03:00 UTC = 12:00 JST) で過剰 ping 回避。
- **author auto-detection**: comment author == 自分 で skip ([AUTO-REPLY] rule respect)。

---

## 8. 関連 doc

- `docs/cross-instance-prs/` (= 監視対象 hand-off doc 群 / part 162-168 累積 6 streams)
- `.github/workflows/wbs-staleness-audit.yml` (= ベース pattern)
- `.github/workflows/dormant-instance-grace-cron.yml` (= 同 pattern / part 165 hand-off / Codex 実装待ち)
- part 167 ping trigger schedule (= 5/14 / 5/15 / 5/18 / 5/22)
- 「Phase 1 手動 → Phase 2 自走化分離 dogfood」pattern 第 9 例 (= 本 spec)
