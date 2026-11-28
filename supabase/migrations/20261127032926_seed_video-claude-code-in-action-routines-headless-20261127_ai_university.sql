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
  'video_claude_code_in_action_routines_headless_20261127',
  'Claude Code定期実行と非対話-p設計｜--bare固定CI・JSON出力・Agent SDK【実践Claude Code #6】',
  $content$# Claude Code定期実行と非対話-p設計（実践Claude Code #6）

## 学習目標
定型タスクの自動化について、構築不要の「クラウドスケジュールタスク」、パイプ・構造化出力・セッション継続ができる「ヘッドレス `-p`」、CI 向け「`--bare`」、製品組込の「Agent SDK」の 4 段階を要件に応じて使い分けられるようになる。

## ポイント
- **クラウドスケジュールタスク（旧 routines）**: Anthropic インフラ上で動作し、`claude.ai/code/routines` または `/schedule` で作成できる。プロンプト・リポジトリ・コネクタ・トリガー（cron / HTTP POST / GitHub イベント）をまとめるが、① リサーチプレビュー、② 定期実行は最短 1 時間間隔、③ 既定で `claude/` ブランチへ出力（保護ルールで制御。ただし接続権限が回避できる設定は無効化されない点に注意）の 3 制約がある。
- **非対話 `-p`（`--print`）と構造化・継続**: シェルパイプで標準入出力を扱える（単体では hooks・Skills・`CLAUDE.md`・MCP も読み込む）。`--output-format json --json-schema '...'` を併用すると `structured_output` に制約済み JSON が格納され、さらに 1 段目出力の `session_id` を `--resume` へ渡すことで分析と修正を別スクリプトへ分割できる。
- **CI 再現性の `--bare`**: hooks・Skills・プラグイン・MCP・`CLAUDE.md` の自動検出を省き（`~/.claude/settings.json` 等の権限ルール設定は参照）、`--settings` 等の明示指定と事前 **`ANTHROPIC_API_KEY`** で高速・均質に起動する（`--settings` 経由の hooks も未実行）。
- **Agent SDK**: TypeScript / Python から `query` と `allowedTools`・システムプロンプト・権限モードを指定してストリーミング応答を自社アプリへ組み込める。

## 練習
手元の定期作業（例：PR 変更差分のリスク分類・リリース前確認）を 1 つ選び、① 1 時間以上の間隔＋既存連携で足りるため「クラウドスケジュールタスク」で済む部分、② ローカル環境や構造化 JSON が必要で `-p` / `--bare`（`ANTHROPIC_API_KEY` 設定要否含む）に切り替える条件の 2 点をメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=XmryZ0Sf3P8
- 参考：Claude Academy「Scheduled tasks and headless」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/routines-and-headless
  - https://academy.claude.com/ja/courses/claude-code-in-action/routines-and-headless
- 公式ドキュメント入口：https://code.claude.com/docs/en/overview

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。PR差分リスク分類のコマンド構成、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=XmryZ0Sf3P8',
  '2026-11-27',
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
