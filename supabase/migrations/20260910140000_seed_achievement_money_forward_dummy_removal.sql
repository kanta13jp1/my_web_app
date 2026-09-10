-- daily-development (scheduled) 2026-09-10 (2回目): MoneyForward連携ページのダミーOAuthを撤去

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'MoneyForward連携: ダミーOAuth画面を実行可能なCSV案内に置換',
  '/money-forward の「接続する」ボタンは mf.connect_url が返す固定URL(/oauth/moneyforward、未実装ルート)を一度も使わずスナックバー表示するだけで、mf.status が参照する access_token もコード全体のどこにも書き込まれないため「連携済み」状態に絶対到達できない死んだ画面だった。MoneyForward は個人向け公開OAuth APIを提供していないため実装不可能と判断し、既存の動くCSVエクスポート→インポート手順(#5365でマニュアル修正済み)へ誘導するページに全面置換。実際のスクレイピング/API連携は #2497-#2500 で別途追跡中。',
  '2026-09-10'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'MoneyForward連携: ダミーOAuth画面を実行可能なCSV案内に置換'
);
