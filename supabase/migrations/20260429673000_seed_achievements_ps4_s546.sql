-- PS#4 S546: 競合3社追加 1458→1467社 (renovate/mend/fossa)
-- SEO: "Renovate代替"/"Mend代替"/"FOSSA代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S546: 競合3社追加 1458→1467社 (renovate/mend/fossa)',
  'comparison_page.dartにrenovate(OSS自動依存関係更新・PR自動生成・スケジュール制御・全言語・モノレポ/21BCCC)/mend(旧WhiteSource OSS脆弱性・ライセンス管理・AppSec自動修正・SBOM/00529B)/fossa(OSSライセンス管理・脆弱性管理・SBOM・Legal承認ワークフロー/6633CC)の3社追加(1458→1467社)。sitemap 1561 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
