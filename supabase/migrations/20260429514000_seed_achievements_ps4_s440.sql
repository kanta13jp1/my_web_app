-- PS#4 S440: 競合3社追加 1144→1147社 (mixmax/copper-crm/streak-crm)
-- SEO: "Mixmax代替"/"Copper CRM代替"/"Streak代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S440: 競合3社追加 1144→1147社 (mixmax/copper-crm/streak-crm)',
  'comparison_page.dartにmixmax(Gmail生産性メール追跡シーケンスCRM統合/email-sales/FF6B2B)/copper-crm(Google Workspace専用CRM自動データ入力パイプライン/crm/FF6D00)/streak-crm(Gmail内蔵CRMパイプラインmail merge/crm/FF6600)の3社追加(1144→1147社)。sitemap 1237 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
