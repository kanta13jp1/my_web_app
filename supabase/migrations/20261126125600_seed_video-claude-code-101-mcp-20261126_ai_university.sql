-- AI大学: YouTube 公開動画を埋め込み学習コンテンツとして登録する。

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
VALUES (
  'anthropic',
  'video_claude_code_101_mcp_20261126',
  'Claude CodeのMCP｜外部ツールと安全につなぎ、必要な情報だけ活かす【Claude Code 101 #11】',
  $content$# Claude CodeのMCP

## 学習目標
外部ツールやデータソースへつなぐ共通規格 `MCP` の接続方法・スコープ・コンテキスト管理と信頼性確認を理解し、安全に使い始める。

## ポイント
- `MCP` は外部ツール・API・データソースへ直接つなぐオープン標準で、リモート向けの `HTTP` とローカル実行の `Stdio` を `claude mcp add` で追加する。
- スコープは `Local`（今の作業の自分用）・`User`（全プロジェクトの自分用）・`Project`（`.mcp.json` をリポジトリ共有）の3段階で切り分ける。
- 外部コンテンツを取り込むサーバーはリスクもあるため、接続前に信頼できる接続先かどうかを必ず確認する。
- 接続数が増えるとコンテキストを消費するため、`/mcp` で不要サーバーを無効化し、`gh` や `aws` 等は既存 CLI の併用も優先する。

## 練習
普段よくチャット欄へ手作業でコピーしている外部情報を1つ選び、「Local / User / Project のどのスコープで接続するか」「信頼できる接続先か」「既存 CLI で代替できないか」を短いメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=DFxmjX5dIY0
- 参考：Claude Academy「MCP」
- https://academy.claude.com/courses/claude-code-101/mcp
- 公式ドキュメント：https://code.claude.com/docs/en/mcp

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。教材一覧の確認例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=DFxmjX5dIY0',
  '2026-11-26',
  0,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
