-- PS#4 S622: 競合3社追加 ステータスページ/死活監視 (freshstatus/betteruptime/checkly)
-- SEO: "Freshstatus代替"/"Better Uptime代替"/"Checkly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S622: 競合3社追加 (freshstatus/betteruptime/checkly)',
  'comparison_page.dartにfreshstatus(無料ステータスページ・インシデント管理・Freshdesk統合/25B75E)/betteruptime(死活監視・インシデントタイムライン・オンコール・スクリーンショット/3ECF8E)/checkly(API監視・E2Eテスト・Playwright統合・コードファースト/45C8B4)の3社追加(1690社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
