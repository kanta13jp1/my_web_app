-- PS#5 S121: bc58b50b #1751 allowManagedPermissionRulesOnly + #1791 PreToolUse git bypass防止
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'bc58b50b #1751: allowManagedPermissionRulesOnly — 権限ルール完全ロックダウン',
    '.claude/settings.json に allowManagedPermissionRulesOnly: true 追加。開発者がローカル設定で組織の強制セキュリティプロンプトをバイパスするリスクを完全遮断。12インスタンスfleet全体に適用。',
    '2026-05-03'
  ),
  (
    'bc58b50b #1791: PreToolUse git hook bypass防止 — GitHub MCP commit前lint強制',
    '.claude/hooks/pre-commit-guard.ps1 新規作成 + settings.json PreToolUse hook追加。GitHub MCP (create_or_update_file/push_files) 実行前に dart format/flutter analyze/deno lint を強制実行。WEB版・Codex MCP経由コミット時のgit hook迂回問題を解決。Exit 2でブロック機構実装。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
