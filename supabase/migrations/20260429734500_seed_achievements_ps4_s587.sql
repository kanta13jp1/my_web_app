-- PS#4 S587: 競合3社追加 継続 (octopai/erwin/data-world)
-- SEO: "Octopai代替"/"erwin代替"/"data.world代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S587: 競合3社追加 (octopai/erwin/data-world)',
  'comparison_page.dartにoctopai(自動データリネージ・クロスBI検索・メタデータ・MS Fabric対応/2196F3)/erwin(データカタログ/ガバナンス/モデリング・エンタープライズ・Quest Software/0F4C81)/data-world(クラウドカタログ・コラボレーション・SPARQL・知識グラフ/00BFA5)の3社追加(1582社)。sitemap 1678 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
