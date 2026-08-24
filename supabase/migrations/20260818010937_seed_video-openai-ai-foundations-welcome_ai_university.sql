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
  'video_openai_ai_foundations_welcome',
  'AI Foundationsへようこそ｜AIを正しく学び、使いこなす5つの基礎',
  $content$# 学習目標

AIと大規模言語モデルの基礎を説明し、ChatGPTへ明確に依頼し、回答を自分で評価・改善しながら責任を持って活用できるようになります。

# 学習の要点

1. AIと大規模言語モデルが何をする技術なのかを、難しい専門用語に頼らず整理します。
2. ChatGPTが入力された文章と文脈を受け取り、回答を組み立てる大まかな仕組みを理解します。
3. 目的、背景、条件、ほしい出力形式を具体的に伝えることで、回答の実用性を高められます。
4. 生成された回答をそのまま採用せず、事実・目的との一致・不足点を確認し、追加指示で改善します。
5. 個人情報や機密情報を入力せず、誤りの可能性を考慮し、重要な判断は人が行います。

# 実践演習

メールの下書き、文章の要約、予定整理、アイデア出しなど、毎日行う小さな作業を一つ選んでください。「目的」「背景」「守る条件」「ほしい形式」を含むプロンプトを作成してChatGPTへ入力し、返ってきた回答の良い点と改善点を一つずつ挙げて、追加指示で一度改善しましょう。入力前に、個人情報や公開できない内容が含まれていないことも確認してください。

# 参考・出典

- 公開動画: https://www.youtube.com/watch?v=yGCLS7EW91A
- OpenAI Academy — AI Foundations: https://academy.openai.com/learn/ai-foundations-juzjs/lessons

この教材と動画は、上記のOpenAI公式コンテンツを参考に独自に再構成した日本語の要約・解説です。OpenAIによる公式翻訳・公式教材ではありません。$content$,
  'https://www.youtube.com/watch?v=yGCLS7EW91A',
  '2026-08-18',
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
