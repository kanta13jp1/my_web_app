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
  'video_claude_code_101_overview',
  'Claude Code 101を1時間で学ぶ｜公式講座の全体像【日本語解説】',
  $content$# 学習ゴール

Claude Codeの基本的なエージェント動作と安全な開発手順を理解し、小さく検証可能な課題で「探索・計画・実装・確認」を実践できるようになります。

## この動画で学べること

- Claude Codeが、コードベースの調査、ファイル編集、コマンド実行、結果検証を行うエージェント型開発ツールであること
- 状況を集める、作業する、結果を検証する、という基本ループと、人が途中で方向を修正する重要性
- 目的、制約、確認方法を含む具体的なプロンプトで作業範囲を明確にする方法
- Explore → Plan → Code → Commitの順で、既存設計とテストを確認してから安全に変更を進める考え方
- コンテキスト管理、コードレビュー、CLAUDE.md、サブエージェント、スキル、MCP、フックを使って反復作業を改善する方法

## 実践してみよう

1. 影響範囲が小さく、結果を確認しやすい警告やテスト失敗を1つ選びます。
2. Claude Codeへ、原因調査、修正前の説明、変更範囲、実行する確認方法をまとめて依頼します。
3. 提案された計画と差分を読み、目的外の変更が含まれていないか確認します。
4. 対象テストまたは静的解析を実行し、結果と残るリスクを説明してもらいます。
5. 繰り返し使う開発ルールが見つかったら、CLAUDE.mdやスキルへ記録します。

## 出典・注記

- [Claude Code 101 — Claude Academy](https://academy.claude.com/courses/claude-code-101)
- [Claude Code overview — Anthropic公式ドキュメント](https://code.claude.com/docs/en/overview)
- この教材は、公開されているAnthropic公式教材と公式ドキュメントを参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。
- 機能、画面、受講条件などは更新される可能性があります。2026年8月29日時点の情報として扱い、最新情報は公式サイトで確認してください。$content$,
  'https://www.youtube.com/watch?v=Pe-2A1Rq6Hc',
  '2026-08-29',
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
