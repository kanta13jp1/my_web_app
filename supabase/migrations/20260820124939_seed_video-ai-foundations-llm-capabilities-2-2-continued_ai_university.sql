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
  'video_ai_foundations_llm_capabilities_2_2_continued',
  '曖昧な指示を使える依頼へ｜文脈・確認・改善のコツ【AI Foundations 2.2 続編】',
  $content$# 学習ゴール

ChatGPTへの曖昧な依頼を、読み手・背景・条件・出力形式を備えた実用的な指示へ改善し、回答を確認・修正して使えるようになります。

## 学べること

- LLMが指示と会話の流れを文脈として回答を生成する仕組み
- 短い依頼に読み手、背景、条件、出力形式を追加する方法
- 短い指示と文脈を加えた指示の回答を比較する見方
- 数字、日付、固有名詞などを確認し、不足条件を伝えて改善する流れ
- 文章・画像・音声・動画でも目的、文脈、形式、確認が共通すること

## 練習

今日行う小さな作業を一つ選び、まず短い指示で依頼します。次に「誰向けか」「背景」「守る条件」「出力形式」を追加して再度依頼し、2つの回答の違いと確認すべき事実をメモしてください。

## 出典

参考：OpenAI Academy — AI Foundations
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=KWURBiF0kAs',
  '2026-08-20',
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
