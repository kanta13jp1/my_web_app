-- PS#4 S124: 競合3社追加 243→246社 (confluence/freshworks/pandadoc)
-- SEO: "Confluence代替"/"Freshworks代替"/"PandaDoc代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S124: 競合3社追加 243→246社 (confluence/freshworks/pandadoc)',
  'comparison_page.dartにconfluence(チームWiki/documentation/0052CC)/freshworks(CRM+サポート/crm/00A2FF)/pandadoc(電子署名・契約書/documents/30C454)の3社追加(243→246社)。新カテゴリdocumentation/documents追加。competitorMeta/sitemap/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
