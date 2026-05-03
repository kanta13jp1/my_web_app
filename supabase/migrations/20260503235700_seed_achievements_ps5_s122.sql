-- PS#5 S122: bc58b50b #1729 allowManagedHooksOnly + #1848 PreCompact backup hook
-- Also re-applies S121 settings.json changes (dropped by autostash during rebase)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'bc58b50b #1729/#1751: allowManagedHooksOnly + allowManagedPermissionRulesOnly 完全ロックダウン',
    '.claude/settings.json に allowManagedHooksOnly: true + allowManagedPermissionRulesOnly: true 追加。ローカル開発者による Hook/Permission バイパスを完全遮断。12インスタンスfleet全体適用。',
    '2026-05-03'
  ),
  (
    'bc58b50b #1848: PreCompact hook — transcript backup で context 蒸発防止',
    '.claude/hooks/pre-compact-backup.ps1 新規作成 + settings.json PreCompact hook追加。コンテキスト圧縮前に CLAUDE_COMPACT_TRIGGER_SUMMARY を memory/transcripts/compact-YYYYMMDD-HHMMSS.md へ自動バックアップ。AI_FLEET_SYNERGY Principle #5 (Memory & State Continuity Hooks) 実装完了。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
