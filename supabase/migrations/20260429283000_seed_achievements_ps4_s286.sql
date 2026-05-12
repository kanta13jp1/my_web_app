-- PS#4 S286: 競合3社追加 729→732社 (icims/beamery/cornerstone)
-- SEO: "iCIMS代替"/"Beamery代替"/"Cornerstone代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S286: 競合3社追加 729→732社 (icims/beamery/cornerstone)',
  'comparison_page.dartにicims(エンタープライズATS採用プラットフォーム/ats/0065A3)/beamery(AIタレントライフサイクル採用CRM/hr/7B2D8B)/cornerstone(エンタープライズHCM学習パフォーマンス/hcm/0D2240)の3社追加(729→732社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
