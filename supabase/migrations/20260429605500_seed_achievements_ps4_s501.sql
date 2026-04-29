-- PS#4 S501: 競合3社追加 1323→1332社 (adobe-express/crello/desygner)
-- SEO: "Adobe Express代替"/"VistaCreate代替"/"Desygner代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S501: 競合3社追加 1323→1332社 (adobe-express/crello/desygner)',
  'comparison_page.dartにadobe-express(Adobeテンプレート動画PDF AI生成/FF0000)/crello(アニメーションデザイン50K+テンプレート動画SNS最適化/00ACC1)/desygner(ブランドテンプレートPDF編集チームデザイン統一/3F51B5)の3社追加(1323→1332社)。sitemap 1426 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
