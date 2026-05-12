-- PS#4 S352: 競合3社追加 927→930社 (getimg-ai/nightcafe/starryai)
-- SEO: "getimg.ai代替"/"NightCafe代替"/"Starryai代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S352: 競合3社追加 927→930社 (getimg-ai/nightcafe/starryai)',
  'comparison_page.dartにgetimg-ai(AI画像生成編集ファインチューニングAll-in-One/image-gen/7C3AED)/nightcafe(AIアート生成クリエイターコミュニティ/image-gen/1E1B4B)/starryai(AIアートNFTモバイルアプリ/image-gen/4F46E5)の3社追加(927→930社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
