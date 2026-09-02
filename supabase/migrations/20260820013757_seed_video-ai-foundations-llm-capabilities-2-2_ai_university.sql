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
  'video_ai_foundations_llm_capabilities_2_2',
  'LLMは何ができる？予測と生成の仕組み【AI Foundations 2.2 日本語解説】',
  $content$## 学習ゴール

大規模言語モデル（LLM）が言葉のパターンと文脈を使って回答を生成する仕組みを理解し、実務の小さな作業へ安全に活用できるようになります。

## この動画のポイント

1. **LLMが支援できること** — 下書き、要約、説明、計画、アイデア出し、情報整理など、言葉を扱う幅広い作業を支援できます。
2. **入力が文脈になる** — 利用者の質問、目的、背景、条件が、回答を作る出発点になります。
3. **一語ずつ予測して生成する** — 回答全体を一度に取り出すのではなく、続く可能性が高い言葉を選び、その結果を次の予測へ加えながら文章を組み立てます。
4. **検索と生成は異なる** — 保存済みの答えをそのまま探すのではなく、学習したパターン、指示、会話の文脈を組み合わせて回答を生成します。
5. **最後は人が判断する** — 自然な文章でも誤りを含む可能性があるため、重要な事実や数字を確認し、目的に合うかを人が判断します。

## 実践課題

日々の仕事から小さな作業を一つ選び、ChatGPTへ「目的」「背景」「希望する出力形式」を含めて依頼してください。得られた回答について、事実が正しいか、共有してよい内容か、目的に合っているかを確認し、必要な箇所を自分で修正してみましょう。

## 出典と位置づけ

参考：OpenAI Academy「AI Foundations」
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

この教材は、参考内容をもとに独自に構成した日本語の要約・解説です。OpenAI公式の翻訳教材ではありません。$content$,
  'https://www.youtube.com/watch?v=ZFVlTcRwNVU',
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
