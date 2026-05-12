-- PS#4 S419: 競合3社追加 1081→1084社 (hims-hers/noom/betterhelp)
-- SEO: "Hims & Hers代替"/"Noom代替"/"BetterHelp代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S419: 競合3社追加 1081→1084社 (hims-hers/noom/betterhelp)',
  'comparison_page.dartにhims-hers(DtoC処方箋ウェルネスオンライン診療/dtoc-health/1A1A2E)/noom(AI体重管理行動変容プログラムコーチング/wellness/88C057)/betterhelp(オンラインセラピーメンタルヘルスカウンセリング/mental-health/4CAF84)の3社追加(1081→1084社)。sitemap 1174 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
