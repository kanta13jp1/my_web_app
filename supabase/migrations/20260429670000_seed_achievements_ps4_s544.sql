-- PS#4 S544: 競合3社追加 継続 (codepen/jsfiddle/dagger-io)
-- SEO: "CodePen代替"/"JSFiddle代替"/"Dagger代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S544: 競合3社追加 (codepen/jsfiddle/dagger-io)',
  'comparison_page.dartにcodepen(フロントエンドPen・HTML/CSS/JS・インスピレーション・コミュニティ・無料/47CF73)/jsfiddle(オンラインJS/CSS/HTMLテスト・コラボ・ライブラリ・バグ再現・シェア/0084FF)/dagger-io(ポータブルパイプライン・コンテナファースト・任意CI互換・GraphQL API・OSS/1A1A2E)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
