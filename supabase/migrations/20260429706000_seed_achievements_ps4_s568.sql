-- PS#4 S568: 競合3社追加 継続 (kaseya/connectwise/n-able)
-- SEO: "Kaseya代替"/"ConnectWise代替"/"N-able代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S568: 競合3社追加 (kaseya/connectwise/n-able)',
  'comparison_page.dartにkaseya(VSA RMM・パッチ管理・リモート監視・MSP向け/0066CC)/connectwise(RMM/PSA・MSP統合・自動化・ヘルプデスク・プロジェクト管理/003087)/n-able(RMM・N-central・MSP向けセキュリティ・バックアップ・EDR/00AEF3)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
