-- PS#4 S648: 競合3社追加 ORM/クエリビルダー (prisma/drizzle/typeorm)
-- SEO: "Prisma代替"/"Drizzle ORM代替"/"TypeORM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S648: 競合3社追加 (prisma/drizzle/typeorm)',
  'comparison_page.dartにprisma(次世代Node.js ORM・型安全・自動生成・マイグレーション/2D3748)/drizzle(TypeScript SQLクエリビルダー・型安全・軽量・エッジランタイム/C5F74F)/typeorm(TypeScript ORM・デコレータ・アクティブレコード/データマッパー/E83E8C)の3社追加(1771社)。sitemap 1867 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
