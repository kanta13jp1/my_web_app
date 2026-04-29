-- PS#4 S363: 競合3社追加 960→963社 (marvel/proto-io/axure)
-- SEO: "Marvel代替"/"Proto.io代替"/"Axure代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S363: 競合3社追加 960→963社 (marvel/proto-io/axure)',
  'comparison_page.dartにmarvel(プロトタイプデザインコラボアニメーション/design-proto/E52E34)/proto-io(高度インタラクティブプロトタイプアニメーション/design-proto/6B48C8)/axure(高機能ワイヤフレーム条件分岐プロトタイプ/design-proto/FF4B00)の3社追加(960→963社)。sitemap 1012 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
