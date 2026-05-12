-- PS#4 S145: 競合3社追加 306→309社 (pinterest/reddit/twitch)
-- SEO: "Pinterest代替"/"Reddit代替"/"Twitch代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S145: 競合3社追加 306→309社 (pinterest/reddit/twitch)',
  'comparison_page.dartにpinterest(ビジュアルインスピレーション収集/social/E60023)/reddit(コミュニティ情報収集/social/FF4500)/twitch(ゲームライブ配信/entertainment/9146FF)の3社追加(306→309社)。新カテゴリentertainment追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
