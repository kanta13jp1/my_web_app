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
  'video_ai_foundations_clear_instructions_3_1',
  '明確な指示がAIの回答を変える｜Task・Context・Expectation【AI Foundations 3.1】',
  $content$# 学習ゴール

ChatGPTへの依頼を、Task（何をしてほしいか）、Context（判断に必要な背景）、Expectation（望む形式・品質）の3要素で明確にし、用途に合う回答を得られるようになります。

## 学べること

- 曖昧な指示では、ChatGPTが目的・対象読者・重要点・長さなどを推測する必要があること
- Taskで、要約・説明・作成などの具体的な作業を明示すること
- Contextで、対象読者、背景、資料、利用場面など、判断に必要な情報を加えること
- Expectationで、文章の長さ、形式、語調、含める項目など、良い回答の基準を示すこと
- 生成結果をCLEAR（Complete、Logical、Evidence、Audience、Relevant）の観点で確認し、必要に応じて指示を改善すること

## 練習

普段使っている曖昧な依頼を一つ選びます。最初にTask、Context、Expectationの3項目へ分解し、それぞれを一文で書いてから一つのプロンプトにまとめてください。回答をCLEARの5観点で確認し、不足している情報を一つ追加して再実行し、回答がどう変わったかを比較します。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 3.1 “Why clear instructions matter”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=2rzqAjG6Ih8',
  '2026-08-23',
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
