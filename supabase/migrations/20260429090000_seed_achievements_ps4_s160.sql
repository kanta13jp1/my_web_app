-- PS#4 S160: 競合3社追加 351→354社 (couch-to-5k/zwift/nike-run)
-- SEO: "Couch to 5K代替"/"Zwift代替"/"Nike Run Club代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S160: 競合3社追加 351→354社 (couch-to-5k/zwift/nike-run)',
  'comparison_page.dartにcouch-to-5k(初心者ランニング/fitness/27AE60)/zwift(バーチャルサイクリング/fitness/FF6B1C)/nike-run(GPS+コーチ/fitness/111111)の3社追加(351→354社)。sitemap 396 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
