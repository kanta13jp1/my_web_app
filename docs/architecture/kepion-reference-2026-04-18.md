# Kepion: Building an Autonomous AI Company Orchestrator

**ソース**: NotebookLM <https://notebooklm.google.com/notebook/819f4e8d-d48f-4a09-8920-89cf83da9091>
**取得日**: 2026-04-18 (Windowsアプリ版#87)
**目的**: 自分株式会社の AI Agent OS / agent-hub 進化の参考にする外部アーキテクチャ・ベンチマーク。

---

## 全体要約

**Kepion** は **「1文のビジネスアイデア」 → 自律 AI 企業構築・運用** を実現するフルスタック・エージェント・オーケストレーション・プラットフォーム。28 体の AI エージェントが市場調査 / 妥当性検証 / プロダクト設計 / 開発 / コンテンツ / マーケまで自律実行する。

開発前に **「ゲートシステム」** でビジネス成功確率をスコアリングし、採算が取れないアイデアへの無駄な投資を防ぐ設計。

---

## 主要技術特徴

### 1. 2層アーキテクチャ (Business / Tool layer)

エージェントを **ビジネス層 (専属)** と **ツール層 (共有)** に明確分離し、**コストを倍増させずに複数ビジネスを同時スケール**。

| 層 | エージェント数 | 例 | 責務 |
| --- | --- | --- | --- |
| **ビジネス層** | 7体 (PROJECT毎に専属) | PM Max / マーケ Ivy / セールス Sam / Finance Finn / CS Joy / Legal Lex / ジェネレータ Chief | ビジネス文脈 (ニッチ・競合・ターゲット) を深く理解 |
| **ツール層** | 21体 (PROJECT間で共有) | Architect Atlas / Designer Maya / Frontend Kai / Backend Dev / Security Shield / Researcher Nova / Writer Sage / Vault Libra + 14体 | 専門技術 (Craft) のみ。ビジネス層から完全コンテキスト付きで委任される |

### 2. イベント駆動 (Redis Pub/Sub)

すべてのエージェントアクションがイベントとして発行 → 以下を一発で実現:

- **コンプライアンス監査ログ** (full audit trail)
- **リアルタイム・コスト追跡**
- **WebSocket ライブアクティビティ監視**
- **異常時キルスイッチ** (kill switch)

### 3. インテリジェント・モデル・ルーティング

**OpenRouter ゲートウェイ + 4 ティア** で 300+ AI モデルをタスクに最適化:

| Tier | 用途例 |
| --- | --- |
| Free | 軽量タスク・実験 |
| Budget | MiniMax M2.7 など低コスト高性能 |
| Performance | 標準業務 |
| Premium | 高難度推論 |

**自動エスカレーション**: タスク失敗時に上位 Tier へ。
**自動ダウングレード**: 連続成功で下位 Tier へ。
→ **品質維持で運用コスト 80〜85% 削減**。

### 4. 永続的記憶 (Obsidian Vault)

- リサーチ結果 / アーキテクチャ決定 (ADR) / バグ修正 → **すべて Markdown ノート**
- **Git バージョン管理** で変更履歴保持
- **Librarian (Libra) エージェント** が自動インデックス・タグ付け・統合
- 知識は **プロジェクト枠を超えて共有** → システム全体が学習

### 5. A2A (Agent-to-Agent) プロトコル

- 各エージェントの機能を **JSON 形式 Agent Card** で定義
- 標準化エンドポイントで **外部エージェントとの相互運用**
- 将来的なプラットフォーム間機械間通信を見据える

### 6. ファクトベース・リサーチスタック (反ハルシネーション)

| ツール | 役割 |
| --- | --- |
| **Perplexica** | 引用付き Web 検索 |
| **SurfSense** | ハイブリッド検索 |
| **AnythingLLM** | RAG ワークスペース |
| **Firecrawl** (MCP) | Web スクレイピング |

セルフホスト統合で事実に基づいたデータ収集と分析。

### 7. システム統合

- **API ゲートウェイ**: FastAPI
- **Composio**: Gmail / Slack / Notion など **400+ 外部アプリ連携**

---

## 自分株式会社への応用検討

### 即適用可能 (短期)

- **OpenRouter ティア戦略**: 既存 `ai-hub:provider.chat` の OpenAI 互換 8社統合に、自動エスカレーション/ダウングレード ロジックを追加
- **ai-hub provider.chat に Tier メタデータ**: Free/Budget/Performance/Premium 分類を `lib/models/ai_provider_registry.dart` に追加
- **MiniMax-M2.5-Lightning** ($0.10/1M) を Budget Tier デフォルトとして活用 (Win版#76 で追加済み)

### 中期 (本格採用)

- **イベント駆動アーキテクチャ**: Supabase Realtime ＋ `agent_activity_log` テーブルで Pub/Sub 化 → kill switch / コスト追跡 / WebSocket ライブダッシュボード
- **永続知識ベース**: 既存 `memory/` (Master Brain) を **Librarian エージェント風** に自動インデックス化 (semantic embedding + 自動タグ)
- **A2A Agent Card**: 既存 21 エージェント (`agent-hub`) に JSON Agent Card 公開エンドポイント追加 → 外部 MCP / Cline / Cursor から呼べる
- **ゲートシステム**: ROADMAP の各機能候補に **成功確率スコア** + ROI 試算 → 着手判断の自動化

### 長期 (戦略)

- **2層アーキテクチャ移行**: 既存エージェントを Business / Tool 層に再分類
- **ファクトベース・リサーチ**: 現在 NotebookLM 単独 → Perplexica + SurfSense + AnythingLLM 併用検討
- **Composio 連携**: 既存の Gmail / Slack / Notion / GitHub MCP に + α で 400 アプリ網羅

---

## 次セッション候補タスク

| 優先度 | タスク | 担当インスタンス |
| --- | --- | --- |
| 🔴 高 | `ai_provider_registry.dart` に `tier` (Free/Budget/Performance/Premium) フィールド追加 | VSCode版 |
| 🔴 高 | `ai-hub:provider.chat` に **自動エスカレーション/ダウングレード** ロジック追加 | PowerShell版 |
| 🟡 中 | `memory/` Librarian: 自動 index + tag + relation 抽出スクリプト | Windowsアプリ版 |
| 🟡 中 | `agent_activity_log` テーブル + Supabase Realtime で WebSocket ライブダッシュボード | VSCode版 |
| 🟢 低 | Agent Card JSON エンドポイント + A2A 試験統合 | PowerShell版 |
| 🟢 低 | Perplexica / SurfSense セルフホスト評価 | Windowsアプリ版 |

---

## 引用

ノートブック内番号 `[1-16]` 参照。詳細は NotebookLM 上で `notebooklm ask "[質問]"` で再取得可能。
