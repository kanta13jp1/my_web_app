-- PS#4 S322: 競合3社追加 837→840社 (scrimba/domestika/treehouse)
-- SEO: "Scrimba代替"/"Domestika代替"/"Treehouse代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S322: 競合3社追加 837→840社 (scrimba/domestika/treehouse)',
  'comparison_page.dartにscrimba(インタラクティブコーディング学習スクリーンキャスト/learning/5C62FF)/domestika(クリエイター向けデザインイラスト学習/learning/FF5C6A)/treehouse(Web開発デザインオンライン学習/learning/5FCF80)の3社追加(837→840社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
