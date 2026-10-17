-- Add one approved public lesson; preserve all existing videos.
INSERT INTO public.ai_university_content
(provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES (
'anthropic',
'video_claude_code_101_workflow_20260927',
'Claude Code開発の4段階｜調査・計画・実装・コミット【Claude Code 101 #5】',
$lesson$# Claude Code開発の4段階

## 学習目標

調査・計画・実装・コミットを分け、各段階で人が確認する内容を説明できるようになる。

## 学習のポイント

- **調査**：まず関連ファイルや現在の動作を調べる。「まだ編集しないで」と明示し、症状と原因の予想を区別する。
- **計画**：変更方針、維持する条件、成功条件を整理してから実装を承認する。
- **実装**：承認した範囲だけ変更し、テストと実際の動作で成功条件を確認する。
- **コミット**：差分に無関係な変更や秘密情報がないか確認し、意図が分かる名前で記録する。コミットと本番公開は別の操作として扱う。

## 練習

小さな画面改善を一つ選び、次の依頼を自分の状況に合わせて書き換えてください。

「動画が画面からはみ出す問題について、関連する画面とサイズの決め方を調べてください。まだ編集せず、分かった事実、原因の候補、確認が必要な点を分けて報告してください。」

調査後は、守る条件と成功条件をそれぞれ二つ挙げ、変更計画を確認してから実装へ進めましょう。

## 動画と出典

- 解説動画：https://www.youtube.com/watch?v=MQ-379FXaiM
- 参考：Claude Academy — The Explore, Plan, Code, Commit workflow
- https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow

本教材は公開ページのSummaryを参考にした独自の日本語要約・解説であり、公式翻訳ではありません。動画プレーヤーの改善は説明用の独自例です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$lesson$,
'https://www.youtube.com/watch?v=MQ-379FXaiM',
DATE '2026-09-27', 0, true
)
ON CONFLICT (provider, category) DO UPDATE SET
title = EXCLUDED.title, content = EXCLUDED.content,
source_url = EXCLUDED.source_url, published_at = EXCLUDED.published_at,
sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;
