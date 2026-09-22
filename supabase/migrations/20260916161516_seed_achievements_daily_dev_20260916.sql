-- daily-development (scheduled) 2026-09-16: MoneyForward連携ページの偽OAuthダミー実装を修正した実績を記録

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'MoneyForward連携ページの偽OAuth成功表示を修正',
  '/money-forward の「接続する」ボタンは mf.connect_url (固定URL /oauth/moneyforward を返すだけで実際のOAuthコールバックは repo 内に存在しない) を呼んだ後「認証URLを取得しました。ブラウザで連携を完了してください」と成功を装う表示をしていたが、実際には何も起きず connected は恒久的に false のままだった。ボタンを CSVインポート画面 (/import) への誘導に差し替え、既存で動作するCSVエクスポート手順を案内するよう修正。バックエンドの実OAuth連携は財務データ領域のため人間レビュー前提で別途対応する。',
  '2026-09-16'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'MoneyForward連携ページの偽OAuth成功表示を修正'
);
