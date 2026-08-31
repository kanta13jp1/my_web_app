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
  'video_claude_code_101_how_claude_code_works',
  'Claude Codeはどう動く？エージェントループ・コンテキスト・権限を解説｜Claude Code 101 #2【日本語解説】',
  $content$# 学習ゴール

Claude Codeが「情報収集・実行・検証」を繰り返して作業を進める仕組みを理解し、コンテキストと権限を適切に設定して安全に開発を任せられるようになります。

## この動画で学べること

- Claude Codeは回答文を返すだけでなく、関連ファイルやコマンド結果から情報を集め、変更を実行し、結果を検証するエージェントループで動くこと
- 検証結果が不十分なときは、追加調査、再実行、再検証へ戻り、ユーザーも途中で情報追加、停止、方向修正ができること
- 会話、ファイル内容、コマンド出力はコンテキストウィンドウに入り、情報量が増えると重要事項を残すコンパクションが行われること
- ファイルの読み取り、検索、編集、コマンド実行を可能にするツールと、手動確認・編集承認・読み取り専用計画・保護付き自動実行などの権限設定を、作業リスクに応じて使い分けること
- 安全に任せるには、目的、変更範囲、禁止事項、確認方法を先に明確にし、実行後の差分と検証結果を人が確認すること

## 実践してみよう

1. 自分のプロジェクトから、ドキュメント修正や小さな警告解消など、影響範囲を限定できる課題を一つ選びます。
2. Claude Codeへ、目的、変更してよいファイル、変更してはいけない範囲、完了条件を伝え、まず計画だけを作成してもらいます。
3. 計画を確認してから実行を許可し、どの情報を集め、何を変更し、どのテストや静的解析で検証したかを説明してもらいます。
4. 差分と検証結果を自分でも確認し、不足があれば追加コンテキストを渡して、もう一度エージェントループを回します。

## 出典・注記

- [Claude Code 101「How Claude Code works」— Claude Academy](https://academy.claude.com/ja/courses/claude-code-101/how-claude-code-works)
- [Claude Code overview — Anthropic公式ドキュメント](https://code.claude.com/docs/en/overview)
- この教材は、公開されているAnthropic公式教材と公式ドキュメントを参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。
- 機能、権限モード、画面は更新される可能性があります。2026年8月31日時点の情報として扱い、最新情報は公式サイトで確認してください。$content$,
  'https://www.youtube.com/watch?v=wqjrEI6GcYE',
  '2026-08-31',
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
