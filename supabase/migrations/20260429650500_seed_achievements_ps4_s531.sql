-- PS#4 S531: 競合3社追加 1413→1422社 (nolt/featurebase/supahub)
-- SEO: "Nolt代替"/"Featurebase代替"/"Supahub代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S531: 競合3社追加 1413→1422社 (nolt/featurebase/supahub)',
  'comparison_page.dartにnolt(シンプル機能投票ボード・公開ロードマップ・チェンジログ・ブランドカスタム・Zapier連携/4A90E2)/featurebase(プロダクトフィードバックハブ・投票・ロードマップ・NPS・インタビュー統合/5856D6)/supahub(カスタマーフィードバックポータル・公開ロードマップ・チェンジログ・ウィジェット・低価格/FF5A5F)の3社追加(1413→1422社)。sitemap 1516 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
