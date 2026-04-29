-- PS#4 S316: 競合3社追加 819→822社 (budibase/flutterflow/iterable)
-- SEO: "Budibase代替"/"FlutterFlow代替"/"Iterable代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S316: 競合3社追加 819→822社 (budibase/flutterflow/iterable)',
  'comparison_page.dartにbudibase(OSS ローコード内部ツールワークフロー/no-code/6B21A8)/flutterflow(ビジュアルFlutterアプリ構築/no-code/54C5F8)/iterable(クロスチャネルマーケオートメーション/email-marketing/7C3AED)の3社追加(819→822社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
