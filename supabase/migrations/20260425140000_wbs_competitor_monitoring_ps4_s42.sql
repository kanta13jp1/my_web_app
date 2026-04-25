-- PS#4 S42: 競合モニタリング夕版 (2026-04-25)
-- Notion Custom Agents + Japan DC / Slack Agentforce / MS 7% cut / Google Agents CLI

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合モニタリング PS#4 S42 (2026-04-25夕)',
  'Notion Custom Agents発表(🔴🔴最高脅威)・Notion日本DC2026年5月開設(🔴高) ' ||
  '・Slack Agentforce+料金改定・Microsoft 7%人員削減・Google Agents CLI+LiteRT / ' ||
  'SCOREBOARD+2026-04-25レポート更新 / cross-instance-pr Win版(Supabase Tokyo検討)',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
