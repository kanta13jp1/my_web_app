-- PS#5 S118: AI_FALLBACK_RUNBOOK v2.1.113-v2.1.126 + NotebookLM適用 + GitHub Issues #1765-#1775
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S118: Claude Code v2.1.113-v2.1.126 fleet反映 + NotebookLM未適用11件Issues登録',
  '【AI_FALLBACK_RUNBOOK更新】Claude Code v2.1.113-v2.1.126の新機能をPS5 worktreeで文書化: sandbox.network.deniedDomains(セキュリティ) / Hooks→MCP tool(type:mcp_tool) / /theme command / Vim visual mode / claude ultrareview CI統合 / /recap session復帰 / Windows Git Bash不要化。【Copilot更新】GPT-5.3-Codex base model昇格(2026-05-17〜)を反映。【NotebookLM未適用Issues登録】#1765(Hooks→MCP) / #1766(sandbox.deniedDomains) / #1767(claude ultrareview CI) / #1768(Notion-Style Comments) / #1769(Claude Design Plugin) / #1770(Cartesia Sonic TTS) / #1771(GPT-Image-2) / #1772(Claude API Cost) / #1773(Vibe Coding品質ゲート) / #1774(Anthropic Evolution fleet) / #1775(Gemini Domain-Specific AI大学)',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
