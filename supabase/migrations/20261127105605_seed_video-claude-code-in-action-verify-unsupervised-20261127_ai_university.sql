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
  'video_claude_code_in_action_verify_unsupervised_20261127',
  'Claude Code無人実行の検証型｜auto限界・git diff範囲外検知・exit 2関門・無記憶査読【実践Claude Code #8】',
  $content$# Claude Code無人実行の検証型（実践Claude Code #8）

## 学習目標
無人実行や CI で完了した Claude Code の成果物について、任せた裁量に応じた検証水準を設定し、`auto` モードの限界理解・`git diff` 計画外変更検出・`Stop (exit 2)` フック関門・無記憶サブエージェント査読を組み合わせて安全に検収できるようになる。

## ポイント
- **基本原則と `auto` モードの境界**: 見ていなかった度合いが大きいほど厳密に検証する。無人実行は完全免除ではなく `auto` モードを維持して危険操作の分類器を残すが、**分類器はコードの正しさを保証しない**ため、品質確認の基準は一切下げない。
- **要約より先に `diff` を読む**: 完了報告の文章は計画外ファイルへの変更を隠してしまうことがある。まず `/code-review` で論点を洗い出し、`git diff` で「計画したファイル」に続いて「計画外の想定外ファイル」が変更されていないかを目視確認する。
- **テストを約束ではなく `exit 2` フックの関門にする**: 編集毎の `PostToolUse`（Lint・型チェック）と、失敗時に `exit 2` でターン終了を阻止し Claude へ修正を促す `Stop` フックを組むことでスキップを防ぐ。ヘッドレス実行は JSON 出力と終了コードで確認する。
- **冷静な第二の意見（Cold second opinion）**: 実装経緯の記憶を持たない別セッションやサブエージェントに差分をレビューさせ、元セッションの思い込みや妥協を排する。

## 練習
次に無人実行や長時間セッションを終えたタイミングで、① `git diff --stat` で計画外ファイルの有無を最初に確認し、② `Stop` フック（`exit 2`）でテスト通過を強制できていたか点検し、③ 実装文脈を渡さない新規セッションへ差分のみのレビューを 1 回依頼してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=jlMxwUuRbZ8
- 参考：Claude Academy「Trust it: Verifying unsupervised runs」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/trust-it-verifying-unsupervised-runs
  - https://academy.claude.com/ja/courses/claude-code-in-action/trust-it-verifying-unsupervised-runs
- 公式ドキュメント入口：https://code.claude.com/docs/en/overview

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。無人リファクタ検収フローの図解・練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=jlMxwUuRbZ8',
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
