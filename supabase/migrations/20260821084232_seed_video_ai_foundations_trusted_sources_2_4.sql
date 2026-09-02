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
  'video_ai_foundations_trusted_sources_2_4',
  'ChatGPTを情報源にしない｜信頼できる情報を使う方法【AI Foundations 2.4】',
  $content$# 学習ゴール

現在性や正確さが必要な作業で、信頼できる情報源を先に確認し、ChatGPTを整理・要約・比較の作業場として安全に活用できるようになります。

## 学べること

- ChatGPTは便利な作業場であり、常に正しい情報源そのものではないこと
- 現在の事実、規程・法的助言、価格・日付・予定、引用・リンク、正確な原資料、変化し得る情報では、信頼できる情報源やWeb検索を先に使うこと
- 会議メモや承認済み社内資料を渡し、メールやチェックリストへ変換する実務的な使い方
- 複数の信頼できる出典とリンクを保ったまま、短いブリーフィングの下書きを作る方法
- 流暢な回答でも、事実、出典、最終判断を人が確認してから利用すること

## 練習

今日確認する必要がある情報を一つ選び、「最新性や正確さが必要か」を判断してください。必要なら公式情報、承認済み社内資料、信頼できるWeb検索結果のいずれかを用意し、ChatGPTへ「この資料だけを根拠に、要点を三つの箇条書きで整理し、確認が必要な点を最後に示してください」と依頼します。出力を原資料と照合し、事実・出典・最終判断の三点を確認してください。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 2.4 “Know when to use trusted sources”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=VqCeYy7yg28',
  '2026-08-21',
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
