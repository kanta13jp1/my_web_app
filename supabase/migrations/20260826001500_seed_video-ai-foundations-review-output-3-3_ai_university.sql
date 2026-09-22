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
  'video_ai_foundations_review_output_3_3',
  'AIの回答をCLEARで見直す｜5つの確認ポイント【AI Foundations 3.3】',
  $content$# 学習ゴール

ChatGPTが生成した回答を完成品として受け取らず、CLEARの5つの観点で確認し、目的に合う安全で使いやすい内容へ改善できるようになります。

## 学べること

- Completeでは、依頼した項目がすべて含まれ、必要な情報や次の行動が欠けていないかを確認すること
- Logicalでは、説明の順序、前提と結論、手順のつながりが最初から最後まで矛盾していないかを確認すること
- Evidenceでは、もっともらしさだけで判断せず、重要な事実、数値、出典、最新情報を信頼できる情報源で確かめること
- Audienceでは、専門用語、語調、詳しさ、形式が実際に読む人や使う人に合っているかを確認すること
- Relevantでは、回答が依頼の目的に集中し、不要な脱線や使わない情報を含んでいないかを確認すること

## 練習

ChatGPTに、仕事や学習で使う短い文章を一つ作成してもらってください。生成された回答をComplete、Logical、Evidence、Audience、Relevantの順に確認し、それぞれ「問題なし」「要修正」「追加確認が必要」のいずれかを記録します。少なくとも一つ改善指示を追加して再生成し、初回回答と比べて何が良くなったかを説明してください。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 3.3 “Review the output”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=y8_yNuJHe-U',
  '2026-08-26',
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
