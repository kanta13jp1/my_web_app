-- PS#5 S87: collision patrol 4件 + comparison_page lint fix (prefer_adjacent_string_concatenation)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S87: lint fix 12件 + collision patrol 4件',
  'comparison_page.dart の prefer_adjacent_string_concatenation 12件解消 '
  '(月額約''r''$''''14〜''形式 → 隣接文字列リテラル形式)。'
  '010000 vscode_s14→010100 / 003000 ps6_s99→003200 / '
  '018000 ollama→018100 / 019500 llamacpp→019600。'
  '906 timestamps 全 unique。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
