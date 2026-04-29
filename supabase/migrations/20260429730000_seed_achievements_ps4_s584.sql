-- PS#4 S584: 競合3社追加 継続 (matillion/azure-data-factory/aws-glue)
-- SEO: "Matillion代替"/"Azure Data Factory代替"/"AWS Glue代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S584: 競合3社追加 (matillion/azure-data-factory/aws-glue)',
  'comparison_page.dartにmatillion(クラウドETL・ノーコード/コード・Snowflake/Databricks/Redshift対応/00A98F)/azure-data-factory(クラウドETL/ELT・100+コネクター・Synapse統合・Azure/0078D4)/aws-glue(サーバーレスETL・データカタログ・Spark・AWS Data Lake/FF9900)の3社追加(1573社)。sitemap 1669 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
