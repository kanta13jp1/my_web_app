-- PS#4 S111: 超高検索ボリューム競合3社追加 (loom/pipedrive/photoroom) 204→207社
-- SEO: "Loom代替"/"Pipedrive代替"/"PhotoRoom代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S111: 競合3社追加 204→207社 (loom/pipedrive/photoroom)',
  'comparison_page.dartにloom(非同期ビデオコミュニケーション/月額12.5USD~/video-comm)/pipedrive(セールスCRM/月額14.9USD~/crm)/photoroom(AI写真編集背景除去/月額9.99USD~/photo-ai)の3社追加(204→207社)。新カテゴリvideo-comm/crm/photo-ai追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記204→207統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
