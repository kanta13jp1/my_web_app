-- PS#4 S156: 競合3社追加 339→342社 (streaks/productive/daylio)
-- SEO: "Streaks代替"/"Productive代替"/"Daylio代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S156: 競合3社追加 339→342社 (streaks/productive/daylio)',
  'comparison_page.dartにstreaks(12習慣連続トラッカー/habit/FF3B30)/productive(AI習慣スコア分析/habit/5856D6)/daylio(絵文字気分日記/habit/9C27B0)の3社追加(339→342社)。全ファイル348統一。sitemap 638 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
