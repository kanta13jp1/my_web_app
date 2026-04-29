-- PS#4 S519: 競合3社追加 1377→1386社 (pentaho/jaspersoft/alteryx)
-- SEO: "Pentaho代替"/"JasperReports代替"/"Alteryx代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S519: 競合3社追加 1377→1386社 (pentaho/jaspersoft/alteryx)',
  'comparison_page.dartにpentaho(Hitachi Vantara傘下ETL/BI・PDI・Kettle・OSS・エンタープライズデータ統合/2E6DA4)/jaspersoft(TIBCO傘下OSS BIプラットフォーム・JasperReports・PixelPerfectレポーティング・埋め込みBI/005F87)/alteryx(セルフサービスデータ分析・AutoML・コードレス・RPA統合・ビジネスアナリスト向け/0078C8)の3社追加(1377→1386社)。sitemap 1480 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
