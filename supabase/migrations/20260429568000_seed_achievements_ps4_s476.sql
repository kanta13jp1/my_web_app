-- PS#4 S476: 競合3社追加 1249→1252社 (nocodb/baserow/prowritingaid)
-- SEO: "NocoDB代替"/"Baserow代替"/"ProWritingAid代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S476: 競合3社追加 1249→1252社 (nocodb/baserow/prowritingaid)',
  'comparison_page.dartにnocodb(OSS Airtable代替既存DB連携Grid/Kanban自己ホスト/4F46E5)/baserow(OSS GDPR準拠プラグインAPI Airtable代替/3DAAE9)/prowritingaid(25種類レポートスタイル/構造/可読性作家向け/7BB5E5)の3社追加(1249→1252社)。sitemap 1345 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
