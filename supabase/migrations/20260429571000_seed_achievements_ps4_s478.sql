-- PS#4 S478: 競合3社追加 1255→1258社 (goodnotes/notability/quizlet)
-- SEO: "GoodNotes代替"/"Notability代替"/"Quizlet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S478: 競合3社追加 1255→1258社 (goodnotes/notability/quizlet)',
  'comparison_page.dartにgoodnotes(iPad Apple Pencil手書きPDFアノテーションAI数式/FC766A)/notability(録音同期音声リプレイPDF編集Apple Watch/4CAF50)/quizlet(AIフラッシュカード750M+セット教師ダッシュボード/4257B2)の3社追加(1255→1258社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
