-- PS#4 S314: 競合3社追加 813→816社 (gladly/ziprecruiter/sendible)
-- SEO: "Gladly代替"/"ZipRecruiter代替"/"Sendible代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S314: 競合3社追加 813→816社 (gladly/ziprecruiter/sendible)',
  'comparison_page.dartにgladly(人中心カスタマーサービス/support/FF6B35)/ziprecruiter(AI採用マッチング求人掲載/hrtech/167AFF)/sendible(エージェンシー向けSNS管理/social/E8323C)の3社追加(813→816社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
