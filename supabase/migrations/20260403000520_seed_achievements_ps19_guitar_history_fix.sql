-- Session PS#19: 開発実績カード時系列・詳細表示 + ギタースタジオ履歴更新修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '開発実績カード: 時系列ソート・タップ詳細・HH:MM:SS表示',
    '実績を新しい順に並べ替え。各実績をタップすると詳細ダイアログ(説明・追加日時HH:MM:SS)を表示。番号バッジとchevronアイコンを追加。',
    '2026-04-03 00:00:00+00'
  ),
  (
    'ギタースタジオ: 履歴・統計タブの自動リフレッシュ修正',
    '履歴(tab3)/統計(tab4)/AI(tab5)タブ切替時に自動でデータ再取得。統計タブにRefreshIndicator追加。履歴リストの各アイテムにXに投稿ボタンを追加。',
    '2026-04-03 00:01:00+00'
  )
ON CONFLICT DO NOTHING;
