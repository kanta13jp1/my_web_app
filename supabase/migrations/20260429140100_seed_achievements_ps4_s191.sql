-- PS#4 S191: 競合3社追加 444→447社 (buzzsprout/riverside-fm/transistor-fm)
-- SEO: "Buzzsprout代替"/"Riverside.fm代替"/"Transistor代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S191: 競合3社追加 444→447社 (buzzsprout/riverside-fm/transistor-fm)',
  'comparison_page.dartにbuzzsprout(ポッドキャストホスト/podcast/F14E3B)/riverside-fm(リモート収録/podcast/5B21B6)/transistor-fm(チームPodcast/podcast/6B3CEA)の3社追加(444→447社)。sitemap 490 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
