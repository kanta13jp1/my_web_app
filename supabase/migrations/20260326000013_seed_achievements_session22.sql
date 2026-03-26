-- Session 22: CS完全自動化 — サポートチケットAPI・自動返信・バグ修正・エスカレーション

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'CS完全自動化: サポートチケット返信・バグ修正・エスカレーションをClaude Code Scheduleで自動化',
    'feature_requests に admin_reply/admin_replied_at カラム追加 (migration)。get-support-tickets Edge Function実装 (未返信チケット+FAQ一覧を返すGET API)。reply-support-request Edge Function実装 (チケット返信+Resendメール送信)。CLAUDE.md cs-checkタスクを本格化 (FAQ自動返信/バグ自動修正/エスカレーション判断の3ケース対応)。schedule-daily-diggestの status=pending バグを status=open に修正。cs-checkスケジュールトリガーを新エンドポイント対応に更新',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
