-- PS#5 Session 110: EF stale migration 12 pages (batch 2 of 16)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'EF stale migration 12 pages完了 (PS#5 S110)',
  '12 Flutter pages を stale standalone EF → hub EF に移行。enterprise-hub: email_template/github/calendar/legal/recruit/search.semantic、social-commerce-hub: lang/mf、media-hub: viral_video/whiteboard、lifestyle-hub: vehicle、tools-hub: habit.leaderboard(stoic)。DEAD_LIST 32件追加。dart format 0 changes。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
