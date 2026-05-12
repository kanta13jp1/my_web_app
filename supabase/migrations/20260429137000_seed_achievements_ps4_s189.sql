-- PS#4 S189: 競合3社追加 438→441社 (pendo/appcues/userpilot)
-- SEO: "Pendo代替"/"Appcues代替"/"Userpilot代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S189: 競合3社追加 438→441社 (pendo/appcues/userpilot)',
  'comparison_page.dartにpendo(プロダクト分析+ガイド/product/FF4785)/appcues(ノーコードオンボーディング/product/5A30DB)/userpilot(プロダクト成長PF/product/0B5CFF)の3社追加(438→441社)。sitemap 484 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
