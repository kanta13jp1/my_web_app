-- Session Windows版#30: MULTI_INSTANCE_COORDINATION 更新 + T-1第5弾 Zenn投稿
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('MULTI_INSTANCE_COORDINATION 最新化', 'VSCode版ページ数195→205・PowerShell版CI/CD 13→16本に更新', '2026-04-11'),
  ('T-1 第5弾: Zenn 通知センター記事公開', '2026-03-31-notification-center.md を Zenn へ公開 (dart:html→package:web移行パターン)。blog-publish.yml の title抽出・GH006問題も特定', '2026-04-11')
ON CONFLICT DO NOTHING;
