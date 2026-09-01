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
  'video_claude_code_101_installing_claude_code',
  'Claude Codeのインストールと初期設定｜ターミナルから動くAIコーディングエージェント【Claude Code 101】',
  $content$# 学習ゴール

Anthropicが提供するエージェント型コーディングツール「Claude Code」を自身の開発環境にインストールし、初期認証を完了してターミナルから利用開始できるようになります。

## この動画で学べること

- Claude Codeは、ターミナルから直接コードの作成、編集、バグ修正、テスト実行を自律的に行えるAIコーディングエージェントであること
- お使いのOS（macOS / Linux / WSL / Windows PowerShell）に応じたワンライナーコマンドで簡単にインストールできること
- インストール完了後、ターミナルで「claude」コマンドを実行するとブラウザ認証連携が起動すること
- Claude Pro / Max / Teamプラン、またはAPIコンソールキーを接続して即座に対話型開発が始められること
- 安全なエージェント型開発を行うために、実行計画の確認や変更差分の検証手順を把握できること

## 実践してみよう

1. お使いのOS環境（PowerShell / macOSターミナル / WSLなど）を開きます。
2. OSごとのインストールスクリプト（Windows: irm https://claude.ai/install.ps1 | iex、Mac/Linux/WSL: curl -fsSL https://claude.ai/install.sh | bash）を実行します。
3. ターミナルで claude と入力して起動し、画面の指示に従ってブラウザでアカウント認証を完了します。
4. プロジェクトフォルダに移動してClaude Codeを起動し、簡単なコード質問やファイル一覧確認などの指示を試してみましょう。

## 出典・注記

- [Claude Code 101「Installing Claude Code」— Claude Academy](https://academy.claude.com/ja/courses/claude-code-101/installing-claude-code)
- [Claude Code Setup & Installation Guide — Anthropic公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code/setup)
- この教材は、公開されているAnthropic公式教材と公式ドキュメントを参考に制作した独立した要約・解説です。Anthropicによる公式動画、公式翻訳、公式見解ではありません。$content$,
  'https://www.youtube.com/watch?v=gLG3Zzh2FsY',
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
