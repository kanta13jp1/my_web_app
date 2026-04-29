-- PS#4 S178: 競合3社追加 405→408社 (softr/glide/adalo)
-- SEO: "Softr代替"/"Glide代替"/"Adalo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S178: 競合3社追加 405→408社 (softr/glide/adalo)',
  'comparison_page.dartにsoftr(Airtableノーコード/nocode/6C63FF)/glide(スプレッドシートApp/nocode/7C4DFF)/adalo(ノーコードモバイル/nocode/FF5733)の3社追加(405→408社)。sitemap 451 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
