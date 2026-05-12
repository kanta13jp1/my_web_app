-- PS#4 S139: 競合3社追加 288→291社 (blender/paint-net/coreldraw)
-- SEO: "Blender代替"/"Paint.NET代替"/"CorelDRAW代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S139: 競合3社追加 288→291社 (blender/paint-net/coreldraw)',
  'comparison_page.dartにblender(無料3DCGアニメーション/3d/E87D0D)/paint-net(Windows無料画像編集/design/0078D7)/coreldraw(プロ印刷ロゴデザイン/design/009A44)の3社追加(288→291社)。新カテゴリ3d追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
