-- PS#4 S556: 競合3社追加 継続 (ibm-security/microsoft-defender/azure-sentinel)
-- SEO: "IBM QRadar代替"/"Microsoft Defender代替"/"Microsoft Sentinel代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S556: 競合3社追加 (ibm-security/microsoft-defender/azure-sentinel)',
  'comparison_page.dartにibm-security(QRadar SIEM・AI駆動SOC・脅威インテリジェンス・エンタープライズ/0530AD)/microsoft-defender(XDR・Defender for Endpoint/Identity/Office・ゼロトラスト/00A1F1)/azure-sentinel(クラウドSIEM・AI駆動・Azure統合・SOAR自動化/0078D4)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
