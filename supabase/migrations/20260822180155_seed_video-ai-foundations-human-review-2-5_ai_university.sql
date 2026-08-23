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
  'openai',
  'video_ai_foundations_human_review_2_5',
  'AIはなぜ人の確認が必要？ハルシネーションとレビューの基本【AI Foundations 2.5】',
  $content$# 学習ゴール

AIが自然で自信のある回答を返してもそのまま正解とはみなさず、文脈・根拠・目的への適合性・共有の安全性を人が確認して最終判断できるようになります。

## 学べること

- ハルシネーションとは、もっともらしく見えても適切な情報に根拠づけられていないAI回答であること
- 文脈が少ない依頼ほどAIによる推測が増え、対象者、組織、必要項目、期間などを加えると確認しやすい回答になること
- 不足情報があるときは、AIに推測させるのではなく、完成前に必要な質問をさせること
- `FACT / SOURCE / FIT / SHARE`の順で、事実、出典、目的への適合性、安全に共有できる内容かを確認すること
- `CONTEXT → SOURCE → REVIEW → DECIDE`を習慣化し、利用・修正・破棄の最終判断は人が行うこと

## 練習

日常業務から、オンボーディングチェックリストのような小さく低リスクな作業を一つ選びます。最初に短い依頼だけでChatGPTへ質問し、次に対象者、組織や業界、必要な項目、期間、不足情報を質問する指示を追加して再度依頼してください。二つの回答を比べ、`FACT / SOURCE / FIT / SHARE`の四項目で確認し、そのまま使える部分、修正が必要な部分、追加確認が必要な部分を記録します。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 2.5 “Why AI needs human review”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=ib7mIx5p7Wo',
  '2026-08-22',
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
