-- PS#4 S405: 競合3社追加 1039→1042社 (census/bubble-io/glide-apps)
-- SEO: "Census代替"/"Bubble代替"/"Glide代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S405: 競合3社追加 1039→1042社 (census/bubble-io/glide-apps)',
  'comparison_page.dartにcensus(リバースETLデータウェアハウスSaaS同期/data-integration/7B2FBE)/bubble-io(ノーコードWebアプリケーションビルダーフルスタック/no-code/1D4ED8)/glide-apps(スプレッドシートからノーコードモバイルアプリ作成/no-code/6D28D9)の3社追加(1039→1042社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
