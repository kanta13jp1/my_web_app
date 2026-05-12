-- PS#4 S90: seo-shell動的更新 + og:image:alt + navリンク改善
-- S90a: vsMatch ブロックで seo-shell h1/desc をcompany名に書き換え (非JSクローラー対応)
-- S90b: vs-*ページの og:image:alt / twitter:image:alt を company名入りに更新
-- S90c: seo-shell nav に /competitors (174社比較) /ai-university リンク追加

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S90: vs-*ページ seo-shell動的更新 + og:image:alt改善',
  'vsMatchブロックでseo-shellのh1/descをcompany名に書き換え(非JSクローラーが各vs-*ページを個別コンテンツとして認識)。og:image:alt/twitter:image:altをcompany名+比較に更新。seo-shell navに/competitors(174社)/ai-universityリンク追加。PS#4 SEO全施策完結。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
