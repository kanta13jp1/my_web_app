-- PS#4 S399: 競合3社追加 1021→1024社 (aha-io/roadmunk/dovetail)
-- SEO: "Aha!代替"/"Roadmunk代替"/"Dovetail代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S399: 競合3社追加 1021→1024社 (aha-io/roadmunk/dovetail)',
  'comparison_page.dartにaha-io(プロダクトロードマップ戦略アイデア管理/product-management/CC3333)/roadmunk(ビジュアルプロダクトロードマップタイムライン共有/product-management/2B6CB0)/dovetail(ユーザーリサーチインサイト管理UXリポジトリ/ux-research/FF3366)の3社追加(1021→1024社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
