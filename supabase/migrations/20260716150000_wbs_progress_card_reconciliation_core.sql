-- Win Claude (L3): Partial progress for the card-statement reconciliation cluster
-- (#3329 / #3326 / #3349) — shared deterministic core landed. NOT completion.
--
-- Deliverable (tested pure logic):
--   - lib/services/card_statement_reconciliation_planner.dart … Flutter/Supabase 非依存の
--     照合 money ロジック。billed / configured / statement 差分、needs_review、alert、
--     `suggestedBalancingAmount`(不足額の pre-fill)、`previewAdjustment`(差分入力の
--     ライブ preview + overshoot 判定 + 解消判定)、provisional(仮内訳)を official 集計から
--     除外 + promote。revolving は alert 抑止。tolerance 0.5 円は既存 `_moneyDiffers` と一致。
--   - test/services/card_statement_reconciliation_planner_test.dart … 11 ケース
--     (auPAY 例 billed40163/configured32152 の -8011 差分 / balancing 8011 で解消 /
--      overshoot / provisional 除外 + promote / 0・NaN reject / revolving 抑止)。
--
-- 検証: dart 未導入のため実 Dart test はローカル不可 → ロジックを faithful に JS ミラーして
--   Node で 11 グループ全通過を確認。正本 `flutter test` は ci.yml が gate。
--
-- この 1 コアが 3 Issue の受け入れ条件の計算部を満たす:
--   #3329 3ステップ照合ウィザードの「請求額確認→差分入力→保存」の算出
--   #3326 手動明細入力の configured vs billed 整合チェック + 差分0で自動解消
--   #3349 仮内訳の official 集計除外 + 昇格
-- 残作業 (Codex 実装 + 実機 QA): 各 Issue の wizard/UI 導線、Supabase 永続化、E2E QA。
-- progress<100 / in_progress を維持 (完了は主張しない)。

UPDATE public.wbs_tasks AS t
SET
  status         = 'in_progress',
  progress       = GREATEST(COALESCE(t.progress, 0), 50),
  owner_instance = COALESCE(NULLIF(t.owner_instance, ''), 'win'),
  remaining_work = m.remaining,
  updated_at     = now()
FROM (
  VALUES
    ('cb2bd1e3-949a-4a22-9066-4e1b1eb62c3c'::uuid,
     '#3329: 照合 core = lib/services/card_statement_reconciliation_planner.dart (差分/preview/balancing) 着地。残: 3ステップ wizard UI (請求額確認→差分入力→保存) + 保存永続化 + 実機 QA (Codex)。'),
    ('b10b88c0-0298-467c-84f8-94f450e16ea2'::uuid,
     '#3329: 照合 core = lib/services/card_statement_reconciliation_planner.dart (差分/preview/balancing) 着地。残: 3ステップ wizard UI (請求額確認→差分入力→保存) + 保存永続化 + 実機 QA (Codex)。'),
    ('f9251537-2599-423f-81b1-798db41886d0'::uuid,
     '#3326: 照合 core (configured vs billed 整合 + previewAdjustment で差分0=自動解消) 着地。残: 手動明細行入力フォーム UI + card_statement_reconciliation への反映 + 実機 QA (Codex)。'),
    ('60bee610-f25c-401f-85ac-2b8ea7075c25'::uuid,
     '#3326: 照合 core (configured vs billed 整合 + previewAdjustment で差分0=自動解消) 着地。残: 手動明細行入力フォーム UI + card_statement_reconciliation への反映 + 実機 QA (Codex)。'),
    ('a95eb43d-5749-4fa3-9008-08d2d81c82f0'::uuid,
     '#3349: 仮内訳 core (CardManualAdjustment.provisional を official 集計から除外 + promote) 着地。残: 仮内訳の追加/昇格/削除 UI + 永続化 + バッジ表示 + 実機 QA (Codex)。'),
    ('2df11e2b-9b42-46cc-ad63-a43d77d2457a'::uuid,
     '#3349: 仮内訳 core (CardManualAdjustment.provisional を official 集計から除外 + promote) 着地。残: 仮内訳の追加/昇格/削除 UI + 永続化 + バッジ表示 + 実機 QA (Codex)。')
) AS m(row_id, remaining)
WHERE t.id = m.row_id
  AND COALESCE(t.status, '') <> 'completed';
