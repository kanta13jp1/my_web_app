-- PS#5 S73: stale EF migration — performance-review/leave-management → enterprise-hub
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'stale EF 移行 — performance-review/leave-management を enterprise-hub に統合',
  'performance_review_page: invoke enterprise-hub(review.list/review.create)。leave_management_page: invoke enterprise-hub(leave.list/leave.request)、data[leaves]→data[requests]、leave_type→type。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
