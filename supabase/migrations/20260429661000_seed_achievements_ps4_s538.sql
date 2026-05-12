-- PS#4 S538: 競合3社追加 継続 (justinmind/avocode/supernova)
-- SEO: "Justinmind代替"/"Avocode代替"/"Supernova代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S538: 競合3社追加 (justinmind/avocode/supernova)',
  'comparison_page.dartにjustinmind(高機能プロトタイピング・複雑インタラクション・データ駆動・HTML出力・エンタープライズ/E63946)/avocode(デザインハンドオフ・CSS/Swift/Androidコード生成・Sketch/Figma/PSD対応/7B2FBE)/supernova(デザイン→コード自動変換・デザインシステム管理・Figma連携・React/Flutter/SwiftUI/9B59B6)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
