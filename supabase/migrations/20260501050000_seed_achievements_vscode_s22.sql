-- VSCode版 S22: テーマ切り替え UI Phase 2 実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'テーマ切り替え UI Phase 2 — 10 テーマカタログ (VSCode版 S22)',
  'Win版#132 part 100 cross-instance-pr 完了。AppThemeDef + ThemeService catalog 拡張 + ThemeSelectorPage (2x5 grid + preview tile + 即適用) + settings_page デザインテーマ entry + /settings/theme route。SharedPreferences 永続化でオフライン動作。flutter analyze 0 issues。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
