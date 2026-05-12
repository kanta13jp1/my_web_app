-- PS#4 S306: 競合3社追加 789→792社 (restream/mmhmm/airmeet)
-- SEO: "Restream代替"/"mmhmm代替"/"Airmeet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S306: 競合3社追加 789→792社 (restream/mmhmm/airmeet)',
  'comparison_page.dartにrestream(マルチプラットフォーム同時ライブ配信/streaming/7C3AED)/mmhmm(バーチャル背景プレゼン演出ビデオ/video-comm/FF6B6B)/airmeet(バーチャルイベントコミュニティ/virtual-event/0EA5E9)の3社追加(789→792社)。sitemap 841 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
