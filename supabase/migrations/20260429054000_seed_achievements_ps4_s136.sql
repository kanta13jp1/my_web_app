-- PS#4 S136: 競合3社追加 279→282社 (affinity-designer/procreate/clip-studio)
-- SEO: "Affinity Designer代替"/"Procreate代替"/"CLIP STUDIO代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S136: 競合3社追加 279→282社 (affinity-designer/procreate/clip-studio)',
  'comparison_page.dartにaffinity-designer(ベクターグラフィック/design/1B2E4E)/procreate(iPad専用デジタルイラスト/design/2D2D2D)/clip-studio(マンガイラスト制作/design/0099D6)の3社追加(279→282社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
