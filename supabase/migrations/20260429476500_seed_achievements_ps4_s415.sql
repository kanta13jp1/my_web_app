-- PS#4 S415: 競合3社追加 1069→1072社 (carta/angellist/donotpay)
-- SEO: "Carta代替"/"AngelList代替"/"DoNotPay代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S415: 競合3社追加 1069→1072社 (carta/angellist/donotpay)',
  'comparison_page.dartにcarta(キャップテーブル管理株式報酬ベンチャーファンド管理/equity/0073E6)/angellist(スタートアップ投資家マッチング採用Rolling Funds/startup/000000)/donotpay(AIロボット弁護士法的書類自動化消費者権利保護/legal-ai/FF0000)の3社追加(1069→1072社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
