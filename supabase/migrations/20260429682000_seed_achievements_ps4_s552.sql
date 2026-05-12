-- PS#4 S552: 競合3社追加 継続 (jfrog/sonatype/black-duck)
-- SEO: "JFrog代替"/"Sonatype代替"/"Black Duck代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S552: 競合3社追加 (jfrog/sonatype/black-duck)',
  'comparison_page.dartにjfrog(Artifactory・Xray・バイナリ管理・サプライチェーン・DevSecOps/40BE46)/sonatype(Nexus IQ・SBOM・OSS脆弱性・サプライチェーンセキュリティ/1B4D7E)/black-duck(Synopsys OSSセキュリティ・SCAスキャン・ライセンスコンプライアンス/2D2D2D)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
