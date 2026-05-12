-- PS#4 S624: 競合3社追加 コンテナ/コードセキュリティ (aquasec/grype/gitleaks)
-- SEO: "Aqua Security代替"/"Grype代替"/"Gitleaks代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S624: 競合3社追加 (aquasec/grype/gitleaks)',
  'comparison_page.dartにaquasec(コンテナセキュリティ・CSPM・脆弱性スキャン・実行時保護/00ADEF)/grype(OSS脆弱性スキャン・コンテナ/ファイルシステム・Anchore製/2D5BFF)/gitleaks(gitシークレット検出・OSS・CI/CD統合・履歴スキャン/E44A52)の3社追加(1699社)。sitemap 1795 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
