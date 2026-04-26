-- PS#5 S61: stale EF invoke 一括移行 A11件 → hub actions
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Flutter stale EF invoke 一括移行 (A11件)',
  'PS#5 S61: 削除済みEFを参照していたFlutter12ページをhub actionsに移行。analyze-reality→ai-hub, app-analytics-dashboard→core-hub, development-achievements→core-hub, growth-achievement-summary→growth-hub, growth-share-signal→growth-hub, personal-dashboard→core-hub, referral-program→growth-hub, daily-judgment→ai-hub, video-ad-generator→growth-hub, viral-growth-engine→growth-hub(3箇所), virtual-organization→ai-hub(3call→1call統合)。stale invoke audit cross-instance-pr A11件完了。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
