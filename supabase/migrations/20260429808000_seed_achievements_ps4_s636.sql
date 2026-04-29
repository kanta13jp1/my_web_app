-- PS#4 S636: 競合3社追加 開発者ドキュメント (readme-io/swagger-ui/redoc)
-- SEO: "ReadMe代替"/"Swagger UI代替"/"ReDoc代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S636: 競合3社追加 (readme-io/swagger-ui/redoc)',
  'comparison_page.dartにreadme-io(開発者ドキュメントSaaS・APIリファレンス・インタラクティブ/018EF5)/swagger-ui(OpenAPI可視化・インタラクティブドキュメント・APIテスト・業界標準/85EA2D)/redoc(OpenAPIドキュメント・3パネルレイアウト・レスポンシブ・埋め込み可/E53935)の3社追加(1735社)。sitemap 1831 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
