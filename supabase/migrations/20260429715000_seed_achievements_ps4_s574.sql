-- PS#4 S574: 競合3社追加 継続 (manageengine/sysaid/spiceworks)
-- SEO: "ManageEngine代替"/"SysAid代替"/"Spiceworks代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S574: 競合3社追加 (manageengine/sysaid/spiceworks)',
  'comparison_page.dartにmanageengine(ServiceDesk Plus・IT資産管理・パッチ・コスト効率/F05A28)/sysaid(ITSM・AI自動化・ヘルプデスク・資産管理・中規模IT/0057A8)/spiceworks(無料ヘルプデスク・IT管理・クラウド/オンプレ・コミュニティ/E05C00)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
