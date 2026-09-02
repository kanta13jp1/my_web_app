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
  'video_ai_foundations_task_context_expectation_3_2',
  '良いプロンプトの3要素｜Task・Context・Expectation【AI Foundations 3.2】',
  $content$# 学習ゴール

ChatGPTへの依頼をTask、Context、Expectationの3要素に分けて整理し、目的に合う具体的で使いやすいプロンプトへ組み立てられるようになります。

## 学べること

- Taskでは、メール作成、要約、説明、チェックリスト作成など、ChatGPTに求める成果物や行動を具体的に示すこと
- Contextでは、対象読者、目的、背景、相手の知識、業務上の制約など、回答を判断するための情報を加えること
- Expectationでは、箇条書き、長さ、語調、詳しさ、次の行動など、回答の完成形を指定すること
- Task、Context、Expectationは厳密な公式ではなく、依頼に不足している情報を発見するための柔軟な整理方法であること
- 3要素を一つの依頼文にまとめることで、一般的な回答を実際の仕事で使いやすい回答へ近づけられること

## 練習

普段使っている短く曖昧な依頼を一つ選び、Task、Context、Expectationの三つに分解してください。次に、三つを一つのプロンプトへまとめてChatGPTへ入力します。元の依頼と改善後の依頼で得られた回答を比べ、具体性、読み手への適合、形式、次の行動の四項目で変化を記録してください。

## 出典

参考：OpenAI Academy — AI Foundations, Lesson 3.2 “Task, Context, and Expectation”
https://academy.openai.com/learn/ai-foundations-juzjs/lessons

本教材は上記教材を参考に、学習内容を独自に要約・再構成した日本語解説です。OpenAI公式の翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=e323zNN2lgI',
  '2026-08-24',
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
