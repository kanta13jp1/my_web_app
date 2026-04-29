-- PS#4 S187: 競合3社追加 432→435社 (heap/segment/rudderstack)
-- SEO: "Heap代替"/"Segment代替"/"RudderStack代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S187: 競合3社追加 432→435社 (heap/segment/rudderstack)',
  'comparison_page.dartにheap(自動キャプチャ分析/analytics/FF6B81)/segment(Twilio CDP/analytics/52BD94)/rudderstack(OSS CDP/analytics/1D232D)の3社追加(432→435社)。sitemap 478 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
