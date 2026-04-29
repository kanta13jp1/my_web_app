-- PS#4 S549: 競合3社追加 継続 (orca-security/lacework/tenable)
-- SEO: "Orca Security代替"/"Lacework代替"/"Tenable代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S549: 競合3社追加 (orca-security/lacework/tenable)',
  'comparison_page.dartにorca-security(エージェントレスCSPM/CWPP/CIEM・AWS/Azure/GCP・AIリスク優先/0066FF)/lacework(ML異常検知・Polygraph可視化・CSPM/CWPP・コンテナ/4A90D9)/tenable(Nessus脆弱性管理・クラウド/オンプレ・OT/IoT・リスクベーススコアリング/003087)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
