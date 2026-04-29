-- PS#4 S650: 競合3社追加 Java/Python ORM (sqlalchemy/hibernate/mikro-orm)
-- SEO: "SQLAlchemy代替"/"Hibernate代替"/"MikroORM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S650: 競合3社追加 (sqlalchemy/hibernate/mikro-orm)',
  'comparison_page.dartにsqlalchemy(Python ORM/SQL toolkit・宣言的マッピング・非同期・多DB/D4380D)/hibernate(Java ORM・JPA実装・HQL/JPQL・Spring統合・エンタープライズ/59666C)/mikro-orm(TypeScript ORM・DataMapper・Unit of Work・NestJS統合/5B21B6)の3社追加(1771社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
