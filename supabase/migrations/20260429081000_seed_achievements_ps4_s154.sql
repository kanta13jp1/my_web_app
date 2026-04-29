-- PS#4 S154: 競合3社追加 333→336社 (notion-calendar/apple-health/peloton)
-- SEO: "Notion Calendar代替"/"Apple ヘルスケア代替"/"Peloton代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S154: 競合3社追加 333→336社 (notion-calendar/apple-health/peloton)',
  'comparison_page.dartにnotion-calendar(Notion統合スマートカレンダー/calendar/222222)/apple-health(iOS統合健康ダッシュボード/health/FF2D55)/peloton(ライブフィットネスストリーミング/fitness/EF0028)の3社追加(333→336社)。全ファイル339統一。sitemap 629 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
