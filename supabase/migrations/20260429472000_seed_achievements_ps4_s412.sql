-- PS#4 S412: 競合3社追加 1060→1063社 (paylocity/justworks/remofirst)
-- SEO: "Paylocity代替"/"Justworks代替"/"RemoteFirst代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S412: 競合3社追加 1060→1063社 (paylocity/justworks/remofirst)',
  'comparison_page.dartにpaylocity(クラウド給与HCM従業員エンゲージメント統合/payroll/005D8E)/justworks(スタートアップ向けPEO給与ベネフィットHR/payroll/2453FF)/remofirst(グローバル採用EOR給与コンプライアンス低価格/global-hr/4CAF50)の3社追加(1060→1063社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
