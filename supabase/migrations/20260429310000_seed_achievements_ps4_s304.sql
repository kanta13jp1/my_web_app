-- PS#4 S304: 競合3社追加 783→786社 (gather/kumospace/wonder)
-- SEO: "Gather代替"/"Kumospace代替"/"Wonder代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S304: 競合3社追加 783→786社 (gather/kumospace/wonder)',
  'comparison_page.dartにgather(バーチャルオフィス2Dメタバースリモートワーク/virtual-office/7C3AED)/kumospace(バーチャルイベントオフィス空間/virtual-office/0EA5E9)/wonder(バーチャルイベントネットワーキング/virtual-office/EC4899)の3社追加(783→786社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
