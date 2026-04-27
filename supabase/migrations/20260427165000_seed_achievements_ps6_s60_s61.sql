-- PS#6 S60+S61: worktree cleanup + horseracing.stats EF enrichment
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S60 — stale worktree クリーンアップ',
    'git worktree remove (4本) + orphan dir 削除 (4本)。cranky-chaplygin/sweet-blackwell は空dir残留(プロセスロック)。leaderboard UI cross-instance-pr done確認。',
    '2026-04-27'
  ),
  (
    'PS#6 S61 — horseracing.stats EF 強化',
    'horseracing.stats に learning フィールド追加: daily_trend (horse_learning_daily_accuracy 直近N日) / top_bet_types TOP5 / latest metrics。body.days パラメータ対応。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
