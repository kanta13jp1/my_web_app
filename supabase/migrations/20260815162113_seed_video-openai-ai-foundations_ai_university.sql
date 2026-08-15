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
  'video_openai_ai_foundations',
  'AIの基礎｜モデル・LLM・ChatGPTの違いをわかりやすく解説',
  $content$# 学習目標

AI、モデル、大規模言語モデル（LLM）、ChatGPTの関係と、学習方法・モデル選択・指示の基本を体系的に説明できるようになります。

# 学習の要点

1. AIは一つの製品名ではなく、データからパターンを学び、役に立つ出力を生み出す技術全体を表すカテゴリーです。
2. モデルは学習したパターンを新しい状況へ応用する仕組みで、音声・画像・予測など得意分野が異なります。
3. LLMは言葉を扱うモデルで、会話の文脈から次に続く可能性の高い言葉を組み立てます。ChatGPTは、そのモデルを使いやすく届ける製品です。
4. 事前学習では大量の情報から基礎能力を身につけ、事後学習では人のフィードバックを通じて指示への従い方、表現、安全性を改善します。
5. 文章整理やアイデア出しには高速なモデル、計画・分析・難しい判断にはリーズニングモデルが適しています。目的、読み手、形式、条件を具体的に伝え、重要な内容は人が確認します。

# 実践演習

日常や仕事からAIに任せたい作業を一つ選び、「目的」「読み手」「ほしい形式」「守る条件」を一文ずつ書いてください。高速モデルとリーズニングモデルのどちらを使うか、その理由と、人が確認すべき点も一つ挙げて実行結果を比較しましょう。

# 参考・出典

- 公開動画: https://www.youtube.com/watch?v=yAbco3K_TLQ
- OpenAI Academy — AI Foundations: https://academy.openai.com/learn/ai-foundations-juzjs/lessons
- OpenAI — AIの基礎: https://openai.com/ja-JP/academy/what-is-ai/

この教材と動画は、上記のOpenAI公式コンテンツを参考に独自に再構成した日本語の要約・解説です。OpenAIによる公式翻訳・公式教材ではありません。$content$,
  'https://www.youtube.com/watch?v=yAbco3K_TLQ',
  '2026-08-15',
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
