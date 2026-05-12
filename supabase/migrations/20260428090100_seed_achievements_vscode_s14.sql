-- VSCode S14: 4ページ dark mode 対応 (discord/bookmark/habit/gantt)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'VSCode S14: Dark Mode Batch — 4ページ light container 対応',
  'discord_notification_page / bookmark_sync_page / habit_gamification_page / gantt_timeline_page の light container backgrounds を dark mode 対応。_buildAlert / _buildBookmarkCard / _buildChallengesTab / _buildBadgeChip / _buildMilestoneRow に isDark 分岐追加。commit 7a1d34a6',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
