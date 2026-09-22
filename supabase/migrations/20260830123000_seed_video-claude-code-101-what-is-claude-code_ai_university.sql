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
  'anthropic',
  'video_claude_code_101_what_is_claude_code',
  'Claude Codeとは？会話AIとの違いとできること｜Claude Code 101 #1【日本語解説】',
  $content$# 学習ゴール

一般的な会話AIとClaude Codeの違いを理解し、Claude Codeへ安全に小さな開発作業を任せるための基本的な考え方を説明できるようになります。

## この動画で学べること

- 会話AIが主に質問へ文章で答えるのに対し、Claude Codeはコードベースやファイルを読み、許可されたコマンドを実行して作業を進めるコーディングエージェントであること
- Claude Codeが、状況の調査、変更、テストや静的解析による検証を一つの作業ループとして扱えること
- 人が目的、変更範囲、制約、完了条件を伝え、提案や差分を確認することが安全な利用の前提になること
- 最初は影響範囲が小さく、結果を確認しやすい課題から始めると、Claude Codeの能力と限界を把握しやすいこと

## 実践してみよう

1. 自分のプロジェクトから、ドキュメントの修正や小さな警告の解消など、失敗しても影響の小さい課題を一つ選びます。
2. Claude Codeへ、目的、変更してよい範囲、変更してはいけない範囲、確認方法を含めて依頼します。
3. 実行前の説明と変更後の差分を読み、依頼していない変更が含まれていないか確認します。
4. 対象テストや静的解析の結果を確認し、未確認事項と残るリスクを説明してもらいます。

## 出典・注記

- [Claude Code 101「Claude Codeとは？」— Claude Academy](https://academy.claude.com/ja/courses/claude-code-101/what-is-claude-code)
- [Claude Code overview — Anthropic公式ドキュメント](https://code.claude.com/docs/en/overview)
- この教材は、公開されているAnthropic公式教材と公式ドキュメントを参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。
- 機能や画面は更新される可能性があります。2026年8月30日時点の情報として扱い、最新情報は公式サイトで確認してください。$content$,
  'https://www.youtube.com/watch?v=BjOtCEYRzmc',
  '2026-08-30',
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
