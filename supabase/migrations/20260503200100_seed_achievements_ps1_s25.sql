-- PS#1 Session 25: WF health check + NotebookLM bc58b50b適用 + Issue登録
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S25: Rule17 WF health + bc58b50b適用 + notebooklm全登録',
  'issue-to-wbs.yml YAML構文エラー修正(heredoc 0インデント→10sp) / CI失敗#1763-#1764-#1776 close / sandbox.network.deniedDomains設定 / bc58b50b未適用5件(#1789-#1793) / notebooklm list 18ノートブック全Issue化(#1794-#1811) / claude/mobile-version-task-hQxcq未マージ検出→cross-instance-pr#1812',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
