-- PS#4 S397: 競合3社追加 1015→1018社 (rewardful/tolt/typefully)
-- SEO: "Rewardful代替"/"Tolt代替"/"Typefully代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S397: 競合3社追加 1015→1018社 (rewardful/tolt/typefully)',
  'comparison_page.dartにrewardful(SaaSアフィリエイトリファラルプログラム管理Stripe連携/affiliate/7C3AED)/tolt(スタートアップ向けシンプルアフィリエイトPaddle連携/affiliate/10B981)/typefully(Twitter/Xスレッド作成スケジュール分析/social-media/1DA1F2)の3社追加(1015→1018社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
