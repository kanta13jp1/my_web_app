# Cross-Instance PR: stale EF 移行 completeness audit

**作成**: Win版#132 part 50 / 2026-04-28
**依頼先**: PS版#5 (EF整理 / stale EF 移行 / on-call EF urgent 専任)
**優先度**: HIGH — 本日 part 50 で発覚した構造的負債 (memo-reactions の 1 件はすでに hotfix 済)
**推定工数**: 2-3 hours / hub EF 数 × action 数の cross-check スクリプト

---

## 背景

Win版#132 part 50 で発生した production 404 (`/functions/v1/memo-reactions?memo_id=N`)
の root cause:

- 旧 `memo-reactions` EF が 2026-04-24 (commit b4c91bc2) に core-hub 統合
- core-hub は `memo.react` action 1 個だけを実装し、それも **memo_reactions
  テーブルでなく hub_data に書く間違った実装** だった
- 旧 EF が提供していた **GET 集計** + **toggle off (DELETE)** が完全欠落
- Flutter `lib/pages/public_memo_detail_page.dart` は元 EF の 3 path
  (GET `?memo_id` / POST add / POST remove) を呼び続けて 404
- 5 日以上 production 404 のまま (= ユーザー UX 直接影響)

Win版#132 part 50 で `memo.react.list` + `memo.react.toggle` を core-hub に追加
+ Flutter 側を切り替えて hotfix (commit 45590ce4)。

しかし **これは 1 ケースに過ぎない**。同様の不完全 stale EF 移行が他にもある
可能性が高い。OPS-28 改善トリガー #4 (PR↔main 正本ズレ) の構造化。

## 現状の hub EF 統合状況

deploy-prod.yml のコメントから抽出した統合履歴:

```
core-hub (~25 EFs 統合):
  public-memo-share, memo-reactions, get-ogp, get-public-memo-ogp,
  ... (要 grep)

ai-hub (~16 EFs 統合):
  daily-judgment, ai-search, ai-suggest-tags, ai-secretary, ...

schedule-hub (~6 EFs 統合):
  schedule-daily-digest, schedule-manager, notification-center,
  post-x-update, blog-post-manager, blog-auto-publisher
```

**疑問**: 各 hub の action リストは **元 EF の全 endpoint contract をカバーして
いるか?** 現状の統合作業は「主たる 1 path のみ移行 / 残りは抜け落ち」を
許容している → memo-reactions 同型の bug が他にもある可能性。

## 依頼内容

`scripts/audit_hub_migration_completeness.py` (新規) を作成 → 以下を機械的に検出:

### 1. 旧 EF の参照を Flutter / scripts / docs から grep

```bash
# 統合済 (= deploy-prod.yml にコメント有り) の旧 EF 名一覧
RETIRED_EFS=$(grep -oE "([a-z-]+) → (core|ai|schedule|app|enterprise|community)-hub に統合済み" \
  .github/workflows/deploy-prod.yml | awk '{print $1}')

for ef in $RETIRED_EFS; do
  # client (lib/) で旧 path がまだ呼ばれているか
  hits=$(grep -rln "/functions/v1/$ef\b" lib/ 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "[STALE CLIENT REF] $ef still referenced by:"
    echo "$hits" | sed 's/^/  - /'
  fi
done
```

### 2. hub に対応 action があるか確認

旧 EF の TypeScript ソースが残っていれば (= まだ supabase/functions/<ef>/index.ts
が存在する場合) その exported route を hub の switch (action) と突き合わせる。
存在しないなら手動 spec チェックリスト (= cross-instance-pr で記録).

### 3. CI 化

`.github/workflows/stale-ef-completeness-check.yml` (新規):

```yaml
name: Stale EF Migration Completeness Check
on:
  pull_request:
    paths:
      - 'lib/**/*.dart'
      - 'supabase/functions/**'
      - '.github/workflows/deploy-prod.yml'
  push:
    branches: [staging, develop]
  schedule:
    - cron: '0 0 * * 1'  # weekly Monday 09:00 JST

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - run: python3 scripts/audit_hub_migration_completeness.py
      # exit 1 = stale ref 検出 → PR fail / Issue 自動起票
```

## 完了条件

- [ ] `scripts/audit_hub_migration_completeness.py` 新規 + main merge
- [ ] 初回 manual dispatch で **既存 stale ref を全件抽出**
- [ ] 各 stale ref を Issue 化 (label: `ops`, `stale-ef`, `priority:high`)
- [ ] CI workflow 追加 → PR で新規 stale ref 発生時 fail-fast
- [ ] Push 後この cross-instance-pr を `docs/cross-instance-prs/done/` に移動

## 既知の hotfix 済 case (本 audit の baseline)

| 旧 EF | hub | action 補完 commit | 完了 |
| --- | --- | --- | --- |
| memo-reactions | core-hub | 45590ce4 (Win版#132 part 50) | ✅ |

audit script はこの 1 件を抽出しないこと (今日の commit で対応済 = false positive)。

## OPERATIONS_CHARTER 整合

- 改善トリガー #4 (正本ズレ) を **構造的に検出する仕組み** へ昇格
- 5 正本層 #1 (Issues / PR) = 各 stale ref を Issue として可視化
- 5 正本層 #5 (worktree / branch) = main の deploy-prod.yml と client コードの整合を CI で守る

## 並行依頼 (= part 48 起票済の延長)

- `docs/cross-instance-prs/20260428_codex_merge_backlog_monitor_ps1.md` (PS#1) =
  Codex worktree の merge backlog 監視
- 本 PR (PS#5) = stale EF 移行の completeness 監査

両方が稼働すると、12 並行運用の **5 正本層ズレ** を 7 日以内に必ず検出できる
体制が完成する。

---

*Win版#132 part 50 / 2026-04-28 起票*
