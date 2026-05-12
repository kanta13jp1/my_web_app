-- PS#4 S282: 競合3社追加 717→720社 (hopin/bizzabo/gather-town)
-- SEO: "Hopin代替"/"Bizzabo代替"/"Gather代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S282: 競合3社追加 717→720社 (hopin/bizzabo/gather-town)',
  'comparison_page.dartにhopin(バーチャルハイブリッドイベント/events/7B4FD0)/bizzabo(エンタープライズイベント管理/events/1A3B5C)/gather-town(ピクセルアートバーチャルオフィス/collab/7742FF)の3社追加(717→720社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
