-- Session daily-dev#4: T-1第4弾投稿 + abstinence_slips テーブル + 思考妨害UI確認
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 第4弾: Claude Code Schedule 自動ブログ投稿', 'blog-auto-publisher EFで2026-04-10.md をdev.to に自動投稿。Qiitaは障害のためスキップ。', '2026-04-11'),
  ('abstinence_slips テーブル作成', 'THOUGHT_INTERRUPT_ELIMINATOR設計書に従いabstinence_slipsテーブルを作成。RLS + item_id/slipped_atインデックス付き。', '2026-04-11')
ON CONFLICT DO NOTHING;
