-- PS#4 S625: 競合3社追加 シークレット検出/SAST (trufflehog/codeql/blackduck)
-- SEO: "TruffleHog代替"/"CodeQL代替"/"Black Duck代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S625: 競合3社追加 (trufflehog/codeql/blackduck)',
  'comparison_page.dartにtrufflehog(gitシークレット検出・エントロピー解析・700+検出器/FF6B35)/codeql(GitHub製SAST・コードクエリ・脆弱性パターン分析・10言語/2DA44E)/blackduck(SCA・OSS脆弱性・ライセンスコンプライアンス・Synopsys傘下/1E3050)の3社追加(1699社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
