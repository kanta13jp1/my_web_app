# Win版 #132 part 29 — 2026-04-25 22:00 JST

**Instance**: Windowsアプリ版
**Branch**: claude/exciting-wu-3856d1 (worktree)
**Commits**: 73f146e0, 6ed0c44d

## 主要成果

deploy-prod の連鎖失敗 (24930958010 / 24931147734) の根本対策を強化。
PS#4 S57 (b94d502f) と Codex (2363ff66) が並行で 203000 を修正していたが、
他の `UPDATE WHERE instance='X'` パターンにも同じ SQLSTATE 23505 リスクが残存。
本セッションでそれらを idempotent 化。

## 実装

### 20260425203000_wbs_remove_all_instances_add_codex.sql
- 並行修正(2363ff66)で `UPDATE all→codex` は `DELETE WHERE instance='all'` に置換済
- 追加で以下の UPDATE パターンに DELETE-before-UPDATE ガード:
  - `UPDATE WHERE instance='windows' SET instance='win'`
  - `UPDATE WHERE instance='ps' SET instance='ps1'`
  - `UPDATE WHERE instance NOT IN (whitelist) SET instance='codex'`
- 各 DELETE は EXISTS 条件付き — 衝突対象 (title, target_instance) 行が既に存在する場合のみ実行
- 新DBでは no-op、repair re-run でのみ衝突行を排除

### 20260425210000_wbs_remove_all_instance_add_codex.sql
- category 別 CASE UPDATE all→mapped instance の前に DELETE 衝突行
- CASE 式を WHERE 句にインライン化して target instance ごとの衝突判定
- business-legal/finance/product/hr/ops/ipo→win, business-marketing→ps2,
  business-sales→ps5, UI系→vscode, etc.

## 並行修正との関係

| 修正 | 対象 | アプローチ | 残課題 |
|------|------|-----------|-------|
| 2363ff66 (Codex) | 203000 | target_instances に codex 追加 + UPDATE→DELETE | windows/ps/catch-all は未修正 |
| b94d502f (PS#4 S57) | 202000 新規 | 203000 実行前に pre-delete | 203000 内の他 UPDATE は未修正 |
| 73f146e0 (Win版 part29 = 私) | 203000+210000 | 全 UPDATE パターンに DELETE ガード | — |

3 修正は協調して機能。順序:
1. 202000 (PS#4): 'all'+'codex' 衝突 pre-clean
2. 203000 (Codex+Win): cartesian INSERT (codex 含む) → DELETE 'all' 残骸
   + Win版追加の windows/ps/catch-all idempotent ガード
3. 210000 (Win版): category-based CASE UPDATE idempotent

## CI 失敗履歴

- 24930958010 (31fea891 home): SQLSTATE 23505 wbs_tasks_title_instance_unique
- 24931147734 (88d30458 lint): 同上
- 24931499141 (b94d502f S57): cancelled (新 push に置換)
- 24931479924 (2363ff66 codex): in_progress
- 24931550431 (73f146e0 = 私 + roadmap): pending

## 学習: SQLSTATE 23505 + UNIQUE INDEX + repair re-run

`CREATE UNIQUE INDEX ... ON (col1, col2)` を migration で追加すると、その INDEX は
schema_migrations 状態と独立して**永続**する (CREATE IF NOT EXISTS は no-op)。

repair list で前後の migration を marked-reverted → re-apply する場合:
- INDEX 既存
- 前段の INSERT/UPDATE migrations が再実行される
- (col1, col2) の UNIQUE 違反で SQLSTATE 23505

**回避パターン (確立)**:
```sql
-- Idempotent UPDATE (DELETE conflicts then UPDATE survivors)
DELETE FROM tbl t1
WHERE t1.col2 = 'X'
  AND EXISTS (
    SELECT 1 FROM tbl t2
    WHERE t2.col1 = t1.col1
      AND t2.col2 = '<target>'
  );

UPDATE tbl SET col2 = '<target>' WHERE col2 = 'X';
```

新DB では DELETE 行 0件 (no-op)、re-run では衝突行のみ削除。

## 次回タスク候補

1. WBS recovery_plan / title mojibake 修正 (defe198f / b9e41091)
   - 現状: CP932 → UTF-8 raw byte storage で �ǉ� 等の REPLACEMENT char
   - 推定: defe198f.recovery_plan = "FY26 Q1: Lovable / v0 / Bolt.new 追加で 150 達成"
   - 推定: b9e41091.title = "LP FAQ差別化軸7追加 + FeatureStrategyAiReviewService test fix"
   - 推定: b9e41091.category = "LP改善"
   - 修正方法: data UPDATE migration (timestamp 20260426120000+)

2. provider.chat task (defe198f) 92→100 push: 未実装の LLM provider 残社調査 + PROVIDER_CONFIGS 追加
   - 候補: Lepton AI / Codestral (Mistral専用) / Databricks Foundation Model

3. EF cleanup: PS#6 S35 で 50/50 達成済 → 維持確認のみ

4. 競合モニタリング: 最新 Mythos AI exploit / DeepSeek V4 / Notion 3.4 戦略レポート
   (PS#4 担当だが Win版アーキテクチャ判断の場合あり)

## Philosophy Alignment

- CEO感: 並行修正の重複排除 + 追加防御の判断 ✅
- ミッション駆動: deploy 完走 = ユーザー価値届ける基盤 ✅
- 商品=ユーザー価値: feature/home integrated briefing が deploy 完走で本番反映 ✅
- 資本=時間: 同種衝突の再発防止 → 将来の deploy ループ削減 ✅
- KPI=昨日の自分: 1パターン → 5パターン全 idempotent 化 ✅
- ゴール: deploy SLA 改善 = α版 50人達成への貢献 ✅
