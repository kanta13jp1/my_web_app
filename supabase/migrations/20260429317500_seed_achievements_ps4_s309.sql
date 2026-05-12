-- PS#4 S309: 競合3社追加 798→801社 (taleo/smartrecruiters/jobvite)
-- SEO: "Oracle Taleo代替"/"SmartRecruiters代替"/"Jobvite代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S309: 競合3社追加 798→801社 (taleo/smartrecruiters/jobvite)',
  'comparison_page.dartにtaleo(Oracle製エンタープライズ採用HCM/hrtech/F80000)/smartrecruiters(タレントアクイジションスイート/hrtech/2563EB)/jobvite(AIパワード採用オンボーディング/hrtech/16A34A)の3社追加(798→801社)。sitemap 850 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
