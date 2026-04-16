-- Windowsアプリ版#本セッション: Cognition AI (Devin) 大学コンテンツ seed
-- 世界初の自律AIソフトウェアエンジニア — Devin

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('cognition', 'overview',
'Cognition AI: 自律AIソフトウェアエンジニア「Devin」',
$$# Cognition AI

Cognition AIは「AIソフトウェアエンジニア」を開発するスタートアップ。
代表製品の**Devin**は、GitHub Issue・JiraチケットからPRまで自律的に完結させる世界初のAIエンジニア。

## Devinとは

- **2024年3月公開**: SWE-bench (ソフトウェアエンジニアリングベンチ) でGPT-4を大幅上回り業界を震撼
- **自律的コーディング**: タスクを与えると独立してコードを書き、テストし、PRを作成
- **長時間タスク対応**: 数時間〜数日かかるタスクを並行処理
- **20+ツール統合**: GitHub/GitLab/Jira/Linear/Slack/AWS/GCP/Azure/Snowflake/PostgreSQL等

## 主要機能

| 機能 | 説明 |
|------|------|
| **コードベース理解** | リポジトリ全体を読み込み、構造・コンテキストを把握 |
| **自律的PR作成** | Issue → 実装 → テスト → PR → レビュー対応まで自動化 |
| **バグ修正** | エラーログを受け取り自律的に原因特定・修正 |
| **コードレビュー** | PR差分を分析してセキュリティ・パフォーマンス指摘 |
| **リファクタリング** | 技術的負債の解消を自律実行 |

## 業界インパクト

```
従来: 開発者がタスクを実行
Devin以後: AIが並行してタスクを実行 → 開発者は戦略・設計に集中
```

**評価**: 技術革新性9/9・API公開7/9・話題性9/9
$$,
'https://cognition.ai/devin',
'2026-04-16', 1),

('cognition', 'models',
'Devin: 能力・アーキテクチャ・使用モデル',
$$# Devin の能力とアーキテクチャ

## SWE-bench スコア

| モデル | SWE-bench Verified (%) |
|--------|------------------------|
| **Devin** | **13.86%** (2024年公開時) |
| Claude 3.5 Sonnet | 49% (2024年) |
| GPT-4 | 1.7% |
| SWE-agent + GPT-4 | 12.5% |

※ 2026年現在、Devin 2.0でさらに大幅向上

## コア技術

- **Planning & Reasoning**: 長期タスクの計画立案・ステップ分解
- **Tool Use**: ターミナル・ブラウザ・エディタ・APIを自律使用
- **Memory & Context**: セッション間でコードベース・会話履歴を保持
- **Multi-agent**: サブタスクを並行エージェントに分配

## 対応スタック

```
フロントエンド: React / Vue / Next.js / Flutter
バックエンド:   Node.js / Python / Go / Rust / Java
DB:           PostgreSQL / MySQL / MongoDB / Snowflake
クラウド:      AWS / GCP / Azure / Vercel / Supabase
CI/CD:        GitHub Actions / CircleCI / Jenkins
```

## Devin 2.0 (2025年以降)

- コンテキストウィンドウ大幅拡張 (100K+ tokens)
- 並行エージェント実行 (最大10並行)
- Slack/Linear直接統合での自律タスク受付
$$,
'https://cognition.ai/blog/swe-bench-technical-report',
'2026-04-16', 2),

('cognition', 'api',
'Devin API: 開発者向け統合ガイド',
$$# Devin API & 統合方法

## 利用方法

### 1. Webインターフェース
- `app.devin.ai` でタスク指示
- GitHubリポジトリを接続して自動タスク受付

### 2. GitHub Integration
```yaml
# .github/workflows/devin-tasks.yml
# IssueにDevinをアサインすると自動実行
on:
  issues:
    types: [assigned]
```

### 3. Slack Bot
```
/devin fix the authentication bug in PR #123
/devin refactor the user service to use dependency injection
```

### 4. Linear / Jira Integration
チケットに `@devin` をメンションするだけで自律実行開始

### 5. API (Enterprise)

```python
import cognition

client = cognition.Client(api_key="your_key")

# タスク作成
task = client.tasks.create(
    description="Fix the failing tests in auth/middleware.py",
    repo_url="https://github.com/your/repo",
    branch="main"
)

# 進捗確認
status = client.tasks.get(task.id)
print(status.progress)  # "Writing tests...", "Creating PR..."
```

## 料金 (2026年)

| プラン | 価格 | 制限 |
|--------|------|------|
| **Starter** | $500/月 | タスク250件 |
| **Team** | $2,000/月 | タスク無制限 (5シート) |
| **Enterprise** | カスタム | オンプレ対応可 |

## このプロジェクトとの関連

- `github-issue-fix.yml` → Devinパターンの参考実装
- Claude Code Schedule + GitHub Actions = **自作Devin**パターン
- Devinの「Issue → PR自動化」= Copilot Workspaceと同コンセプト
$$,
'https://cognition.ai/blog',
'2026-04-16', 3),

('cognition', 'news',
'Cognition AI 最新ニュース (2026-04-16)',
$$# Cognition AI 最新動向 (2026-04-16)

## 主要アップデート

### Devin 2.0 リリース (2025年)
初代Devinから大幅進化。より複雑なタスク・長期プロジェクトに対応。
SWE-benchスコアが初代比2倍以上に向上。

### Snowflake MCP統合
DevinがSnowflakeのMCP (Model Context Protocol) サーバーと統合。
データウェアハウスに直接アクセスしてSQL最適化・データパイプライン構築が自律化。

### 資金調達 (2024年)
シリーズBで$175Mを調達。評価額$2B超。
Founders Fund, Khosla Ventures, Atlassian等から投資。

### GitHub Copilot Workspaceとの比較

```
Devin         → 完全自律。数時間かかるタスクも可能。高コスト
Copilot WS    → 計画提案型。人間がステップ承認。無料〜$10/月
Claude Code   → ターミナル直接操作。コンテキスト保持。月$20
```

## 業界への影響

- **「Agentic AI」ブーム**: Devin成功後、各社がエージェント型AIを競って開発
- Cognitionのアーキテクチャ (Plan→Execute→Verify) が業界標準パターンに
- Claude Code、Copilot Workspace、Cursor等のAIコーディングツール進化を加速

## このプロジェクトへの示唆

- `github-issue-fix.yml` + `ci-auto-fix.yml` = Devin的な自律修正パターン
- **ゴール**: Claude Code 4インスタンスを「自社Devin」として機能させる
$$,
'https://cognition.ai/blog',
'2026-04-16', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
