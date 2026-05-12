-- PS#4 S341: 競合3社追加 894→897社 (pika-labs/luma-ai/kling-ai)
-- SEO: "Pika代替"/"Luma AI代替"/"Kling AI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S341: 競合3社追加 894→897社 (pika-labs/luma-ai/kling-ai)',
  'comparison_page.dartにpika-labs(AIテキスト画像to動画Pika 2.0/video-gen/7C3AED)/luma-ai(Dream Machine超リアル映像NeRF/video-gen/6D28D9)/kling-ai(快手発高品質AI動画生成/video-gen/0EA5E9)の3社追加(894→897社)。sitemap 940 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
