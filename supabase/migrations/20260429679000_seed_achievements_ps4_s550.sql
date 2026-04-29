-- PS#4 S550: 競合3社追加 継続 (qualys/rapid7/burpsuite)
-- SEO: "Qualys代替"/"Rapid7代替"/"Burp Suite代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S550: 競合3社追加 (qualys/rapid7/burpsuite)',
  'comparison_page.dartにqualys(VMDR・Asset管理・パッチ管理・TruRiskスコア・ゼロトラスト/0078D4)/rapid7(InsightVM・LiveBoard・リアルタイムリスク・Attack Surface/E8002D)/burpsuite(Webアプリセキュリティ・プロキシ・DAST・スキャナー・ペネトレーションテスト/FF6633)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
