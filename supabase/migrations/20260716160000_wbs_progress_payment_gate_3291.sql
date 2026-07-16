-- Win Claude (L3): Partial progress for GitHub Issue #3291
-- 「入金予定ウィザードと必須チェック（給料日テンプレ即登録）」 — gate core landed. NOT completion.
--
-- Deliverable (tested pure logic):
--   - lib/services/payment_confirmation_gate.dart … Flutter/Supabase 非依存の gate 判定。
--     income_plan 未登録 + 利用可能額不足を入力に、(1) 未登録バナー可視 (AC: 警告バナー) /
--     (2) 支払確定を確認ダイアログでインターセプト (AC: 未登録のまま確定→確認/キャンセル可) /
--     (3) severity(none/info/warning/critical) と文面 を決定。paymentAmount 指定時は
--     「その支払で利用可能額がマイナスになる」ケースも確認要求。
--   - test/services/payment_confirmation_gate_test.dart … 7 ケース
--     (#3291 実例 available -236,690 + income_plans=[] → critical/block / 未登録+黒字=warn/block /
--      健全=none / 既に赤字=warn/block・バナー無 / 支払で赤字転落=block / 収まる=通過)。
--
-- 検証: dart 未導入のため実 Dart test はローカル不可 → ロジックを faithful に JS ミラーして
--   Node で 7 グループ全通過を確認。正本 `flutter test` は ci.yml が gate。
--
-- 既存で充足済 (agent 監査): 入金予定の登録 dialog + 保存後 cashflow 即時再計算 (AC #2)。
-- 本 core が埋める欠落: 未登録時の block gate 判定 (AC #1 バナー / AC #3 確認ダイアログ)。
-- 残作業 (Codex 実装 + 実機 QA): バナー widget、支払確定ボタンへの gate 接続 (確認ダイアログ表示)、
--   多段登録 wizard、E2E QA。progress<100 / in_progress を維持 (完了は主張しない)。

UPDATE public.wbs_tasks AS t
SET
  status         = 'in_progress',
  progress       = GREATEST(COALESCE(t.progress, 0), 50),
  owner_instance = COALESCE(NULLIF(t.owner_instance, ''), 'win'),
  remaining_work = '#3291: gate core = lib/services/payment_confirmation_gate.dart (未登録バナー可視 + 支払確定確認 + severity) 着地。既存の登録 dialog + 保存後再計算は実装済。残: バナー widget + 支払確定ボタンへ gate 接続 (確認ダイアログ/キャンセル可) + 多段登録 wizard + 実機 QA (Codex)。計算は evaluatePaymentConfirmationGate を呼ぶだけ。',
  updated_at     = now()
FROM (
  VALUES
    ('88c21306-1b5f-4398-8518-c5003ed217a6'::uuid),
    ('4d15bd44-dbce-4f0b-8c2c-89194d5547f1'::uuid)
) AS m(row_id)
WHERE t.id = m.row_id
  AND COALESCE(t.status, '') <> 'completed';
