# Cross-Instance PR: time-relative CHECK 触れ migration を CI で検出

**作成**: Win版#132 part 56 / 2026-04-28
**依頼先**: PS版#1 (Rule 17 WF health 専任 / `.github/workflows/`)
**優先度**: MEDIUM (deploy fail 直接予防 / 影響範囲: time-relative CHECK 持つ全 table)
**推定工数**: 1-2 hours

---

## 背景

PS#5 S78 (commit c698681e9 / 2026-04-28) で `20260426100000_wbs_github_issue_sync.sql`
が CI deploy 3 件失敗を起こした。root cause:

- migration が `wbs_tasks` を UPDATE
- table に `wbs_enforce_recovery_plan_trg` trigger 設置 (= deadline 経過 +
  recovery_plan NULL → SQLSTATE 23514)
- migration 作成時 (2026-04-26) は deadline=2026-04-27 が **未来 → pass**
- CI retry 時 (2026-04-28) は **過去化 → fail**
- = **migration の time-relative non-determinism**

PS#5 が `20260426090000_fix_wbs_recovery_plan_before_github_sync.sql` で事前
backfill する defensive migration を追加して解消したが、**同型 bug が将来
再発する可能性** がある (= 構造的負債 / 検出機構不在).

これは Win版#132 part 47 で導入した
`scripts/check_migration_timestamps.py` の盲点 — collision (= 同 timestamp) は
検出するが、**timestamp drift による time-relative CHECK 違反** は検出しない.

## 提案

`scripts/check_migration_time_relative_check.py` を新規作成 (or 既存
`check_migration_timestamps.py` に flag 追加):

### 検出ロジック

1. **対象 table の特定** — `supabase/migrations/` を grep して以下 pattern を持つ
   table 名を抽出:
   ```sql
   CHECK (deadline ... CURRENT_DATE ...)
   CHECK (due_date ... CURRENT_DATE ...)
   CHECK (valid_until > NOW() ...)
   CREATE TRIGGER ... BEFORE UPDATE ON <table> ... -- enforce_*_trg
   ```
   想定される table (現状判明): `wbs_tasks`, `streaks` (?), `daily_judgments` (?)

2. **疑わしい migration の特定** — 上記 table を UPDATE する migration:
   ```sql
   UPDATE wbs_tasks SET ...
   ```
   特に migration timestamp と CURRENT_DATE の差が 7 日以上ある場合は警告.

3. **CI 統合** — `.github/workflows/migration-collision-check.yml` (PS#1 既設置) の
   後段に step 追加 or 別 workflow `migration-time-relative-check.yml`.

### 期待出力例

```
$ python3 scripts/check_migration_time_relative_check.py
scanned 815 migration files
detected 3 tables with time-relative CHECK constraints:
  - wbs_tasks (wbs_enforce_recovery_plan_trg)
  - streaks (streak_within_window_chk)
  - daily_judgments (judgment_freshness_chk)

WARN: 2 migrations may fail on retry due to drift:
  - 20260426100000_wbs_github_issue_sync.sql
    UPDATE wbs_tasks (touches recovery_plan trigger; created 2 days ago)
    suggestion: defensive backfill or add trigger DEFERRABLE
  - 20260427150000_wbs_progress_remaining.sql
    UPDATE wbs_tasks (creator commented "deadline=2026-04-30")
    suggestion: review deadline CHECK timing

exit 1 if any WARN, exit 0 if clean
```

### 完了条件

- [ ] 新 script `scripts/check_migration_time_relative_check.py` 作成
- [ ] CI 統合 (案 A: 既存 collision-check workflow に step 追加 / 案 B: 新 workflow)
- [ ] PS#5 S78 と同型 backfill が再必要なら memory feedback `feedback_correction_20260428_migration_time_relative_check_drift.md`
      の "defensive backfill pattern" を docs に正式化
- [ ] git commit + push origin HEAD:main
- [ ] cross-instance-pr を `done/` 移動

## 案 A vs 案 B (PS#1 が判断)

**案 A: 既存 collision-check workflow を拡張**
- メリット: workflow 数増えない / paths-filter 同一
- デメリット: 検出ロジックが 2 種類混在 (collision + time-relative)

**案 B: 新 workflow `migration-time-relative-check.yml`**
- メリット: 関心の分離 (collision != time-relative)
- デメリット: workflow 数増 / paths-filter 重複

PS#1 推奨判断 (筆者の推測): 案 B が clean (= 検出ロジック異種混在を避ける).

## OPERATIONS_CHARTER 整合

- 改善トリガー #4 (正本ズレ) — migration timestamp ↔ deploy 時刻 の整合監視
- 5 正本層 #5 (worktree/main vs production state) — defensive backfill pattern を
  本 PR で正式化することで構造的負債解消

## 補助情報

判定 5 質問 (Codex routing matrix per part 53):
- Q1 設計判断: **YES** (案 A vs 案 B 判断 + DEFERRABLE 案 / Codex には判断不能)
- Q2 cross-instance 調整: **YES** (PS#1 territory)
- Q3 軸 docs 更新: 部分 YES (memory feedback 既作成)
- Q4 docs に残す判断: **YES**
- Q5 NotebookLM 連携: 不要

→ 1 つでも YES = **Claude (PS#1) が処理**. Codex は適合しない.

---

*Win版#132 part 56 / 2026-04-28 起票*
