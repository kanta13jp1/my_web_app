-- PS#4 S555: 競合3社追加 継続 (vectra/exabeam/secureworks)
-- SEO: "Vectra AI代替"/"Exabeam代替"/"Secureworks代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S555: 競合3社追加 (vectra/exabeam/secureworks)',
  'comparison_page.dartにvectra(AI NDR/XDR・ネットワーク脅威検知・自動トリアージ・Active Directory/0080FF)/exabeam(New-Scale SIEM・UEBA・ユーザー行動分析・SOC自動化/003DA5)/secureworks(MDR/XDR・Taegis・脅威インテリジェンス・24/7 SOC/E31837)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
