-- 2026-03-31 gemini-election-analysis 関数登録 + 実績シード

-- edge_function_ui_status に gemini-election-analysis を追加
INSERT INTO edge_function_ui_status (function_name, has_ui_caller, caller_file, last_checked)
VALUES
  ('gemini-election-analysis', false, NULL, now()),
  ('local-election-intelligence', false, NULL, now())
ON CONFLICT (function_name) DO UPDATE
  SET last_checked = now(), updated_at = now();

-- 本日の開発実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'gemini-election-analysis Edge Function 追加',
    'Google Gemini API を使用して統一地方選の候補者分析・月次KPI計算を行う Edge Function を新規追加。国民民主党700人倍増目標に向けた地域別シミュレーションをAIが自動生成。',
    '2026-03-31'
  ),
  (
    'ユーザーマニュアル QUICK ACCESS セクション対応',
    'ホーム画面の実際の UI 構造 (QUICK ACCESS セクション) に合わせてユーザーマニュアルを全面更新。存在しないセクション名の記述を修正し、正確なナビゲーション手順を記載。',
    '2026-03-31'
  ),
  (
    '比較ページ SEO メタデータ 21競合完全整備',
    'Google / Microsoft / Discord / LINE / Facebook / Liven / GitHub の vs-* 比較ページに OGタグ・description を追加し、21競合全ての比較ページの SEO 対応を完了。',
    '2026-03-31'
  ),
  (
    'Claude Code Schedule cs-check 自己修復フロー強化',
    'cs-check スケジュールタスクのプロンプトを更新。自己修復ステップ (auto-review Issue の自動修正) と schedule_task_runs テーブルへの実行ログ記録を追加。毎時の cs-check が正常動作中 (昨日4回実行確認)。',
    '2026-03-31'
  )
ON CONFLICT (title) DO NOTHING;
