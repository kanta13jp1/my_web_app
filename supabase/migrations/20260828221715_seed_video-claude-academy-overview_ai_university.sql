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
  'video_claude_academy_overview',
  'Claude Academyとは？公式教材から最短ルートを選ぶ方法【日本語解説】',
  $content$# 学習ゴール

Claude Academyの主要な学習ルートを理解し、自分の目的に合う最初の教材を選んで、小さな実務で試せるようになります。

## この動画で学べること

- Claude.ai、Claude Cowork、Claude Code、Claude Tag、Claude Platformの5つの学習ルートと、それぞれが想定する利用場面
- 初学者がClaude 101などの入門教材から無理なく始める考え方
- AI Fluencyを支えるDelegation、Description、Discernment、Diligenceの「4D」
- コース、短いチュートリアル、実務ユースケースから目的に合う教材を選ぶ方法
- 公式教材の更新を確認し、Claudeの出力を自分でレビューして使う重要性

## 実践してみよう

1. 今使いたい製品を、Claude.ai、Cowork、Code、Tag、Platformから1つ選びます。
2. 選んだ製品の101コース、または短いチュートリアルを1つ選びます。
3. 学んだ内容を、文章の整理や小さなコード変更など、失敗しても影響の小さい実務で試します。
4. 結果を4Dの観点で振り返り、次に改善する指示や確認事項を1つ記録します。

## 出典・注記

- [Claude Academy](https://academy.claude.com/)
- この教材は、公開されている公式教材を参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。
- 機能、画面、教材数、利用条件などは更新される可能性があります。2026年8月28日時点の情報として扱い、最新情報は公式サイトで確認してください。$content$,
  'https://www.youtube.com/watch?v=7tsldHpEzTo',
  '2026-08-28',
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
