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
  'video_claude_code_in_action_claude_md_20261126',
  '従われるCLAUDE.mdの書き方｜肥大化を防ぎHooks・4層配置・具体表現を使い分ける【実践Claude Code #2】',
  $content$# 従われるCLAUDE.mdの書き方（実践Claude Code #2）

## 学習目標
`CLAUDE.md` を「強制設定ではなく注意を奪い合うガイダンス」として捉え、Hooks との役割分担・4 層配置・具体的かつ代替案付きの記述・引き締まった継続保守によって指示遵守率を高められるようになる。

## ポイント
- **`CLAUDE.md` vs `Hooks`**: 絶対に破られてはならない制約は `PreToolUse` フックで機械的にブロックし、`CLAUDE.md` には緩やかな設計方針や慣習だけを残して肥大化を防ぐ。
- **4 つの配置場所と `@` インポート**: `Managed policy` / `User`（`~/.claude/CLAUDE.md`） / `Project` / `Local`（`.gitignore` 対象の `CLAUDE.local.md`）は起動時にすべて積み重なる。`@path/to/file` によるインポートは整理に役立つが起動時にインライン展開されるため、コンテキスト量の削減にはならない。
- **検証可能性と代替案の明示**: 結果を見て成否を即断できる具体基準で書き、「〜を使わない」だけでなく「〜ではなく〜を使う」と代替手段を指定する。
- **平易な表現と生きた保守**: `IMPORTANT` などの強調語を重ねると過剰適用を招きやすいため平易な一文で書き、誤動作が起きたら `CLAUDE.md` のバグ報告として追記・不要行削除を繰り返す。

## 練習
現在使っている（または作る予定の）`CLAUDE.md` からルールを 3 つ選び、① `PreToolUse` フックへ移すべき絶対制約がないか、② 成否を確認できる具体基準と代替案が書かれているか、③ 削れる曖昧行や過剰強調がないかを見直してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=_o4hnmp9U3U
- 参考：Claude Academy「Writing a CLAUDE.md that Claude actually follows」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/a-claude-md-that-follows
  - https://academy.claude.com/ja/courses/claude-code-in-action/a-claude-md-that-follows

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。具体例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=_o4hnmp9U3U',
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
