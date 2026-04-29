-- PS#4 S464: 競合3社追加 1213→1216社 (jetbrains/tidycal/google-workspace)
-- SEO: "JetBrains代替"/"TidyCal代替"/"Google Workspace代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S464: 競合3社追加 1213→1216社 (jetbrains/tidycal/google-workspace)',
  'comparison_page.dartにjetbrains(IntelliJ/PyCharm/WebStorm/DataGrip AI Assistant/FF318C)/tidycal(格安Calendly代替生涯29ドル無制限予約/4B5EFC)/google-workspace(Gmail/Docs/Sheets/Drive/Meet/Chat Gemini AI/4285F4)の3社追加(1213→1216社)。sitemap 1309 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
