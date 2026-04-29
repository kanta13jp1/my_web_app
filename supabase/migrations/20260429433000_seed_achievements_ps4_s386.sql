-- PS#4 S386: 競合3社追加 1029→1032社 (hoppscotch/semgrep/stoplight)
-- SEO: "Hoppscotch代替"/"Semgrep代替"/"Stoplight代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S386: 競合3社追加 1029→1032社 (hoppscotch/semgrep/stoplight)',
  'comparison_page.dartにhoppscotch(OSS API開発REST/GraphQL/WS PWA/ci-cd/00E9A3)/semgrep(OSS SAST静的コード解析セキュリティ/sast/10B981)/stoplight(APIデザインOpenAPIドキュメントモック/api-design/F66A0A)の3社追加(1029→1032社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
