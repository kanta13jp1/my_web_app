-- PS#4 S629: 競合3社追加 高速リンター/Ruby解析 (ruff/oxlint/rubocop)
-- SEO: "Ruff代替"/"oxlint代替"/"RuboCop代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S629: 競合3社追加 (ruff/oxlint/rubocop)',
  'comparison_page.dartにruff(高速PythonリンターRust製・Flake8/Black/isort代替・100倍高速/D7522E)/oxlint(超高速JSリンター・Rust製・ESLint互換・50-100倍高速/FF6B00)/rubocop(Ruby静的解析・スタイルガイド準拠・自動修正・Rails対応/CC342D)の3社追加(1708社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
