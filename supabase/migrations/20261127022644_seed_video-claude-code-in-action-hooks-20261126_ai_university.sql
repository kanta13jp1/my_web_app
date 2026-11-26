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
  'video_claude_code_in_action_hooks_20261126',
  '実践Claude Code Hooks設計｜exit 1素通り罠・JSON書換マスク・圧縮後文脈復元【実践Claude Code #5】',
  $content$# 実践Claude Code Hooks設計（実践Claude Code #5）

## 学習目標
基礎の `exit 0/2` に加え、`Bash|Monitor` マッチャー設計・`exit 1` 素通り回避・`PreToolUse` の JSON 判定と `updatedInput` による機密マスク・`SessionStart (compact)` による圧縮後文脈復元を実装できるようになる。

## ポイント
- **マッチャーと対象イベントの設計**: `PreToolUse` / `Stop` / `SubagentStop` / `SessionStart`（`startup`・`compact`）/ `InstructionsLoaded` など約 30 イベントから目的別に選ぶ。バックグラウンド用ツール `Monitor` を漏らさないため `"Bash|Monitor"` とし、`"if"` 条件を使う際も `Monitor` 抜けに注意する。
- **`exit 1` 素通り罠と fail-open 対策**: ブロックされるのは `exit 2` であり、`exit 1`・パス誤り・依存ツール未導入時は標準ではそのまま処理が通る。ダミー入力でテスト検証し、必要なら失敗時ブロックを有効化する。
- **JSON 判定と `updatedInput` 書換**: `hookSpecificOutput.permissionDecision`（`allow` / `deny` / `ask`）と `permissionDecisionReason` を使い、特に `updatedInput` を使うと入力オブジェクト全体を置き換えて認証トークンをマスク値へ差し替え、`ask` で承認しつつ実行できる（未変更フィールドも必ず保持して返す）。
- **圧縮後コンテキストの復元**: `PostCompact` の出力は会話に入らないため、`SessionStart` に `"matcher": "compact"` を設定し、作業中の変更一覧等を標準出力してコンテキストへ自動再注入させる。

## 練習
自分がよく回すコマンド群（API 検証・デプロイ前チェック・圧縮後再開）を対象に、① `PreToolUse`（`"Bash|Monitor"`）で秘匿置換したい機密パターン、② 失敗時に素通りさせないためのテスト入力、③ `SessionStart (compact)` で再注入したい最小コマンド（変更一覧など）の 3 点をメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=so_KeBp2N7I
- 参考：Claude Academy「Hooks」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/hooks
  - https://academy.claude.com/ja/courses/claude-code-in-action/hooks
- 公式リファレンス：https://code.claude.com/docs/en/hooks

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。API確認コマンドのマスク例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=so_KeBp2N7I',
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
