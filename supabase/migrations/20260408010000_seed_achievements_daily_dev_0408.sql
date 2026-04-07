-- Session daily-development 2026-04-08: Xコンポーザーウィンドウ連動・テスト修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ElectionXPostComposerDialog initialWindowIndex 追加',
    'スケジュールフィルター選択（今週末/2週後/…）をXコンポーザーダイアログに引き継ぐ initialWindowIndex パラメータを追加。_filterToWindowIndex() ヘルパーで文字列フィルター名を availableWindows インデックスに変換。スケジュールセクションに「この週末の選挙をX投稿」ショートカットボタンを追加し、フィルター→投稿の操作を1タップに削減。',
    '2026-04-08'
  ),
  (
    'election_charts_test.dart オーバーフロー修正',
    'ElectionRegionalKpiChart テストが RenderFlex overflow で失敗していた既存バグを修正。SingleChildScrollView ラッパーで対応。凡例テキスト検索を find.text → find.textContaining に変更し正確なアサーションに修正。flutter test 0件失敗。',
    '2026-04-08'
  )
ON CONFLICT DO NOTHING;
