-- PowerShell #8 セッション実績
-- schedule-task-monitor schema修正・CS/daily-reportトリガー task_id修正

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('schedule-task-monitor スキーマ完全修正', 'task_name→task_id カラム名修正・failure→error ステータス正規化・存在しない get_schedule_task_stats() RPC を削除しクライアント側統計計算に変更。Edge Function が schedule_task_runs テーブルと正しく連携', '2026-04-01'),
  ('cs-check / daily-report トリガー schema修正', 'RemoteTrigger API で cs-check・daily-report 両トリガーのプロンプトを更新。schedule_task_runs への POST 時に task_id カラムと error ステータスを使用するよう修正し実データ記録を開始', '2026-04-01')
ON CONFLICT DO NOTHING;
