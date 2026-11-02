-- Preserve the earlier lesson; add the separately approved September 27 revision.
INSERT INTO public.ai_university_content
  (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES (
  'anthropic',
  'video_claude_code_101_your_first_prompt_20260927',
  'Claude Codeへの最初の指示｜目的・制約・Planモードと結果の確認【Claude Code 101 #4】',
  $lesson$# 学習ゴール

Claude Codeへの依頼に目的・制約・確認方法を含め、計画と実行結果を自分で確認できるようになります。

## 学べること

- 曖昧な依頼を、具体的な検索機能の依頼に変える方法
- Planモードで編集前に調査と計画を確認すること
- 編集の自動承認とコマンド実行の許可を区別すること
- 検索結果・ゼロ件表示・並び順を実際に確認すること

## 実践

練習用プロジェクトで小さな変更を一つ選び、目的・変えない条件・完成を確かめる方法を書いてください。まず編集せず計画を説明してもらい、範囲を確認した後に実行します。最後に差分と動作を確認してください。

## 出典・注記

- [Claude Academy — Your first prompt](https://academy.claude.com/courses/claude-code-101/your-first-prompt)
- 2026年9月27日確認。公式教材を参考にした独自の要約・解説であり、公式翻訳ではありません。
- 説明用の図解とGemini 3.8 Flash TTS（Kore）のAI生成音声を使用しています。
- 機能や権限の動作は環境・設定によって異なります。旧教材を削除せず追加した新版です。$lesson$,
  'https://www.youtube.com/watch?v=zBLlOoS6Mp0',
  DATE '2026-09-27',
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
