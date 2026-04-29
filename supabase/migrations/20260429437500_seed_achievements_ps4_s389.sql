-- PS#4 S389: 競合3社追加 1038→1041社 (archbee/swimm/contractbook)
-- SEO: "Archbee代替"/"Swimm代替"/"Contractbook代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S389: 競合3社追加 1038→1041社 (archbee/swimm/contractbook)',
  'comparison_page.dartにarchbee(開発者向けドキュメントAPIリファレンス/docs/5B4FE9)/swimm(AIコードドキュメント自動同期/docs/0052CC)/contractbook(デジタル契約管理eSignatureCLM/contract/1B1464)の3社追加(1038→1041社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
