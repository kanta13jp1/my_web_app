-- PS#4 S517: 競合3社追加 継続 (boomi/hevo-data/supermetrics)
-- SEO: "Boomi代替"/"Hevo Data代替"/"Supermetrics代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S517: 競合3社追加 (boomi/hevo-data/supermetrics)',
  'comparison_page.dartにboomi(クラウドネイティブiPaaS・2000+コネクタ・AI Suggest・Dell Technologies分離・ローコード/009BDE)/hevo-data(ノーコードETL・150+コネクタ・リアルタイム同期・自動スキーマ管理・SMB向け/8B5CF6)/supermetrics(マーケティングデータ統合・BigQuery/Sheets/Looker・100+ソース・広告データ自動化/3B82F6)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
