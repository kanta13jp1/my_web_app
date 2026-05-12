-- PS#4 S642: 競合3社追加 CSSフレームワーク/UIコンポーネント (tailwind/bootstrap/material-ui)
-- SEO: "Tailwind CSS代替"/"Bootstrap代替"/"Material UI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S642: 競合3社追加 (tailwind/bootstrap/material-ui)',
  'comparison_page.dartにtailwind(ユーティリティファーストCSS・JIT・クラスベース・カスタマイズ/06B6D4)/bootstrap(CSS/JSコンポーネント・グリッドシステム・テーマ・jQuery非依存/7952B3)/material-ui(Google Material Design・Reactコンポーネント・テーマ・アクセシビリティ/0081CB)の3社追加(1753社)。sitemap 1849 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
