-- PS#4 S467: 競合3社追加 1222→1225社 (figjam/kik/fathom)
-- SEO: "FigJam代替"/"Kik代替"/"Fathom Analytics代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S467: 競合3社追加 1222→1225社 (figjam/kik/fathom)',
  'comparison_page.dartにfigjam(Figma製ホワイトボードブレスト投票AI整理/FF7262)/kik(電話番号不要Bot APIグループチャット/82BC23)/fathom(プライバシーファーストクッキーフリーGDPR準拠/9B59B6)の3社追加(1222→1225社)。sitemap 1318 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
