-- PS#4 S256: 競合3社追加 639→642社 (docusaurus/signoz/honeycomb)
-- SEO: "Docusaurus代替"/"SigNoz代替"/"Honeycomb代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S256: 競合3社追加 639→642社 (docusaurus/signoz/honeycomb)',
  'comparison_page.dartにdocusaurus(Meta製OSSドキュメント/docs/3ECC5F)/signoz(OSS オブザーバビリティ/monitoring/E75480)/honeycomb(イベント駆動オブザーバビリティ/monitoring/F3B500)の3社追加(639→642社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
