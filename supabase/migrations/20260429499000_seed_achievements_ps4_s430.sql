-- PS#4 S430: 競合3社追加 1114→1117社 (vinted/depop/apple-music)
-- SEO: "Vinted代替"/"Depop代替"/"Apple Music代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S430: 競合3社追加 1114→1117社 (vinted/depop/apple-music)',
  'comparison_page.dartにvinted(欧州最大C2C中古ファッションVinted Go/resale/09B1BA)/depop(Gen ZファッションリセールEtsy傘下ヴィンテージ/resale/FF4040)/apple-music(1億曲ロスレス空間オーディオApple One/music/FC3C44)の3社追加(1114→1117社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
