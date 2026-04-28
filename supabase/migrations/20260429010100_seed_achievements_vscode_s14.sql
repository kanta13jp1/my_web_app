-- VSCode S14: Notion Japan DC対抗 LP差別化セクション + FAQ 2件追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'VSCode S14: LP Notion Japan DC対抗 差別化強化',
  '_buildNotionVsSection() 5行対比表 (意思決定OS/CEO感/バランスシート/ゴール/コスト) + FAQ「Notion+Slack使ってるが?」「Notion Japan DC対抗」2件追加。cross-instance-pr 3件クローズ (notion_agent_skills/notion34_differentiation/notion_japan_dc VSCode部分)。commit 788e520fa。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
