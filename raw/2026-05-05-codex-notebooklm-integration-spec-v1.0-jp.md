# Codex × NotebookLM 連携システム 要件定義書 v1.0

**Version**: 1.0
**作成日**: 2026年5月5日
**Source**: ユーザー提供 PDF (4 ページ / 2026-05-07 ingest)

---

## 1. ドキュメント情報

- **作成目的**: X (旧 Twitter) 上の実践事例調査を基に、Codex と NotebookLM の連携システムに関する正式な要件を定義。Claude (Claude Code / Cursor 等) にそのまま投入して、セットアップガイド・実装支援・カスタマイズを効率的に行うためのベースドキュメントとする。
- **対象読者**: Claude Code / Codex ユーザー、AI 駆動開発者
- **参照ソース**: X 投稿 (2026年4-5月)、GitHub リポジトリ (notebooklm-mcp, notebooklm-py)

## 2. 目的

AI コーディングエージェント「Codex」から Google NotebookLM のノートブックに対して直接連携を実現し、以下の価値を提供する:

- 大量ドキュメント (論文・書籍・動画文字起こし等) の分析を NotebookLM にオフロード
- Codex 側のトークン消費を 70% 以上削減
- ソース引用付きの根拠ある回答を取得 (ハルシネーション低減)
- 研究 → 実装のシームレスなワークフローを構築

## 3. 背景と課題

### 3.1 現在の状況 (X 調査結果)

2026 年 4-5 月、X 日本語圏で「Codex + NotebookLM」連携が急速に拡大。主なツールとして notebooklm-py (Python Skill) と notebooklm-mcp (MCP サーバー) が実践されている。

ユーザーの声:
- 「本一冊を Codex に喰わせるのは無理だが、NotebookLM 経由なら可能になった」
- 「YouTube 文字起こしを NotebookLM に任せて、結果を Claude Code/Codex で取得 → トークン劇的に抑えられる」
- 「notebooklm-py は無茶いい。Codex に丸投げで完璧に動いた」

### 3.2 解決すべき課題

- Codex 単体ではコンテキスト長・コストの制限が厳しい
- 手動で NotebookLM の結果をコピー&ペーストするのは非効率
- Windows 環境での文字化けなどの実装障壁

## 4. 機能要件 (Functional Requirements)

| ID | 要件名 | 詳細説明 | 優先度 |
|------|----------|----------|--------|
| FR-001 | NotebookLM 接続 | MCP サーバーまたは Python Skill 経由で Google 認証・セッション確立 | 高 |
| FR-002 | ノートブック管理 | ノートブックの一覧表示・作成・選択・削除・切り替え | 高 |
| FR-003 | ソース追加 | URL / PDF / YouTube / テキスト / Google Drive の一括登録 | 高 |
| FR-004 | 質問実行 | 自然言語クエリに対し、ソース引用付き回答を返す (ask_question ツール) | 高 |
| FR-005 | コンテンツ生成 | Audio Overview (ポッドキャスト)、Mind Map、Study Guide、FAQ、Quiz の生成・エクスポート | 中 |
| FR-006 | Codex 統合 | Codex CLI から MCP/Skill としてツール呼び出し可能 (codex mcp add) | 高 |
| FR-007 | 永続セッション | 複数ノートブックの同時管理とセッション永続化 | 中 |
| FR-008 | エラーハンドリング | Windows 文字化け対策、認証エラー時の再認証フロー | 高 |

## 5. 非機能要件 (Non-Functional Requirements)

- **トークン効率**: Codex 単体比で 70% 以上削減 (NotebookLM オフロードによる)
- **回答品質**: すべての回答にソース引用 (citation) を必須とする
- **対応環境**: Windows 10/11, macOS, Linux (Ubuntu 推奨)
- **セキュリティ**: Google OAuth の安全な扱い、ブラウザフィンガープリント保護 (MCP の場合)
- **メンテナンス性**: 既存 OSS (notebooklm-mcp / notebooklm-py) を最大限活用し、車輪の再発明を避ける

## 6. システム構成・技術スタック

### 6.1 推奨構成 (Primary)

**Codex CLI → notebooklm-mcp (MCP サーバー) → NotebookLM (ブラウザ自動化)**

インストール: `codex mcp add notebooklm npx notebooklm-mcp@latest`

### 6.2 代替構成 (Python Skill)

**Codex / Claude Code → notebooklm-py (Python Skill) → NotebookLM**

GitHub: <https://github.com/teng-lin/notebooklm-py>

### 6.3 主なツール一覧

- `ask_question` — 引用付き Q&A
- `add_source` — ソース登録
- `generate_audio` / `download_audio` — ポッドキャスト生成
- `list_notebooks` / `select_notebook` — ノートブック管理

## 7. ユースケース (Use Cases)

- **UC1. 研究論文比較**: 10 本の論文を NotebookLM に登録 → Codex から「主要なコントリビューションの違いを比較せよ」と質問 → 引用付きで回答
- **UC2. 動画 → コード実装**: 技術系 YouTube 動画を NotebookLM で文字起こし+分析 → Codex で実装コードを自動生成
- **UC3. 書籍丸ごと活用**: 技術書 1 冊を NotebookLM に投入 → Codex から「第 3 章のアルゴリズムを Python で実装せよ」と指示
- **UC4. クオンツ研究**: 最新論文を NotebookLM で理解 → Codex にトレード戦略のコード化を依頼

## 8. 導入・運用要件

### 8.1 前提条件

- Codex CLI または Claude Code が利用可能
- Google アカウント (NotebookLM 利用権限あり)
- Node.js 18+ または Python 3.10+
- Playwright / Chromium (MCP 利用時)

### 8.2 文字化け対策 (Windows 特有)

X 実践者報告より、notebooklm-py 使用時に Windows で文字化けが発生するケースあり。Codex に「Windows 文字化け対策を適用せよ」と指示して自動修正可能。

## 9. 参考情報

### 9.1 GitHub リポジトリ

- notebooklm-mcp: <https://github.com/PleasePrompto/notebooklm-mcp>
- notebooklm-py: <https://github.com/teng-lin/notebooklm-py>

### 9.2 X 投稿例 (2026年4-5月)

- @tetumemo: 「Claude Code や Codex と NotebookLM を接続させるためのリポジトリ notebooklm-py」
- @makodama: 「Codex に notebooklm-py を導入。トークン省略のための MCP サーバーも一緒に」

## 10. (元 doc 「Claude への指示」section / NotebookLM ingest 用 reference のみ)

> **Note (2026-05-07 ingest 時)**: 元 doc 章 10 は「Claude への指示」5 タスク (= setup 手順生成 / 比較表 / 文字化けスクリプト / プロンプトテンプレート / 拡張案) を含む. user 明示要求は "NotebookLM とつなげて" (= ingest only) のため、§10 タスク実行は skip。将来 user 明示依頼時に別 session で対応。

元 doc §10 の 5 タスク (= reference のみ):

1. Codex CLI で即座に利用可能な詳細セットアップ手順 (コマンド全文) を生成
2. notebooklm-mcp と notebooklm-py の比較表と、どちらを推奨するかの判断根拠
3. Windows 文字化け完全対策スクリプト
4. 実際のユースケースに即した Codex 用プロンプトテンプレート集 (5-10 個)
5. 将来的な拡張案 (複数ノートブック横断検索、自動ソース更新など)

---

**End of Document** (= 元 doc 4 ページ全文 + ingest メタ情報).
