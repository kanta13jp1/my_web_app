-- PS#4 S130: 競合3社追加 261→264社 (semrush/ahrefs/1password)
-- SEO: "SEMrush代替"/"Ahrefs代替"/"1Password代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S130: 競合3社追加 261→264社 (semrush/ahrefs/1password)',
  'comparison_page.dartにsemrush(SEO競合分析/seo/FF642D)/ahrefs(SEOバックリンク分析/seo/2356FF)/1password(パスワード管理/security/1A8CFF)の3社追加(261→264社)。新カテゴリseo/security追加。全ファイル264統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
