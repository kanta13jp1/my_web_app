-- PS#4 S492: 競合3社追加 1296→1305社 (zoho-projects/ntask/hive-pm)
-- SEO: "Zoho Projects代替"/"nTask代替"/"Hive代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S492: 競合3社追加 1296→1305社 (zoho-projects/ntask/hive-pm)',
  'comparison_page.dartにzoho-projects(Zohoエコシステム統合GanttタイムシートカスタムWF/E84D1C)/ntask(タスク/会議/リスク管理タイムシートGantt低価格/00897B)/hive-pm(HiveMind AI柔軟ビューアクションカードForms/FF6D00)の3社追加(1296→1305社)。sitemap 1399 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
