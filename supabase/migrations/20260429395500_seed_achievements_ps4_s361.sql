-- PS#4 S361: 競合3社追加 954→957社 (circle-so/bettermode/discourse)
-- SEO: "Circle代替"/"Bettermode代替"/"Discourse代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S361: 競合3社追加 954→957社 (circle-so/bettermode/discourse)',
  'comparison_page.dartにcircle-so(クリエイターコミュニティ会員制コース/community/1F2937)/bettermode(顧客ブランドコミュニティSaaS/community/6D28D9)/discourse(OSS コミュニティフォーラム討議/community/5C7CFA)の3社追加(954→957社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
