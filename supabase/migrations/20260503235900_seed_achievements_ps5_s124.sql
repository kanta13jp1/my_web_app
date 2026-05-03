-- PS#5 S124: #1871 SubagentStart/SubagentStop hooks + #1831 Claude Code May 2026 MCP auto-retry docs
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'bc58b50b #1781/#1871: SubagentStart/SubagentStop hooks — サブエージェント品質ゲート',
    '.claude/hooks/subagent-start.ps1 + subagent-stop.ps1 新規作成。SubagentStart: プロジェクト制約(REAL-DATA/EF-CAP/DART-FORMAT/MIGRATION命名)をadditionalContextとして注入。SubagentStop: ダミーデータ/migration命名/--no-verify等の品質チェック。Claude Code v2.1.126+対応。',
    '2026-05-03'
  ),
  (
    '#1831: Claude Code May 2026 MCP auto-retry v2.1.126 fleet適用完了',
    'docs/AI_FALLBACK_RUNBOOK.md にMCP安定性改善(v2.1.126)詳細追記。MCP_TIMEOUT=60000(S119設定済み)との組み合わせ効果確認。/recap CLAUDE_CODE_ENABLE_AWAY_SUMMARY fleet活用法 + project purge worktree cleanup活用法を文書化。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
