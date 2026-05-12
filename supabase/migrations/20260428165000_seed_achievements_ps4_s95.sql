-- PS#4 S95: vs-*ページにブレッドクラムナビ追加
-- SEO流入ユーザー向け: 自分株式会社 / 競合比較 / {Company}

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S95: vs-*全174社ページにブレッドクラムナビ追加',
  'SEO流入ユーザー(Google検索経由)向けに各vs-*ページ上部に「自分株式会社 / 競合比較 / {Company}」パンくずナビを追加。/ホームと/competitorsへのリンクを提供。WrapCrossAlignment.centerでレスポンシブ対応。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
