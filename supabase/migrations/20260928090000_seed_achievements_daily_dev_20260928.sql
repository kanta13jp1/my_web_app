-- daily-development (scheduled) 2026-09-28: 駐車場予約ページの「新規予約は準備中」行き止まりを既存 parking.reserve へ接続した実績を記録

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '駐車場予約ページの新規予約ボタンを実装済みAPIへ接続',
  '/parking の「新規予約」ボタンは「新規予約機能は準備中です」と表示するだけだったが、lifestyle-hub には parking.reserve action が既に実装済みで、UI からの実行経路だけが欠けていた。駐車場名・区画・開始/終了日時・ナンバー・料金を入力するダイアログを追加し、保存後に一覧を再取得するよう接続。EF 側は無検証で保存するため、駐車場名必須・終了>開始・料金0以上の整数の検証を純関数 ParkingReservationDraft に置き、送信 body を一覧モデルで読み戻す往復テストを追加。駐車場事業者への実予約ではなく予約内容の記録であることを画面に明記した。',
  '2026-09-28'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '駐車場予約ページの新規予約ボタンを実装済みAPIへ接続'
);
