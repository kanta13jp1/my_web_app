-- PS#5 S75: stale EF completeness audit + CI + 3 URL ref fixes
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'stale EF completeness audit スクリプト + CI workflow 新規',
  'scripts/audit_hub_migration_completeness.py (185 retired EF scan / exit 0/1/2) + stale-ef-completeness-check.yml (PR/push/weekly/manual). 初回実行で 3 stale URL refs 発見・修正: share-quote/generate-quote-image → app URL, get-public-memo-ogp → buildPublicMemoAppUrl。cross-instance-pr (Win版#132 part 50) 完了。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
