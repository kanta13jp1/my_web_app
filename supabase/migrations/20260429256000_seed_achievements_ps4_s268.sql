-- PS#4 S268: 競合3社追加 675→678社 (mindmeister/xmind/omnivore)
-- SEO: "MindMeister代替"/"XMind代替"/"Omnivore代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S268: 競合3社追加 675→678社 (mindmeister/xmind/omnivore)',
  'comparison_page.dartにmindmeister(オンラインマインドマップコラボ/mindmap/3D9BE9)/xmind(デスクトップ×クラウドマインドマップ/mindmap/0052CC)/omnivore(OSSリーダービリティ後で読む/reading/59A608)の3社追加(675→678社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
