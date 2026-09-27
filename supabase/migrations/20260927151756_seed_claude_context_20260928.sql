-- Approved additive lesson; retain all existing content.
INSERT INTO public.ai_university_content
(provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES ('anthropic', 'video_claude_code_101_context_20260928',
'Claude Codeのコンテキスト管理｜確認・要約・リセットの使い分け【Claude Code 101 #6】',
$lesson$# Claude Codeのコンテキスト管理

## 学習目標
確認・要約・会話の切替を使い分け、次の判断に必要な情報を残せるようになる。

## ポイント
- コンテキストには会話、読み込んだファイル、ツールの結果が含まれる。
- `/context`で使用状況を確認する。
- 同じ作業を続けるときは`/compact`で要約する。細かな条件が抜ける可能性があるため、重要な決定は別に残す。
- 別の作業へ切り替えるときは`/clear`を使う。会話のリセットであり、プロジェクトのファイル削除ではない。
- 共通ルールはCLAUDE.mdに整理する。

## 練習
会話を整理する前に、目的・決定事項・未解決の問題・次の一手を短い引き継ぎメモにしてください。整理後も守る条件が残っているか確認しましょう。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=aXig8KNtPBI
- 参考：Claude Academy「Context management」
- https://academy.claude.com/ja/courses/claude-code-101/context-management

公開された英語概要を参考にした独自の日本語解説であり、公式翻訳ではありません。図解と練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。
$lesson$, 'https://www.youtube.com/watch?v=aXig8KNtPBI', DATE '2026-09-28', 0, true)
ON CONFLICT (provider, category) DO UPDATE SET
title=EXCLUDED.title, content=EXCLUDED.content, source_url=EXCLUDED.source_url,
published_at=EXCLUDED.published_at, sort_order=EXCLUDED.sort_order, is_active=EXCLUDED.is_active;
