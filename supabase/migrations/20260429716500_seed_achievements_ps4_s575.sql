-- PS#4 S575: 競合3社追加 継続 (easyvista/invgate/happyfox)
-- SEO: "EasyVista代替"/"InvGate代替"/"HappyFox代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S575: 競合3社追加 (easyvista/invgate/happyfox)',
  'comparison_page.dartにeasyvista(ITSM・ノーコード・ESM・AI自動化・ナレッジ管理/0070CC)/invgate(ITSM・ITAM・IT資産管理・中規模向け統合/7C3AED)/happyfox(ヘルプデスク・AI自動化・多チャネル・ITSM統合/FF6B35)の3社追加(1546社)。sitemap 1642 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
