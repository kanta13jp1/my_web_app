# Cross-instance PR — Win Claude → Win Codex CLI: Memory + HDD reduction (Issue #1984 残 axis A/B/C/E)

> **From**: Win版 (Claude Code) part 155-b
> **To**: Win版 (Codex CLI)
> **Date**: 2026-05-05
> **Priority**: medium (= P1 Issue だが Win Claude 側 axis D 着地済 / 残部依頼)
> **Issue**: [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984) [追加要望][P1][infra] 開発環境 メモリ + HDD 使用量削減

## 背景

User からの直接 ask (= part 155 末尾): 「毎セッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください.」

Issue #1984 で既に 6 axis (A-F) 設計済. 担当 split:
- **Win Claude** = playbook + 優先順位判断 + axis D (memory)
- **Win Codex** = script + cron + cache 系 (axis A / C / E)

Win Claude 側 part 155-b で **axis D 着地** = `~/.claude/hooks/memory-cleanup.ps1` 新設 + `docs/DISK_HYGIENE_RUNBOOK.md` Section 10-11 追加 (= 5 step / 閾値 gating / idempotent fast path).

## 依頼内容 (= Win Codex territory)

### Axis A: Worktree cleanup (= 最大効果 / 87 worktree → < 10 worktree 目標)

```python
# scripts/worktree_cleanup.py (= 新規)
# - git worktree list 全件
# - 各 worktree branch の origin merged status 検出
# - merged かつ HEAD == origin/<branch> なら remove 候補
# - --dry-run / --apply 切替
# - current $PWD 絶対 skip (= 自分自身削除防止)
```

```yaml
# .github/workflows/worktree-cleanup-cron.yml (= 新規)
name: worktree-cleanup-weekly
on:
  schedule: [{ cron: '0 16 * * 0' }]  # JST 月曜 01:00
  workflow_dispatch: {}
jobs:
  cleanup:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - run: python scripts/worktree_cleanup.py --apply
      - run: git worktree prune
      - name: report
        run: gh issue comment 1984 --body "weekly worktree cleanup ..."
```

### Axis B: 動画ファイル削減

`web/assets/videos/multi-agent-convergence.mp4` (= 12 MB) は Issue #1724 (P1 secrets / YouTube 化) 待ち. Issue #1724 着地後:
- YouTube 化 → mp4 削除
- `web/assets/videos/` 全削除 (= `.gitignore` 済 / repo 0 行)

→ Win Codex は **Issue #1724 着地ブロック解消後** に削除 PR.

### Axis C: Cache 清掃 (= 部分着地済 / 残部実施)

部分着地 (= part 154-a で disk-cleanup.ps1 が browser Cache / Code Cache / GPUCache / Service Worker 削除済).

残: **Flutter / npm / pnpm / pub / notebooklm cache** の cron prune.

```yaml
# .github/workflows/dev-cache-cleanup-cron.yml (= 新規)
name: dev-cache-cleanup-weekly
on:
  schedule: [{ cron: '0 17 * * 0' }]  # JST 月曜 02:00
  workflow_dispatch: {}
jobs:
  cleanup:
    runs-on: windows-latest
    steps:
      - run: flutter clean    # all worktrees
      - run: npm cache verify
      - run: pnpm store prune
      - run: dart pub cache clean
      - run: gh issue comment 1984 --body "weekly dev cache cleanup ..."
```

または Tier 2 `/disk-cleanup` slash command 内で同等処理を **手動 trigger** (= 既存 docs/DISK_HYGIENE_RUNBOOK.md 5 章) → 既存資産延長で十分なら新 cron 不要.

### Axis E: docs rotate (= cs-notes / daily-reports 90 日 archive)

```python
# scripts/docs_rotate.py (= 新規)
# - docs/cs-notes/*.md / docs/daily-reports/*.md / docs/auto-blog/*.md
# - mtime > 90 日 を docs/_archive/<YYYY-MM>/ へ mv (= git rm + git add)
# - 月初 PR 自動生成 (= weekly cron)
```

```yaml
# .github/workflows/docs-rotate-cron.yml (= 新規)
on:
  schedule: [{ cron: '0 18 1 * *' }]  # 月初 JST 03:00
  workflow_dispatch: {}
```

## 完了定義

- [ ] axis A: `scripts/worktree_cleanup.py` + `worktree-cleanup-cron.yml` (= 87 worktree → < 10 worktree 達成 dry-run validation 必須)
- [ ] axis B: Issue #1724 着地後に `web/assets/videos/` 削除 PR
- [ ] axis C: `dev-cache-cleanup-cron.yml` または Tier 2 拡張で Flutter / npm / pub cache 自動 prune
- [ ] axis E: `scripts/docs_rotate.py` + `docs-rotate-cron.yml` で 90 日 archive 自動化

## 関連 docs

- [`docs/DISK_HYGIENE_RUNBOOK.md`](../DISK_HYGIENE_RUNBOOK.md) Section 10-11 (= part 155-b memory 拡張)
- [`~/.claude/hooks/memory-cleanup.ps1`](C:/Users/kanta/.claude/hooks/memory-cleanup.ps1) (= part 155-b 新設)
- [`~/.claude/hooks/disk-cleanup.ps1`](C:/Users/kanta/.claude/hooks/disk-cleanup.ps1) (= part 154 既存)
- Issue [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984) (= 親 Issue / axis A-F 全体)
- Issue [#1724](https://github.com/kanta13jp1/my_web_app/issues/1724) (= axis B blocker / video pipeline secrets)

## 期日

- axis A (worktree cleanup): **1 week 以内** (= 87 worktree 圧迫深刻 / 物理資産 risk)
- axis C / E (cache + docs rotate): 2 week 以内
- axis B (video): Issue #1724 着地後 (= depends-on)

## INSTANCE-ROLES 確認

- 5-question matrix 全 NO = Codex territory
  - Q1 設計 = ❌ (= 既存 spec ship 済 / Win Claude playbook 着地済)
  - Q2 docs/SOP = △ (= playbook 部分は Win Claude / script は Codex)
  - Q3 UI design = ❌
  - Q4 triage = ❌
  - Q5 部署横断 = ❌ (= ops 部署単独)
- → Win Codex hand off
