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
  'video_openai_ai_foundations_learn_chatgpt',
  'ChatGPTと上手に学ぶ方法｜AI Foundations 1.2【日本語解説・アニメ版】',
  $content$# 学習目標

ChatGPTへ目的・背景・必要な支援を具体的に伝え、安全な練習課題を使って回答を確認・改善しながら学習に活用できるようになります。

# 学習の要点

1. プロンプトはChatGPTへ渡す質問や指示です。専門知識よりも、相手に意図が伝わる言葉で説明することが重要です。
2. ChatGPTには、難しい概念の言い換え、仕事や学習に合う具体例、練習問題、クイズ、活用方法の提案を依頼できます。
3. 「自分の目的」「取り組む課題」「背景や条件」「どのような支援がほしいか」を加えるほど、自分に合った回答を得やすくなります。
4. 最初の回答を完成品と考えず、分かりにくい点や不足している情報を伝えて、対話を重ねながら改善します。
5. 日常の小さく低リスクな課題で練習し、個人情報・機密情報・公開できない内容は入力せず、最終判断は自分で行います。

# 実践演習

毎日行う小さな作業を一つ選んでください。例えば、メールの下書き、会議メモの整理、学習計画づくり、文章の要約です。「私の目的」「課題」「背景や守る条件」「ChatGPTにしてほしい支援」を一文ずつ書いてプロンプトにまとめ、回答を実行前に確認します。次に、改善したい点を一つ具体的に伝えて回答を更新し、最初の回答との違いを振り返りましょう。

# 参考・出典

- 公開動画: https://www.youtube.com/watch?v=QJ-oM6DcMz4
- OpenAI Academy — AI Foundations 1.2 Learn with ChatGPT: https://academy.openai.com/learn/ai-foundations-juzjs/lessons

この教材と動画は、上記のOpenAI公式コンテンツを参考に独自に再構成した日本語の要約・解説です。OpenAIによる公式翻訳・公式教材ではありません。$content$,
  'https://www.youtube.com/watch?v=QJ-oM6DcMz4',
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
