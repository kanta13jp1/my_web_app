-- Session 432k: 生活インフラ・安全機能Edge Functions (駐車場/CO2/ギフト/車両/緊急連絡先)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('駐車場・予約管理 Edge Function', 'akippa/タイムズ競合: スペース管理、予約作成、料金自動計算、空き状況確認、収益統計', '2026-04-01'),
  ('カーボンフットプリント管理 Edge Function', 'ESG/SDGs対応: CO2排出量記録(7カテゴリ)、CO2係数自動計算、削減目標設定、オフセット記録、月次レポート', '2026-04-01'),
  ('ギフトレジストリ Edge Function', 'Amazon/楽天競合: ウィッシュリスト作成、イベント紐付け(8タイプ)、購入追跡、共有コード発行', '2026-04-01'),
  ('車両・フリート管理 Edge Function', '車両登録(8タイプ)、走行記録、燃費管理(給油記録・リッター単価)、メンテナンス予定、コスト統計', '2026-04-01'),
  ('緊急連絡先・安否確認 Edge Function', '緊急連絡先登録、医療情報管理(血液型/アレルギー/服薬)、安否確認送信・回答、防災対応', '2026-04-01')
ON CONFLICT DO NOTHING;
