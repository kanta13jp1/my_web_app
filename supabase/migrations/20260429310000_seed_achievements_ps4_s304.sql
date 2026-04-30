-- PS#4 S304: competitor additions for gather/kumospace/wonder

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S304: competitor additions for gather/kumospace/wonder',
  'Added gather, kumospace, and wonder entries to comparison_page.dart with virtual-office metadata and brand colors.',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
