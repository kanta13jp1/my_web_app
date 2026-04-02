-- PowerShell #8 + #9 セッション実績 (統合版)
-- 000070/000080 との重複を避けるため 000900 に統合
-- ON CONFLICT DO NOTHING により重複 INSERT は無害

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('schedule-task-monitor スキーマ完全修正', 'task_name→task_id カラム名修正・failure→error ステータス正規化・存在しない get_schedule_task_stats() RPC を削除しクライアント側統計計算に変更。Edge Function が schedule_task_runs テーブルと正しく連携', '2026-04-01'),
  ('cs-check / daily-report トリガー schema修正', 'RemoteTrigger API で cs-check・daily-report 両トリガーのプロンプトを更新。schedule_task_runs への POST 時に task_id カラムと error ステータスを使用するよう修正し実データ記録を開始', '2026-04-01'),
  ('migration 000020/000040/000050 重複バージョン修正 (PS#9)', '並列インスタンス間の migration version 衝突を複数回修正。PS8→000070、PS8+PS9→000900 にリナンバー。supabase db push CI/CD 正常稼働を維持', '2026-04-01'),
  ('stale docs 整理 — docs/index.ts 削除', 'local-election-intelligence/index.ts の古い不完全なコピーが docs/index.ts に誤配置されていた。git rm で削除しリポジトリをクリーンに保つ', '2026-04-01'),
  ('Schedule 4タスク正常稼働確認', 'cs-check(毎時)/daily-report(毎日)/blog-draft(毎日)/weekly-sns-draft(毎週月) の全4トリガーが enabled かつ correct task_id スキーマで稼働中。flutter analyze 0/deno lint 0 維持', '2026-04-01')
ON CONFLICT DO NOTHING;
