-- Session daily-development 2026-04-06: 公開ギターレコーディングギャラリー実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '公開ギターレコーディングギャラリー実装',
  '全ユーザーの公開録音を一覧表示するギャラリーページ (/public-guitar-gallery) を実装。guitar-recording-studio Edge Function に public_gallery アクションを追加 (アクション追加により新規 quota 消費なし)。新着/いいね/再生数の3ソート、ページネーション、いいね機能付き。ランディングページにギャラリー導線を追加。sitemap.xml に追加。flutter analyze 0件維持。',
  '2026-04-06'
)
ON CONFLICT DO NOTHING;
