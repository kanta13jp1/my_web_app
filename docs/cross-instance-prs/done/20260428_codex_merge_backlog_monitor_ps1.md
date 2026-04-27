# Cross-Instance PR: Codex Worktree Merge Backlog Monitor

**作成**: Win版#132 part 48 / 2026-04-28
**依頼先**: PS版#1 (`.github/workflows/` 専任 / Rule 17 WF health)
**優先度**: MEDIUM — 12 並行運用の構造的弱点 / 本日 1 件発覚 (Issue #857)
**推定工数**: 30-60 min / 1 ファイル新規 (`.github/workflows/codex-backlog-check.yml`)

---

## 背景

Issue #857 (production header version badge hover で Null check operator エラー) を
Win版#132 part 48 で commit 1a8e6623 として hotfix 適用したが、原因調査で
**Codex#2 (codex/fix-header-version-badge / commit 151b9794) で既に修正済だった
にもかかわらず main に取り込まれていなかった** ことが判明した。

OPS-28 改善トリガー #4「Notion-WBS 正本ズレ」と同型の **PR ↔ main 正本ズレ** =
完成済 PR が hand-off lag で stale 化する 12 並行運用の構造的弱点。

## 問題のスコープ

`git worktree list` 確認時点で main 未マージの codex/* ブランチ:
- `codex/fix-header-version-badge` (151b9794) — **本日 part 48 で cherry-pick 済**
- `codex/horse-learning-loop` (fcc07278)
- `codex/ci-final-field-fix` (85b7cce6)
- `codex/fix-wbs-issue-sync` (0027f375)

これらは MULTI_INSTANCE_FLEET.md 末尾の「Codex 4 worktree → 2 stable slot 統合」で
扱う想定だが、**統合前にも individual fix が main に必要なケース**がある (Issue #857)。

## 依頼内容

`.github/workflows/codex-backlog-check.yml` 新規作成 (案):

```yaml
name: Codex Worktree Merge Backlog Check

on:
  schedule:
    - cron: '0 0 * * *'  # daily 09:00 JST
  workflow_dispatch:

permissions:
  issues: write
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: List unmerged codex/* branches
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Fetch all branches
          git fetch origin '+refs/heads/codex/*:refs/remotes/origin/codex/*' --no-tags

          # main にマージされていない codex/* ブランチを抽出
          unmerged=$(git for-each-ref --format='%(refname:short)' \
            refs/remotes/origin/codex \
            | while read b; do
              count=$(git rev-list origin/main..$b --count 2>/dev/null || echo 0)
              if [ "$count" -gt 0 ]; then
                # 7 日以上経過の branch のみ警告対象
                age_days=$(( ($(date +%s) - $(git log -1 --format=%ct $b)) / 86400 ))
                if [ "$age_days" -ge 7 ]; then
                  echo "$b ($count commits, ${age_days}d old)"
                fi
              fi
            done)

          if [ -n "$unmerged" ]; then
            # 既存 open Issue が無ければ新規作成
            existing=$(gh issue list --search 'Codex backlog in:title state:open' --json number --jq '.[0].number' || echo '')
            if [ -z "$existing" ]; then
              gh issue create \
                --title "[ops] Codex worktree merge backlog (7+ days unmerged)" \
                --label "ops,bot" \
                --body "$(printf 'Unmerged codex/* branches >= 7 days old:\n\n%s\n\nReview each branch and either merge or close.\n\n— codex-backlog-check.yml' "$unmerged")"
            fi
          fi
```

### 設計ポイント

- **7 日経過 cutoff**: 短命の codex worktree (PR 中) は除外
- **idempotent**: 既存 open Issue がある日は重複作成しない
- **labels**: `ops,bot` で人間 issue と区別
- **JST 09:00 daily**: User の 1 日開始タイミングで気づける
- **GITHUB_TOKEN のみ**: 新 secret 不要

---

## 完了条件

- [ ] `.github/workflows/codex-backlog-check.yml` 新規作成 + main merge
- [ ] 初回 manual dispatch で動作確認 (現在 3 codex/* branch が cutoff 該当のはず)
- [ ] Issue 自動作成 → 既存 codex worktree のうち merge 可否を判断
- [ ] Push 後この cross-instance-pr を `docs/cross-instance-prs/done/` に移動

## OPERATIONS_CHARTER 整合

- 改善トリガー #4 (正本ズレ) = 本対応で 7 日以内に検出可能化
- 5 正本層 #1 (Issues / PR) = backlog を Issue として可視化 → 正本層への昇格
- 5 正本層 #5 (worktree / branch) = stale branch を物理層から alert へ昇格

## OPS-28 charter 適用例 (本案件)

Issue #857 という 1 件の symptom から、12 並行運用の **構造的弱点** を抽出 →
即 Issue 化 (#857) + 即 hotfix (1a8e6623) + 即構造改善提案 (本 cross-instance-pr) の
3 段運用ができたことを charter「発見即提案」が実証。

---

*Win版#132 part 48 / 2026-04-28 起票*
