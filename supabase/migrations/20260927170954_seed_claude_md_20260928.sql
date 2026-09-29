-- Add one approved lesson; retain existing lessons.
INSERT INTO public.ai_university_content
(provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES ('anthropic', 'video_claude_code_101_claude_md_20260928',
'CLAUDE.mdの使い方｜繰り返す注意をプロジェクトのルールに【Claude Code 101 #8】',
$lesson$# CLAUDE.mdの使い方

## 学習目標
繰り返し伝える注意を、短く具体的なプロジェクトルールに整理する。

## ポイント
- CLAUDE.mdはプロジェクトの説明や作業ルールを残すMarkdownファイル。会話の全文保存とは区別する。
- プロジェクトの概要、確認コマンド、守るルールから始める。
- 「きれいに作る」ではなく、何を守り、どう確認するかを書く。
- `/init`で初期案を作ったら、実際の構成や運用と照合する。
- 古い情報を更新し、ルールを書いた後も変更結果をレビューする。

## 練習
最近二度以上伝えた注意を一つ選び、短いルールに書き直してください。たとえば「既存動画を消さず、画面変更後は狭い画面でも確認する」。チーム共通の条件と個人の好みを区別しましょう。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=RJBLLd1UvmQ
- 参考：Claude Academy「The CLAUDE.md file」
- https://academy.claude.com/courses/claude-code-101/the-claude-md-file

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。動画アプリの例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。
$lesson$, 'https://www.youtube.com/watch?v=RJBLLd1UvmQ', DATE '2026-09-28', 0, true)
ON CONFLICT (provider, category) DO UPDATE SET
title=EXCLUDED.title, content=EXCLUDED.content, source_url=EXCLUDED.source_url,
published_at=EXCLUDED.published_at, sort_order=EXCLUDED.sort_order, is_active=EXCLUDED.is_active;
