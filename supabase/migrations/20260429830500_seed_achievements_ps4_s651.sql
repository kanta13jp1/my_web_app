-- PS#4 S651: 競合3社追加 Node.js Webフレームワーク (express/fastify/hono)
-- SEO: "Express.js代替"/"Fastify代替"/"Hono代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S651: 競合3社追加 (express/fastify/hono)',
  'comparison_page.dartにexpress(Node.js Webフレームワーク・ミニマリスト・ミドルウェア・REST API・業界標準/000000)/fastify(高速Node.js Webフレームワーク・プラグイン・スキーマバリデーション・TypeScript/2C8EBB)/hono(超高速エッジWebFW・CF Workers/Deno/Bun・JSX・日本製/E86A1E)の3社追加(1780社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
