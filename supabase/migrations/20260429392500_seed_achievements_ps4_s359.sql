-- PS#4 S359: 競合3社追加 948→951社 (ecamm-live/switcher-studio/wirecast)
-- SEO: "Ecamm Live代替"/"Switcher Studio代替"/"Wirecast代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S359: 競合3社追加 948→951社 (ecamm-live/switcher-studio/wirecast)',
  'comparison_page.dartにecamm-live(MacライブストリーミングプロアプリZoom/YouTube/streaming/0071E3)/switcher-studio(iPhoneマルチカメラライブ動画制作/streaming/7C3AED)/wirecast(プロライブストリーミングプロダクション/streaming/1A1A2E)の3社追加(948→951社)。sitemap 994 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
