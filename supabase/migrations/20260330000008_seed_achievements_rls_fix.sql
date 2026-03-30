-- RLSポリシー修正と今日の実績シード 2026-03-30

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'blog_posts RLSポリシー修正 (is_admin対応)',
    'blog_postsテーブルのRLSポリシーが存在しないrole列を参照していたバグを修正。is_admin = trueを使ったポリシーに変更し、service_roleによる完全アクセスポリシーも追加。',
    '2026-03-30'
  ),
  (
    '4インスタンス並列開発 競合防止ガイド作成',
    'VSCode/Web/Windows/PowerShell 4インスタンスの役割分担と競合防止手順をdocs/MULTI_INSTANCE_COORDINATION.mdとしてドキュメント化。git pull --rebaseルールとRLS設計原則を明記。',
    '2026-03-30'
  )
ON CONFLICT (title) DO NOTHING;
