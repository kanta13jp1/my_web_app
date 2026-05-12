-- PS#4 S578: 競合3社追加 継続 (helpcrunch/tawk/useresponse)
-- SEO: "HelpCrunch代替"/"tawk.to代替"/"UseResponse代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S578: 競合3社追加 (helpcrunch/tawk/useresponse)',
  'comparison_page.dartにhelpcrunch(オールインワンCS・ライブチャット・メール・ポップアップ・ナレッジベース/F65314)/tawk(完全無料ライブチャット・無制限使用・エージェントアプリ/03A84E)/useresponse(フィードバック+CS統合・アイデア管理・コミュニティ・セルフホスト/1A73E8)の3社追加(1555社)。sitemap 1651 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
