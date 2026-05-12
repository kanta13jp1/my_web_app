-- PS#4 S291: 競合3社追加 744→747社 (meltwater/brandwatch/sprinklr)
-- SEO: "Meltwater代替"/"Brandwatch代替"/"Sprinklr代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S291: 競合3社追加 744→747社 (meltwater/brandwatch/sprinklr)',
  'comparison_page.dartにmeltwater(メディア監視PRインサイト/pr/0066FF)/brandwatch(ディープソーシャルリスニング消費者インテリジェンス/pr/512DA8)/sprinklr(エンタープライズ統合CXM/social/00B4E5)の3社追加(744→747社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
