-- PS#4 S561: 競合3社追加 継続 (delinea/saviynt/sailpoint)
-- SEO: "Delinea代替"/"Saviynt代替"/"SailPoint代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S561: 競合3社追加 (delinea/saviynt/sailpoint)',
  'comparison_page.dartにdelinea(PAM・Secret Server・Privilege Manager・クラウドPAM・ゼロスタンディング/5C2D8B)/saviynt(IGA・CPAM・クラウドアイデンティティ・SaaS対応/7B3FE4)/sailpoint(IGA・IdentityIQ/IdentityNow・AIガバナンス・アクセス認証/003DA5)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
