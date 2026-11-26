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
  'video_claude_code_101_hooks_20261126',
  'Claude CodeのHooks｜必ず守りたい検査や防止策を自動で実行する【Claude Code 101 #12】',
  $content$# Claude CodeのHooks

## 学習目標
ルールへのお願い任せにせず、`settings.json` の `Hooks` を使って自動検査や危険操作の事前ブロックを確実に仕組み化する。

## ポイント
- `Hooks` は `PreToolUse` / `PostToolUse` / `UserPromptSubmit` / `Stop` / `Notification` などのタイミングで決定的に動作し、`/hooks` で一覧確認できる。
- `PostToolUse`（`matcher: "Edit|Write"`）を使えば編集直後に自動検査を走らせられる（シェル経由の変更は `Edit|Write` 対象外である点に留意する）。
- `PreToolUse` は終了コード `0` で続行、終了コード `2` でブロックし、`stderr` メッセージを Claude Code へ返して安全な手順へ誘導できる。
- `.claude/settings.json` をリポジトリへコミットし、`$CLAUDE_PROJECT_DIR` でスクリプトパスを指定するとチーム全員へ安全に共有できる。

## 練習
自分の作業で「毎回必ず走らせたい検査」または「絶対に止めておきたい操作」を1つ選び、「どのイベント（PreToolUse / PostToolUse）・どのマッチャーで・何を終了コード 2 で止めるか」をメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=tYdQez_3KWI
- 参考：Claude Academy「Hooks」
- https://academy.claude.com/courses/claude-code-101/hooks
- 公式リファレンス：https://code.claude.com/docs/en/hooks

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。教材ページのリンク切れ検査例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=tYdQez_3KWI',
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
