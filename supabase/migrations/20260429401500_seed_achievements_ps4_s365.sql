-- PS#4 S365: 競合3社追加 966→969社 (copper/insightly/nutshell-crm)
-- SEO: "Copper代替"/"Insightly代替"/"Nutshell代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S365: 競合3社追加 966→969社 (copper/insightly/nutshell-crm)',
  'comparison_page.dartにcopper(Google Workspace統合CRM・パイプライン/crm/D97706)/insightly(CRM+PM統合中小企業営業管理/crm/00A2D4)/nutshell-crm(シンプルCRMメールマーケ営業自動化/crm/72B01D)の3社追加(966→969社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
