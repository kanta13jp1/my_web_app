-- Approved additive lesson; retain every existing video.
INSERT INTO public.ai_university_content
(provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES ('anthropic', 'video_claude_code_101_review_20260928',
'Claude Codeのコードレビュー｜差分・別視点・根拠で確かめる【Claude Code 101 #7】',
$lesson$# Claude Codeのコードレビュー

## 学習目標
変更の説明だけで判断せず、実際の差分と検証結果を確認して採用を判断する。

## ポイント
- `/diff`で実際の変更を確認し、依頼外の変更、弱くなったテスト、不要な依存追加に注意する。
- `/code-review`で実装した会話とは別のコンテキストから点検する。まず報告を求め、修正は別に判断する。
- 指摘を「今直す」「根拠を確かめる」「後で対応」に分ける。
- 修正後はテスト結果や必要に応じた画面確認で根拠を確かめる。

## 練習
小さな変更を一つ選び、「依頼した目的」「実際の差分」「確認結果」を並べてください。依頼していない変更があれば必要性を問い、採用する理由を自分の言葉で説明しましょう。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=mStC8dGykwI
- 参考：Claude Academy「Code review」
- https://academy.claude.com/courses/claude-code-101/code-review

公開教材を参考にした独自の日本語解説であり、公式翻訳ではありません。動画表示サイズの修正例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。
$lesson$, 'https://www.youtube.com/watch?v=mStC8dGykwI', DATE '2026-09-28', 0, true)
ON CONFLICT (provider, category) DO UPDATE SET
title=EXCLUDED.title, content=EXCLUDED.content, source_url=EXCLUDED.source_url,
published_at=EXCLUDED.published_at, sort_order=EXCLUDED.sort_order, is_active=EXCLUDED.is_active;
