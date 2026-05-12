-- PS#4 S320: 競合3社追加 831→834社 (appsmith/thunkable/fauna)
-- SEO: "Appsmith代替"/"Thunkable代替"/"Fauna代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S320: 競合3社追加 831→834社 (appsmith/thunkable/fauna)',
  'comparison_page.dartにappsmith(OSS内部ツール管理画面ローコード/no-code/FF6D2A)/thunkable(ノーコードモバイルアプリiOS/Android/no-code/5B21B6)/fauna(グローバル分散ドキュメントリレーショナルDB/db/3A1A9A)の3社追加(831→834社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
