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
  'video_claude_code_in_action_github_actions_review_20261127',
  'Claude CodeのPR連携｜マネージドCode ReviewとGitHub Action・dontAsk安全設計【実践Claude Code #7】',
  $content$# Claude CodeのPR連携（実践Claude Code #7）

## 学習目標
プルリクエスト自動化について、指摘専用のマネージド「Code Review」と、修正・定期処理まで実行できる「GitHub Action（`anthropics/claude-code-action@v1`）」の境界線・認証方式・`claude_args` による無人安全制御を設計できるようになる。

## ポイント
- **マネージド Code Review（Team / Enterprise）**: Org Owner が管理設定から有効化すると、複数エージェントが全体コードベースを踏まえて重要指摘をランク付けし、インラインコメントと要約テーブルを投稿する。実行タイミングは毎 push・PR 作成時 1 回・`@claude review` コメント時の 3 択。PR の承認・ブロック・push は行わないため、手元修正には `/code-review --fix` を併用する。
- **GitHub Action（`anthropics/claude-code-action@v1`）**: `/install-github-app`（管理者権限要）で導入でき、`prompt` 省略時は `@claude` メンション待機、`prompt` 指定時は `schedule`（cron）や `workflow_dispatch` で即時実行する。
- **無人 CI の安全制御（`claude_args`）**: `--max-turns` でループ上限を設けつつ小変更でも途中失敗しない余裕を確保し、レポートやトリアージ等の読取ジョブでは `--allowedTools` に最小限の読取ツールのみを列挙して `--permission-mode dontAsk` で許可外ツールを確実に拒否する。
- **柔軟な認証・実行基盤**: `anthropic_api_key` のほか、`claude_code_oauth_token`、Workload Identity Federation（シークレット保存不要）、`use_bedrock` / `use_vertex` / `use_foundry`、カスタム `github_token` を選択できる。

## 練習
管理中のリポジトリで自動化したい PR 作業を 1 つ選び、① 指摘だけで済むか（Code Review）、② コミットや要約生成が必要か（GitHub Action）、③ Action を使う場合に `--permission-mode dontAsk` と `--allowedTools` へ残すべき最小権限をメモに書き出してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=cikFU69WeyE
- 参考：Claude Academy「GitHub Actions and Code Review」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/github-actions-and-code-review
  - https://academy.claude.com/ja/courses/claude-code-in-action/github-actions-and-code-review
- 設定ガイド：https://code.claude.com/docs/en/code-review-setup

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。読取専用 PR 影響確認ワークフローの例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=cikFU69WeyE',
  '2026-11-27',
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
