-- PS#4 S659: 競合3社追加 APIゲートウェイ/サーバー/ツール (apisix/nginx-unit/swagger)
-- SEO: "APISIX代替"/"NGINX Unit代替"/"Swagger代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S659: 競合3社追加 (apisix/nginx-unit/swagger)',
  'comparison_page.dartにapisix(Apache クラウドネイティブAPIゲートウェイ・動的ルーティング・プラグイン/E8512A)/nginx-unit(動的アプリケーションサーバー・多言語・REST API制御/009639)/swagger(OpenAPI UIツール・インタラクティブドキュメント・Codegen/85EA2D)の3社追加(1798社)。sitemap 1894 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
