-- PS#4 S559: 競合3社追加 継続 (netskope/imperva/f5)
-- SEO: "Netskope代替"/"Imperva代替"/"F5代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S559: 競合3社追加 (netskope/imperva/f5)',
  'comparison_page.dartにnetskope(SASE・SSE・CASB・DLP・SaaS/IaaS可視化・ゼロトラスト/005B96)/imperva(WAF・DDoS対策・データセキュリティ・API保護・DBファイアウォール/003580)/f5(BIG-IP・ADC・WAF・負荷分散・マルチクラウド/E4002B)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
