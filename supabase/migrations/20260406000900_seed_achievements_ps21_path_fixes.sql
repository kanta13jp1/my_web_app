-- Session PS#21: EdgeFunctionSummaryCard uiPath 正確化
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'EdgeFunctionSummaryCard uiPath 12箇所修正',
    'ホーム画面の Edge Functions 実装状況カードで参照していた不正確なルートパスを修正。/bookmarks→/bookmark-sync、/election→/election-dashboard、/focus-mode→/focus-timer、/note-list→/note-editor、/onboarding→null(自動表示)、/profile→/profile-settings、/team→/team-workspace の7系統12箇所を正確なルートに更新。EdgeFunctionStatusPageの「実装へ」ボタンが正しいルートへ遷移するよう修正。flutter analyze 0エラー維持。',
    '2026-04-06 00:00:00+00'
  )
ON CONFLICT DO NOTHING;
