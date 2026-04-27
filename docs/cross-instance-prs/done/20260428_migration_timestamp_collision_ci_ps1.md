# Cross-Instance PR: Migration Timestamp Collision CI 統合

**作成**: Win版#132 part 47 / 2026-04-28
**依頼先**: PS版#1 (`.github/workflows/` 専任 / Rule 17 WF health)
**優先度**: HIGH — 本日 (2026-04-28) PS#1 S53 で発生した 3 重衝突の **再発防止**
**推定工数**: 10-20 min / 1 ファイル更新 (CI step 追加 or 新 workflow)

---

## 背景

OPERATIONS_CHARTER 改善トリガー #1 (「衝突しそうな割り振り」) が本日発動:
`feedback_correction_20260428_migration_timestamp_collision.md`

PS#3 + PS#5 + PS#6 が **2026-04-28 00:00:00** の同一 timestamp で migration を作成
→ deploy-prod が SQLSTATE 23505 (schema_migrations_pkey UNIQUE violation) で失敗
→ PS#1 S53 が 000000 → 000100/000200 rename で対症療法。

しかし **予防 script が無い** ため次回も同じ collision が発生確実 (= 12 並行運用の
構造的弱点)。

Win版#132 part 47 で予防 script を実装済:

- [`scripts/check_migration_timestamps.py`](../../scripts/check_migration_timestamps.py)
  (162 行 / pytest 不要 / DB 接続不要 / dependency: 標準ライブラリのみ)
- 機能: `supabase/migrations/*.sql` を timestamp prefix でグループ化 →
  size >= 2 の collision を検出 → 修復候補 timestamp (100s/500s/1000s 増加) 提案
- CLI: `python scripts/check_migration_timestamps.py [--dir <path>] [--json]`
- Exit code: 0 = OK / 1 = collision あり / 2 = 起動エラー
- ローカル smoke: 775 migration 全 unique → exit 0 / synthetic 3 重衝突 → exit 1

---

## 依頼内容

`.github/workflows/ci.yml` または新 workflow に **migration timestamp collision check
step** を追加 → PR で衝突検出時 build fail させる。

### 案 A: 既存 ci.yml に 1 step 追加 (推奨)

`Lint, Format, and Test` job の Flutter analyze 後段に:

```yaml
- name: Check Supabase migration timestamp collisions
  run: |
    python3 scripts/check_migration_timestamps.py
  # exit 1 でビルド失敗 → PR レビュアー / 作成者が即気づく
```

### 案 B: 新 workflow `migration-collision-check.yml` (PR paths フィルタ)

`paths: supabase/migrations/**` のみ trigger する軽量 workflow:

```yaml
name: Migration Timestamp Collision Check
on:
  pull_request:
    paths:
      - 'supabase/migrations/**'
      - 'scripts/check_migration_timestamps.py'
  push:
    branches: [staging, develop]
    paths:
      - 'supabase/migrations/**'
concurrency:
  group: migration-collision-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 3
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: python3 scripts/check_migration_timestamps.py
```

PS#1 の判断で A/B どちらでも OK (推奨は B = video-pipeline-test.yml と同パターン /
ci.yml を肥大化させない)。

---

## 完了条件

- [ ] CI step / workflow が PR で走り、衝突検出時に exit 1 でビルド失敗
- [ ] 当該 step の name に "collision" を含めて run log で発見しやすく
- [ ] Push 後この cross-instance-pr を `docs/cross-instance-prs/done/` に移動

---

## OPERATIONS_CHARTER 整合

- 改善トリガー **#1 衝突しそうな割り振り** = 本対応
- 5 正本層 #1 (GitHub Issues / PR) = CI fail を完了判定として活用
- 5 正本層 #5 (worktree) = 衝突は worktree 跨ぎの timestamp 重複 → 物理層で fail-closed

---

*Win版#132 part 47 / 2026-04-28 起票*
