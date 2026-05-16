# Dormant Instance 30 日 Grace 自動化 設計仕様書

> **作成**: Win版#132 part 165 / 2026-05-07
> **From**: Win Claude (= architect / design)
> **To**: Win Codex (= GHA workflow + Python script 実装)
> **優先度**: medium (= Phase 6 自走化 dogfood / 期限なし / 月次 cleanup ROI 計算で正当化)
> **関連**: part 163 「dormant 30 日 grace pattern 第 1 例」 / Issue [#1962](https://github.com/kanta13jp1/my_web_app/issues/1962) (= 第 1 ケーススタディ) / `~/.claude/projects/.../memory/feedback_success_20260507_dormant_30day_grace_pattern.md`

---

## 1. 背景 + ゴール

### Pattern (= part 163 確立)

`vscode-instance` / `ps1-6-instance` 等 dormant label 付き issue を**直 close せず**:
1. status comment 投稿 (= dormant 確認 + 30 日 grace + 再現時 label 張替指示)
2. 30 日経過 + 再現 comment 0 件 → CLOSE

### Phase 1 (= 手動)

part 163 で Issue #1962 に対し手動適用 (= status comment 投稿 / 2026-06-04 CLOSE 候補)。

### Phase 2 (= 自走化 / 本 spec の対象)

GHA cron + Python script で dormant label issue を全件監視 → 該当 issue に grace comment 自動投稿 + 30 日経過後 auto-CLOSE。

### ゴール

- Win Claude territory「dormant 整理」を構造的自走化
- 月次 manual cleanup work -1h/月 削減 (= [INDIE-29] graveyard 回避)
- 「30 日 grace + monitor」pattern を rule 化 (= [MEMORY-DECAY] dogfood)

---

## 2. アーキテクチャ判断

### 2.1 既存 GHA pattern との関係

| Workflow | 役割 | 本 spec との関係 |
|----------|------|----------------|
| `wbs-staleness-audit.yml` | WBS task の updated_at audit | **同 pattern** (= cron + Python + auto-PR/comment) |
| `stale-ef-completeness-check.yml` | EF deploy completeness audit | 異 domain |

→ `wbs-staleness-audit.yml` の structure をベースに新 workflow `dormant-instance-grace-cron.yml` を作成。

### 2.2 検出対象 label

```yaml
DORMANT_LABELS: ['vscode-instance', 'ps1-instance', 'ps2-instance', 'ps3-instance', 'ps4-instance', 'ps5-instance', 'ps6-instance', 'web-instance', 'mobile-instance', 'codex1-instance', 'codex2-instance']
```

合計 11 label (= 全 dormant instance per part 130 transition)。

### 2.3 判定 logic

```
For each open issue with label IN DORMANT_LABELS:
    age_days = NOW - issue.created_at
    last_repro_comment = NEWEST comment with label-related keyword OR `gh issue` matching pattern

    IF age_days >= 30 AND last_repro_comment IS NULL:
        → auto-CLOSE with reason note ("30-day grace expired / no recurrence")
    ELIF age_days >= 14 AND grace_comment_already_posted IS FALSE:
        → post grace_status_comment (= part 163 template)
    ELSE:
        → no-op
```

### 2.4 auto-CLOSE 安全弁

- **idempotent**: 既 CLOSE issue は skip
- **dry-run mode**: workflow_dispatch で `dry_run=true` 引数指定可 (= 本番反映前 verify)
- **`workflow-failure` label**: 同時付与は skip (= bug-as-dormant 誤判定回避)
- **comment 種別 detection**: comment author == `kanta13jp1` AND body に「再現」「reproduce」「still happening」等含む → 再現 comment 扱い

---

## 3. 成果物 (= 3 file)

### 3.1 `.github/workflows/dormant-instance-grace-cron.yml` (= 新規)

```yaml
name: Dormant Instance 30-Day Grace Cron

on:
  schedule:
    # 毎週月曜 02:00 UTC = 11:00 JST
    - cron: '0 2 * * 1'
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run (no actual close/comment)'
        required: false
        default: 'true'
        type: choice
        options: ['true', 'false']

permissions:
  contents: read
  issues: write

env:
  DORMANT_LABELS: 'vscode-instance,ps1-instance,ps2-instance,ps3-instance,ps4-instance,ps5-instance,ps6-instance,web-instance,mobile-instance,codex1-instance,codex2-instance'
  GRACE_DAYS: 30
  WARN_DAYS: 14

jobs:
  grace:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
      - name: Run dormant grace
        env:
          GH_TOKEN: ${{ secrets.GH_PAT || secrets.GITHUB_TOKEN }}
          DRY_RUN: ${{ github.event.inputs.dry_run || 'true' }}
        run: python scripts/dormant_instance_grace.py --apply=$([ "$DRY_RUN" = "false" ] && echo true || echo false)
```

### 3.2 `scripts/dormant_instance_grace.py` (= 新規 / dependency-free)

```python
"""Dormant instance 30-day grace cron.

Usage:
    python scripts/dormant_instance_grace.py --apply=false  # dry-run (default)
    python scripts/dormant_instance_grace.py --apply=true   # actual close/comment
"""
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta

DORMANT_LABELS = os.environ.get("DORMANT_LABELS", "").split(",")
GRACE_DAYS = int(os.environ.get("GRACE_DAYS", "30"))
WARN_DAYS = int(os.environ.get("WARN_DAYS", "14"))

GRACE_COMMENT_TEMPLATE = """## Dormant instance grace status (auto-comment)

本 Issue は label `{label}` 付与済 = part 130 (2026-05-04) で dormant 移行済 instance。

### 経過

- 起票: {created_at} ({age_days} 日経過)
- {warn_days}+ 日経過 / 再現 comment 0 件
- {remaining_days} 日後 (= {grace_expiry_date}) に auto-CLOSE 予定

### 再現時 action

2 instance fleet (= Win Claude / Win Codex) で同事象再現したら:
- label を `claude-code-instance` or `codex-instance` に張替
- 担当 instance へ振分

cc @kanta13jp1
"""

CLOSE_COMMENT_TEMPLATE = """## Dormant instance auto-close (= grace expired)

label `{label}` 付き Issue / {age_days} 日経過 / 2 instance fleet で再現報告 0 件 → auto-CLOSE。

再現あれば re-open + label 張替。

cc @kanta13jp1
"""

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

def fetch_dormant_issues(label):
    raw = gh("issue", "list", "--state", "open", "--label", label, "--json",
             "number,title,createdAt,labels,comments", "--limit", "200")
    return json.loads(raw)

def is_recurrence_comment(c):
    body = c.get("body", "").lower()
    return any(k in body for k in ["再現", "reproduce", "still happening", "happen again"])

def has_grace_comment(comments):
    return any("dormant instance grace status (auto-comment)" in c.get("body", "")
               for c in comments)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", default="false")
    args = parser.parse_args()
    apply = args.apply.lower() == "true"
    now = datetime.now(timezone.utc)

    actions = []
    for label in DORMANT_LABELS:
        if not label:
            continue
        for issue in fetch_dormant_issues(label):
            if any(L["name"] == "workflow-failure" for L in issue["labels"]):
                continue  # skip bug-as-dormant
            created = datetime.fromisoformat(issue["createdAt"].replace("Z", "+00:00"))
            age_days = (now - created).days
            comments = issue.get("comments", [])
            recurrence = any(is_recurrence_comment(c) for c in comments)
            if recurrence:
                continue  # skip recurring issue
            n = issue["number"]
            if age_days >= GRACE_DAYS:
                # auto-close
                if apply:
                    gh("issue", "comment", str(n), "--body",
                       CLOSE_COMMENT_TEMPLATE.format(label=label, age_days=age_days))
                    gh("issue", "close", str(n))
                actions.append(f"CLOSE #{n} ({label} / {age_days}d)")
            elif age_days >= WARN_DAYS and not has_grace_comment(comments):
                # warn
                expiry = created + timedelta(days=GRACE_DAYS)
                if apply:
                    gh("issue", "comment", str(n), "--body",
                       GRACE_COMMENT_TEMPLATE.format(
                           label=label, created_at=issue["createdAt"][:10],
                           age_days=age_days, warn_days=WARN_DAYS,
                           remaining_days=GRACE_DAYS - age_days,
                           grace_expiry_date=expiry.strftime("%Y-%m-%d")))
                actions.append(f"WARN #{n} ({label} / {age_days}d)")

    print(f"actions={len(actions)} apply={apply}")
    for a in actions:
        print(f"  {a}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### 3.3 `docs/cross-instance-prs/20260507_codex_dormant_grace_cron_handoff_part165.md` (= hand-off)

別 file (= 後述 §6)。

---

## 4. 受け入れ条件 (= Definition of Done)

- [ ] `.github/workflows/dormant-instance-grace-cron.yml` 新規 (= weekly Mon 02:00 UTC + workflow_dispatch dry_run option)
- [ ] `scripts/dormant_instance_grace.py` 新規 (= dependency-free / argparse + gh CLI)
- [ ] `permissions: issues: write` 設定 (= comment + close 必要)
- [ ] dry-run smoke test 1 回 (= workflow_dispatch dry_run=true / 出力件数確認)
- [ ] apply smoke test 1 回 (= Issue #1962 等で actual grace comment + auto-CLOSE 確認)
- [ ] `workflow-failure` label 付与 issue は skip 確認
- [ ] 再現 comment 含む issue は skip 確認
- [ ] PR description に本 spec link + 受け入れ条件 checklist

---

## 5. 4 軸 alignment

- **PHILOSOPHY-22 9/9 ✅** (= mentor + 6 部署 / KPI で graveyard 削減 / IPO 信頼)
- **AI-DEV-23 7/7 ✅** ([EF-FIRST] 不要 = GHA + Python only / dependency-free / observability via action log / dry-run gate)
- **VIBE-30 7/7 ✅** (MVP scope 厳守 / dry-run gate で安全 / Phase 1 手動 → Phase 2 自走化分離 dogfood)
- **INDIE-29 7/7 ✅** (shipping 速度: spec 1 doc + script 1 + workflow 1 = 1 PR / 1 day 完結想定 / [graveyard 回避])
- **SYNERGY-30 7/7 ✅** (cross-instance-pr で fleet 横断 / Win Claude design → Win Codex 実装 routing)
- **BRAIN-32 7/7 ✅** (memory pattern → 自動化 dogfood / Karpathy 4 cycle: ingest→compile→query→**lint**→graveyard 防止)

---

## 6. Codex 振分 5 質問 matrix (= [INSTANCE-ROLES])

| # | 質問 | 答 | 担当 |
|---|------|-----|------|
| Q1 | Architecture / 設計 needed? | YES (= 本 spec で完了 / hand-off) | Win Claude (本 spec) |
| Q2 | UI/UX design? | NO | — |
| Q3 | NotebookLM intake / triage? | NO | — |
| Q4 | AI 大学 / 競合 update? | NO | — |
| Q5 | Mobile UAT / video? | NO | — |
| **Implementation** (GHA workflow + Python script 着地) | **NO design → 実装** | **Win Codex** |

→ 設計 = Win Claude / **実装 = Win Codex** (cross-instance-pr 別 file)

---

## 7. 注意事項

- **[NO-SCOPE-CREEP]**: 本 cron は dormant label issue のみ対象。`stale` / `wontfix` 等他 label は別 cron。
- **[REAL-DATA]**: GitHub API リアルデータ使用 (= 該当)
- **dry-run default**: 初回数週間は `dry_run=true` で動作確認推奨
- **safety**: `workflow-failure` label + 再現 comment detection で **bug-as-dormant** 誤 close 回避
- **frequency**: weekly (= Mon 11:00 JST) で過剰投稿回避

---

## 8. 関連 doc

- [Issue #1962](https://github.com/kanta13jp1/my_web_app/issues/1962) (= 第 1 ケーススタディ)
- [docs/MULTI_INSTANCE_FLEET.md](docs/MULTI_INSTANCE_FLEET.md)
- [docs/FLEET_2_INSTANCE_TRANSITION.md](docs/FLEET_2_INSTANCE_TRANSITION.md)
- [.github/workflows/wbs-staleness-audit.yml](.github/workflows/wbs-staleness-audit.yml) (= ベース pattern)
- `~/.claude/projects/.../memory/feedback_success_20260507_dormant_30day_grace_pattern.md`
