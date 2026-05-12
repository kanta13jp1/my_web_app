-- PS#3 S149: AI大学 Claude Code Masterclass 追加 (Issue #1797)
-- Source: 1aced136 Claude Code Masterclass: From Foundations to Agentic Workflows

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'claude_code', 'masterclass_agentic',
  'Claude Code マスタークラス — Foundations〜Agentic Workflows完全習得・12インスタンスfleet設計まで (10/10)',
  $$## Claude Code マスタークラスとは

**Claude Code** (Anthropic CLI) は「コーディングに特化したClaude」ではなく、**ソフトウェアエンジニアリング全体を自律実行するAIエージェント**。マスタークラスでは基礎から最高度な「エージェントワークフロー構築」まで体系的に習得する。

## Level 1: Foundations (基礎)

```
[インストールと認証]
  npm install -g @anthropic-ai/claude-code
  claude  # 初回起動で認証

[基本操作]
  ・チャット形式でのコード生成・編集
  ・ファイル読み書き・Bash実行の許可モデル
  ・CLAUDE.md でプロジェクト固有ルールを設定
  ・/help, /clear, /compact コマンド

[Permission Mode]
  ・--dangerously-skip-permissions: 全自動（CI用）
  ・通常: ツール実行ごとにユーザー承認
  ・Hooks: 特定ツール実行時に自動スクリプト起動
```

## Level 2: Intermediate (中級)

```
[MCP (Model Context Protocol)]
  ・外部ツールをClaude Codeに接続
  ・GitHub MCP: PR操作・Issue管理
  ・Figma MCP: デザイン取込み
  ・Playwright MCP: ブラウザ自動化
  ・Context7 MCP: ライブラリ最新ドキュメント取得

[Hooks システム]
  ・UserPromptSubmit: プロンプト前処理・ルール注入
  ・PostToolUse: ツール実行後の自動処理
  ・Notification: 長時間タスク完了通知

[Memory システム]
  ・CLAUDE.md: プロジェクトファクト（毎セッション読込）
  ・memory/: セッション間で記憶が必要な情報
  ・~/.claude/hooks/inject-rules.txt: 毎ターン強制注入ルール
```

## Level 3: Advanced (上級)

```
[Sub-Agents パターン]
  ・Agent() ツールで専門エージェントを起動
  ・explore, general-purpose, plan, design-skills など
  ・並列実行で独立タスクを同時処理
  ・worktree 分離で各エージェントが干渉しない

[Multi-Instance Fleet]
  ・12インスタンス (Claude Code 10 + Codex 2) を役割分担
  ・instance-vscode: Flutter UI専任
  ・instance-win: docs + migration専任
  ・instance-ps1〜6: 各種専任ルーチン
  ・git worktree で完全隔離

[Schedule タスク]
  ・/schedule でcronベースの自動エージェント起動
  ・daily-report / cs-check / competitor-monitoring など
  ・GHA workflow との連携で完全自動化
```

## Level 4: Mastery (習熟)

```
[HARNESS Engineering]
  ・Claude Code自体を「操作する仕組み」を設計
  ・inject-rules.txt で毎ターン遵守率を高める
  ・Auto-capture hooks でセッション内容を自動記録
  ・claude-mem (SQLite + Gemini圧縮) で知識を永続化

[Agentic Workflow 設計]
  ・Generator-Verifier: 生成→検証のループ
  ・Orchestrator-Subagent: タスク分解・委譲
  ・Agent Teams: 並列独立タスク
  ・Message Bus: イベント駆動エコシステム
  ・Shared State: Supabase DB / memory/ で知識共有
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 開発ツール / Claudeエコシステム / AI駆動開発学科
- **関連プロバイダー**: Claude / Anthropic / GitHub Copilot / Cursor / Devin
- **実用的示唆**: Level 3の「12インスタンスfleet設計」が
  自分株式会社の実際の運用と完全に一致 → 最先端実践例として提示可能
$$,
  'https://docs.anthropic.com/claude-code/',
  '2026-01-01',
  98
)
ON CONFLICT (provider, category) DO NOTHING;
