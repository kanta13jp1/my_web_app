-- PS#4 S310: 競合3社追加 801→804社 (personio/hibob/remote-com)
-- SEO: "Personio代替"/"HiBob代替"/"Remote.com代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S310: 競合3社追加 801→804社 (personio/hibob/remote-com)',
  'comparison_page.dartにpersonio(欧州中小企業向けHR管理採用給与/hrtech/5C4EFF)/hibob(モダン中規模企業HRIS人材管理/hrtech/FF6B35)/remote-com(グローバルリモート雇用EOR/hrtech/0F766E)の3社追加(801→804社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
