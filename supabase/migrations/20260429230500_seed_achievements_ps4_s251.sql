-- PS#4 S251: 競合3社追加 624→627社 (beautiful-ai/tome/fastmail)
-- SEO: "Beautiful.ai代替"/"Tome代替"/"Fastmail代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S251: 競合3社追加 624→627社 (beautiful-ai/tome/fastmail)',
  'comparison_page.dartにbeautiful-ai(AI自動レイアウトプレゼン/presentation/8B008B)/tome(AIストーリーテリング/presentation/7C3AED)/fastmail(高速プライバシーメール/email/007BFF)の3社追加(624→627社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
