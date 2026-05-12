-- PS#5 S120: bc58b50b #1836 ENABLE_MCP_TOOL_SEARCH + #1834 Plankton Pattern (flutter analyze hook)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'bc58b50b #1836: ENABLE_MCP_TOOL_SEARCH設定追加 — context 95%削減',
    '.claude/settings.json env.ENABLE_MCP_TOOL_SEARCH=true 追加。MCP tool schema を on-demand ロードに切り替え、deferred tools 経由で全 MCP スキーマを事前ロードしないため context 使用量を大幅削減。',
    '2026-05-03'
  ),
  (
    'bc58b50b #1834: Plankton Pattern実装 — PostToolUse flutter analyze自動化',
    '.claude/hooks/post-tool-use-dart-format.ps1 拡張: dart format 成功後に flutter analyze を自動実行。エラー件数を集計し SIMPLE/COMPLEX/WARN_ONLY の3段階 severity で分類、additionalContext として agent に注入する自己修正ループ完成。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
