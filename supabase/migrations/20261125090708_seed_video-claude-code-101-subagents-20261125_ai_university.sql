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
  'video_claude_code_101_subagents_20261125',
  'Claude Codeのサブエージェント｜調査を任せて、根拠を受け取る【Claude Code 101 #9】',
  $content$# Claude Codeのサブエージェント

## 学習目標
調査を別のコンテキストへ切り出して任せ、必要な要約と根拠を受け取って本題を進める。

## ポイント
- サブエージェントはメインの会話とは別のコンテキストで作業し、調べた経緯ではなく必要な要約を返す。
- 「何を対象にし、何を変更せず、どんな根拠を返すか」を明確にしてから任せる。
- `/agents` のメニューから、調査担当は読み取り中心にするなど役割と使えるツールを絞る。
- 会話のコンテキストが別でもファイル隔離や品質保証にはならないため、該当ファイルやテストで確かめる。

## 練習
動画一覧に新しい教材を追加したい場面を想定し、「変更しない範囲」「調査対象」「報告してほしい根拠」の3点を1つにまとめて依頼文を書いてみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=UVp1Y3FE-Uk
- 参考：Claude Academy「Subagents」
- https://academy.claude.com/courses/claude-code-101/subagents

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。動画一覧の調査例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=UVp1Y3FE-Uk',
  '2026-11-25',
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
