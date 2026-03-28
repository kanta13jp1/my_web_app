-- Session 2026-03-28 Session 5: CHO室・選挙知能・仮想秘書強化
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('CHO室 メンタルチェック・医療メモ実装', 'CHO室のComing soonを解消: mental_check_page.dart + medical_memo_page.dartを実装', '2026-03-28'),
  ('選挙知能Edge Function追加', 'local-election-intelligence Edge Functionとelection_victory_page.dartを実装', '2026-03-28'),
  ('仮想秘書クイックタスク入力カード', 'quick_task_input_card.dartで会話からタスク自動生成する仮想秘書強化を実装', '2026-03-28'),
  ('AIゴール分解カード実装', 'AIがゴールを部署タスクに自動分解するカードをホーム画面に追加', '2026-03-28'),
  ('growth_plans 21競合完全対応', 'UNIQUE制約追加+全24プランのupsertマイグレーション(Discord/LINE/Facebook/Liven/GitHub/Google/Microsoft追加)', '2026-03-28'),
  ('edge_function_ui_status テーブル作成', 'GitHub Actions毎時audit結果をSupabaseに保存、admin dashboardでUIカバレッジ確認可能に', '2026-03-28')
ON CONFLICT DO NOTHING;
