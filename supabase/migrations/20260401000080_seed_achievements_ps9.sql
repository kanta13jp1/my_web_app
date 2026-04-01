-- PowerShell #9 セッション実績
-- migration 000020重複修正・stale docs整理・Schedule 4トリガー稼働確認

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('migration 000020 重複バージョン修正 (PS#9)', 'VSCodeインスタンスと PowerShell#8 が同時に 20260401000020_seed_ ファイルを作成して重複。PS#8 ファイルを 20260401000040_ にリナンバー。supabase db push の重複キーエラーを防止', '2026-04-01'),
  ('stale docs 整理 — docs/index.ts 削除', 'local-election-intelligence/index.ts の古い不完全なコピーが docs/index.ts に誤配置されていた。git rm で削除しリポジトリをクリーンに保つ', '2026-04-01'),
  ('Schedule 4タスク正常稼働確認', 'cs-check(毎時)/daily-report(毎日)/blog-draft(毎日)/weekly-sns-draft(毎週月) の全4トリガーが enabled かつ correct task_id スキーマで稼働中。flutter analyze 0/deno lint 0 維持', '2026-04-01')
ON CONFLICT DO NOTHING;
