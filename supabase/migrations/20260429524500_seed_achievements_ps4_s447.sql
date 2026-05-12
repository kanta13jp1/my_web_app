-- PS#4 S447: 競合3社追加 1165→1168社 (proofpoint/knowbe4/crowdstrike)
-- SEO: "Proofpoint代替"/"KnowBe4代替"/"CrowdStrike代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S447: 競合3社追加 1165→1168社 (proofpoint/knowbe4/crowdstrike)',
  'comparison_page.dartにproofpoint(エンタープライズメールセキュリティTAP BEC防御コンプライアンス/email-security/00B0EA)/knowbe4(セキュリティ意識向上トレーニングフィッシングシミュレーション/security-training/FF6600)/crowdstrike(クラウドネイティブEDR Falcon Platform AI脅威検出/endpoint-security/FF0000)の3社追加(1165→1168社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
