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
  'video_ai_foundations_how_models_are_trained_2_3',
  'AIモデルはどう学ぶ？事前学習から継続改善まで【AI Foundations 2.3】',
  $content$# 学習ゴール

AIモデルが事前学習、事後学習、製品体験、継続的な研究・評価を経て、ChatGPTのような製品として使われるまでの関係を説明できるようになります。

## 学べること

- AIの学習は人間の経験的な理解とは異なり、データに含まれるパターンを利用すること
- 事前学習が言葉や概念の関係を扱う基礎を作ること
- 事後学習が役立ち、安全で、指示に沿った回答へモデルを調整すること
- ChatGPTはモデル単体ではなく、会話、履歴、ファイル、検索、安全機能などを組み合わせた製品であること
- 一回の会話でモデルが即座に再学習するのではなく、研究・評価・設計・検証を通じて改善されること

## 練習

一つのテーマを選び、ChatGPTに「一文」「三つの箇条書き」「初心者向け」の三形式で説明を依頼してください。回答を比較し、指示と製品側の文脈によって表現がどう変化したか、また利用前に何を確認すべきかをメモします。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 2.3 “How models are trained”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=5wVvLi-H8PE',
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
