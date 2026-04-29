-- PS#4 S539: 競合3社追加 継続 (anima/frontify/sympli)
-- SEO: "Anima代替"/"Frontify代替"/"Sympli代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S539: 競合3社追加 (anima/frontify/sympli)',
  'comparison_page.dartにanima(Figma→React/HTML変換・プロトタイプ・コラボ・デザイナー→開発者ブリッジ/FF3B7F)/frontify(ブランドガイドライン・アセット管理・コンポーネントライブラリ・DAM・コラボ/003655)/sympli(デザインハンドオフ・バージョン管理・Sketch/Figma/XD・CSS出力・開発者向け/3D9BE9)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
