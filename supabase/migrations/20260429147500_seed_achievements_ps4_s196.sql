-- PS#4 S196: 競合3社追加 459→462社 (lattice/15five/culture-amp)
-- SEO: "Lattice代替"/"15Five代替"/"Culture Amp代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S196: 競合3社追加 459→462社 (lattice/15five/culture-amp)',
  'comparison_page.dartにlattice(パフォーマンス+OKR/hr/6D3A9C)/15five(ウィークリーチェックイン/hr/3DA352)/culture-amp(エンゲージメントサーベイ/hr/E5A32F)の3社追加(459→462社)。sitemap 505 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
