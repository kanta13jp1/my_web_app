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
  'video_ai_foundations_check_in_2_6',
  '生成・根拠づけ・確認｜ChatGPTを信頼して使う3つの習慣【AI Foundations 2.6】',
  $content$# 学習ゴール

ChatGPTを使うときに、生成・根拠づけ・確認の三段階を繰り返し、AIの回答を自分の判断で採用、修正、または再実行できるようになります。

## 学べること

- LLMは言葉のパターン、指示、文脈をもとに回答を生成すること
- ChatGPTは下書き、説明、アイデア出し、情報整理に役立つこと
- 正確さが重要なときは、ファイル、検索結果、具体例、信頼できる情報源を与えること
- 回答を使う前に、正確性、目的への適合性、完全性、根拠を人が確認すること
- `依頼を明確にする → 文脈を足す → 採用・修正・再実行を決める`を実践すること

## 練習

日常の小さく低リスクな作業を一つ選び、最初に「何をしてほしいか」を明確に伝えます。次に、判断に必要な背景、具体例、ファイルや信頼できる情報源を加えてください。返ってきた回答を、正確性、目的への適合性、必要情報、根拠の四項目で確認し、採用・修正・再実行のどれにするかを記録します。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 2.6 “Check-in”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=vLTQ_iJuhho',
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
