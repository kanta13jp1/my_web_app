-- PS#4 S652: 競合3社追加 TypeScript/Python Webフレームワーク (nestjs/django/flask)
-- SEO: "NestJS代替"/"Django代替"/"Flask代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S652: 競合3社追加 (nestjs/django/flask)',
  'comparison_page.dartにnestjs(TypeScript Node.js・Angular風DI・デコレータ・モジュール・マイクロサービス/E0234E)/django(Python Webフレームワーク・バッテリー同梱・ORM・管理画面・セキュリティ/092E20)/flask(Python マイクロWebFW・シンプル・拡張可能・Jinja2・Werkzeug/000000)の3社追加(1780社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
