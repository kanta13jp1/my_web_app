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
  'video_ai_foundations_check_in_1_3',
  'AIを実践的に学ぶ3つの習慣｜AI Foundations 1.3 Check-in【日本語解説】',
  $content$## 学習ゴール

AIを「学ぶ・試す・判断する」の3段階で捉え、ChatGPTを日々の小さな課題へ安全かつ実践的に活用できるようになります。

## この動画のポイント

1. **学ぶ** — AI、大規模言語モデル、ChatGPTの役割を、難しい専門用語だけに頼らず自分の言葉で説明します。
2. **試す** — 短いプロンプトから始め、目的・背景・条件を追加しながら回答を改善します。
3. **判断する** — 個人情報や機密情報を共有せず、AIの回答を確認してから利用します。
4. **小さく続ける** — 毎日扱える課題を一つ決め、同じ課題でプロンプト、文脈、確認方法を少しずつ磨きます。

## 実践課題

今日行う小さな作業を一つ選び、まず一文のプロンプトを書いてください。次に「目的」「背景」「守る条件」を一つずつ加え、最初の回答と改善後の回答を比較します。利用前に、共有してはいけない情報が含まれていないか、回答内容が正しいかを自分で確認してください。

## 出典と位置づけ

参考：OpenAI Academy「AI Foundations」
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

この教材は、参考内容をもとに独自に構成した日本語の要約・解説です。OpenAI公式の翻訳教材ではありません。$content$,
  'https://www.youtube.com/watch?v=ejHBZzoZxRs',
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
