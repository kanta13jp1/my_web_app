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
  'video_claude_code_101_skills_20261126',
  'Claude Codeのスキル｜手順を一度書いて、必要な時だけ活かす【Claude Code 101 #10】',
  $content$# Claude Codeのスキル

## 学習目標
繰り返す作業手順や判断基準を `SKILL.md` にまとめ、必要な場面だけ読み込ませて安全に使い回す。

## ポイント
- スキルは `SKILL.md` と補助リソースをまとめたフォルダで、普段は名前と説明だけを参照し、依頼に合う時だけ本文を読み込む。
- 毎会話で守る全体ルールは `CLAUDE.md`、特定作業の専門手順はスキル（個人用 `~/.claude/skills` / 共有 `.claude/skills`）に分ける。
- カスタムスラッシュコマンドはスキルへ統合されており、`/name` の手動実行も状況に応じた自動適用もできる。
- 公開や送信など勝手に動かしたくない手順は、frontmatter に `disable-model-invocation: true` を設定して自動実行を止める。

## 練習
これまで二度以上くり返して伝えた作業手順を一つ選び、「いつ使うか（description）」「実行手順」「自動実行を止めるべきか」を短いメモにまとめてみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=pa5wTuDmXQE
- 参考：Claude Academy「Skills」
- https://academy.claude.com/courses/claude-code-101/skills
- 公式ドキュメント：https://code.claude.com/docs/en/skills

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。公開前チェックの例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=pa5wTuDmXQE',
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
