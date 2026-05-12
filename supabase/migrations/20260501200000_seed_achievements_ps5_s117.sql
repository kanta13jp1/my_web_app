-- PS#5 S117: ci-auto-fix bash -e propagation fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ci-auto-fix bash -e 伝播バグ修正 (PS#5 S117)',
  'GHA bash -e モードで RESULT=$(flutter analyze) が非ゼロ終了を即時伝播し Step 6/7 がスキップされる問題を修正。set +e/set -e ラッパー追加 + Step 6/7 に always() && 条件追加。format 修正が analyze 失敗時でも確実にコミットされるようになった。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
