-- PS#4 S649: 競合3社追加 ORM (sequelize/mongoose/kysely)
-- SEO: "Sequelize代替"/"Mongoose代替"/"Kysely代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S649: 競合3社追加 (sequelize/mongoose/kysely)',
  'comparison_page.dartにsequelize(Node.js ORM・多DB対応・マイグレーション・アソシエーション/03AFEF)/mongoose(MongoDB ODM・スキーマ定義・バリデーション・ミドルウェア/800000)/kysely(型安全SQLクエリビルダー・TypeScript・零依存・多DB・エッジ/3B82F6)の3社追加(1771社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
