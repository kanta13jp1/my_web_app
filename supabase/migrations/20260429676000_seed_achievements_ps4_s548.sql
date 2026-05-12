-- PS#4 S548: 競合3社追加 継続 (aqua-security/anchore/sigstore)
-- SEO: "Aqua Security代替"/"Anchore代替"/"Sigstore代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S548: 競合3社追加 (aqua-security/anchore/sigstore)',
  'comparison_page.dartにaqua-security(コンテナ/K8s/Serverlessセキュリティ・CI統合・ランタイム保護・コンプライアンス/05B4C6)/anchore(コンテナ詳細分析・CVE/ライセンス・ポリシー強制・SBOM・CI/CDゲート/2E4057)/sigstore(Linux Foundation コード署名・Cosign/Fulcio/Rekor・透明性ログ・無料/4B0082)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
