-- PS#4 S367: 競合3社追加 972→975社 (nimble/keap/deputy)
-- SEO: "Nimble代替"/"Keap代替"/"Deputy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S367: 競合3社追加 972→975社 (nimble/keap/deputy)',
  'comparison_page.dartにnimble(ソーシャルCRMコンテキスト連絡先管理/crm/00BCD4)/keap(旧InfusionsoftCRM自動化請求書/crm/34A853)/deputy(従業員スケジュールシフト計画/workforce/8B2FC9)の3社追加(972→975社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
