-- PS#4 S644: 競合3社追加 UIコンポーネント/CSSエンジン (ant-design/daisyui/unocss)
-- SEO: "Ant Design代替"/"daisyUI代替"/"UnoCSS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S644: 競合3社追加 (ant-design/daisyui/unocss)',
  'comparison_page.dartにant-design(エンタープライズReact・60+コンポーネント・Alibaba製・デザインシステム/1677FF)/daisyui(TailwindCSSコンポーネント・クラスベース・テーマ35+・軽量/570DF8)/unocss(超高速原子CSSエンジン・オンデマンド・Tailwind互換・プリセット/333333)の3社追加(1753社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
