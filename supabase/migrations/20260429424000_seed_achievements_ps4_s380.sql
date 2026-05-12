-- PS#4 S380: 競合3社追加 1011→1014社 (opensearch/fusionauth/stytch)
-- SEO: "OpenSearch代替"/"FusionAuth代替"/"Stytch代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S380: 競合3社追加 1011→1014社 (opensearch/fusionauth/stytch)',
  'comparison_page.dartにopensearch(OSS分散検索ログ分析ES互換/search/005EB8)/fusionauth(デベロッパー向け認証認可セルフホスト/auth/E87722)/stytch(パスワードレス認証B2B IDプラットフォームAPI/auth/19A974)の3社追加(1011→1014社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
