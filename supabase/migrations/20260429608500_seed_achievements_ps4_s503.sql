-- PS#4 S503: 競合3社追加 継続 (darktable/rawtherapee/stencil)
-- SEO: "Darktable代替"/"RawTherapee代替"/"Stencil代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S503: 競合3社追加 (darktable/rawtherapee/stencil)',
  'comparison_page.dartにdarktable(OSS RAW現像非破壊編集プロ色管理Linux/Mac/Win/212121)/rawtherapee(OSS高機能RAW現像詳細色制御バッチ処理/795548)/stencil(SNSグラフィック高速作成2M写真1000フォントスケジュール/FF5722)の3社追加。sitemap 1426 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
