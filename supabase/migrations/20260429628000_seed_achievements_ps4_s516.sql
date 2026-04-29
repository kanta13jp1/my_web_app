-- PS#4 S516: 競合3社追加 1368→1377社 (stitch-data/informatica/mulesoft)
-- SEO: "Stitch Data代替"/"Informatica代替"/"MuleSoft代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S516: 競合3社追加 1368→1377社 (stitch-data/informatica/mulesoft)',
  'comparison_page.dartにstitch-data(Talend傘下クラウドETL・130+コネクタ・ELTパイプライン・デベロッパー向け/4169E1)/informatica(エンタープライズデータ統合・IDMC・AI PowerCenter・データ品質・ガバナンス/FF6600)/mulesoft(Salesforce傘下API統合プラットフォーム・Anypoint・1000+コネクタ・iPaaS/00A1E0)の3社追加(1368→1377社)。sitemap 1471 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
