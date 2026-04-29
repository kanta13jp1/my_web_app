-- PS#4 S658: 競合3社追加 API仕様/Webサーバー (openapi/caddy/varnish)
-- SEO: "OpenAPI代替"/"Caddy代替"/"Varnish代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S658: 競合3社追加 (openapi/caddy/varnish)',
  'comparison_page.dartにopenapi(REST API仕様標準・Swagger・YAML/JSON定義・コード生成・業界標準/85EA2D)/caddy(自動HTTPS Webサーバー・Let''s Encrypt・HTTP/3・リバースプロキシ/00ADD8)/varnish(高速HTTPキャッシュ・リバースプロキシ・VCL・Webアクセラレーター/009BDE)の3社追加(1798社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
