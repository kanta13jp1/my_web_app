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
  'video_claude_code_101_your_first_prompt',
  'Claude Codeに最初の指示を出そう｜Planモードと安全な自律開発サイクル【Claude Code 101】',
  $content$# 学習ゴール

Claude Codeに対話型で最初のプロンプトを指示し、「Planモード」による事前調査・計画立案を活用して安全かつ自律的な開発サイクルを回せるようになります。

## この動画で学べること

- ターミナルで「claude」を実行し、対話型のコーディングセッションをスタートする方法
- 単なる質問への回答にとどまらず、機能追加やバグ修正などの具体的なタスク指示ができること
- いきなりコードを改変させず、読み取り専用で調査と計画を立てさせる「Planモード」の重要性と活用法
- ファイル編集やコマンド実行前にユーザーの承認を挟む安全な権限設計
- 「探索 → 計画 → 実装 → 検証」のサイクルを回し、ターミナル内でGitコミットまで完結するワークフロー

## 実践してみよう

1. ターミナルを開き、開発中のプロジェクトフォルダで `claude` と入力して起動します。
2. まずは「Planモード」を指定して、追加したい機能や修正したい課題の調査と作業計画を依頼します。
3. Claude Codeが提示した探索結果と作業計画（変更対象ファイルや手順）を確認・承認します。
4. 自律的なコード編集とテスト実行を見守り、必要に応じて追加の指示を与えて完成させます。
5. ターミナル内で `git diff` や変更差分を確認し、コミットを行います。

## 出典・注記

- [Claude Code 101「Your First Prompt」— Claude Academy](https://academy.claude.com/ja/courses/claude-code-101/your-first-prompt)
- [Claude Code overview & workflow — Anthropic公式ドキュメント](https://code.claude.com/docs/en/overview)
- この教材は、公開されているAnthropic公式教材と公式ドキュメントを参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。$content$,
  'https://www.youtube.com/watch?v=DDZmhbCebaE',
  '2026-09-01',
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
