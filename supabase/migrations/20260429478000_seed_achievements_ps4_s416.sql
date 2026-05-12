-- PS#4 S416: 競合3社追加 1072→1075社 (mycase/concord/practicepanther)
-- SEO: "MyCase代替"/"Concord代替"/"PracticePanther代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S416: 競合3社追加 1072→1075社 (mycase/concord/practicepanther)',
  'comparison_page.dartにmycase(法律事務所向けケース管理クライアントポータル請求/legal-practice/1565C0)/concord(クラウド契約管理ライフサイクル電子署名統合/clm/3D7EFF)/practicepanther(法律事務所向けクラウドタイムトラッキング請求自動化/legal-practice/FF6B00)の3社追加(1072→1075社)。sitemap 1165 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
