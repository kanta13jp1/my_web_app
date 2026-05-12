-- PS#4 S278: 競合3社追加 705→708社 (mural/conceptboard/remote-com)
-- SEO: "MURAL代替"/"Conceptboard代替"/"Remote.com代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S278: 競合3社追加 705→708社 (mural/conceptboard/remote-com)',
  'comparison_page.dartにmural(デジタルホワイトボードデザイン思考/collab/FF4F00)/conceptboard(GDPR準拠ドイツ製ホワイトボード/collab/0082C9)/remote-com(グローバルEOR給与管理/hr/4353FF)の3社追加(705→708社)。sitemap 751 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
