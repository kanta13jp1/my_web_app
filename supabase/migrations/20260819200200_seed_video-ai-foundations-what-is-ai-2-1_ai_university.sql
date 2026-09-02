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
  'video_ai_foundations_what_is_ai_2_1',
  'AIとは何か？ChatGPT・LLMとの関係をやさしく解説｜AI Foundations 2.1【日本語解説】',
  $content$## 学習ゴール

AI、大規模言語モデル（LLM）、ChatGPTの関係を整理し、AIの出力を人が確認して安全に活用する基本姿勢を身につけます。

## この動画のポイント

1. **AI** — 文章整理、画像認識、質問応答、生成など、人の知的な作業を支援する技術の総称です。
2. **LLM** — 大量の文章から言葉のパターンを学び、入力された指示に応じて自然な回答を組み立てるAIモデルです。
3. **ChatGPT** — LLMを中心に、ファイル、検索、画像、コード、データ分析、安全機能などを組み合わせたAIツールです。
4. **実務での活用** — 箇条書きのメモを、読み手に伝わりやすいプロジェクト進捗報告の草案へ整理できます。
5. **人の判断** — 内容が正確か、共有してよい情報か、目的に合っているかを確認し、利用できる状態かどうかを人が決めます。

## 実践課題

日常の小さな作業からメモを3〜5個選び、ChatGPTへ「読み手に伝わる進捗報告に整理してください」と依頼してみましょう。回答が出たら、事実関係、共有範囲、目的への適合という3点を自分で確認し、必要な箇所を修正してください。

## 出典と位置づけ

参考：OpenAI Academy「AI Foundations」
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

この教材は、参考内容をもとに独自に構成した日本語の要約・解説です。OpenAI公式の翻訳教材ではありません。$content$,
  'https://www.youtube.com/watch?v=QfyU7N4aVTg',
  '2026-08-19',
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
