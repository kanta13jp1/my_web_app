-- PS#3 S119: AI大学 332→333社化 — Cline (Claude VSCode拡張 / OSS AIコーディングエージェント)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cline', 'overview',
  'Cline — Claude VSCode拡張・OSS AIコーディングエージェント・ファイル+ターミナル自律操作 (GitHub 38k+ / 9/9)',
  $$## Cline とは

**Cline** は **VS Code 向けのオープンソース AI コーディングエージェント**。Claude をバックエンドに、**ファイル編集・ターミナル操作・ブラウザ操作**を自律的に行う。GitHub **38,000+ スター** (2024年爆発的成長)。

「**Claude Code の VS Code 拡張版**」として位置付けられ、Claude 3.5 Sonnet との組み合わせで SWE-bench 最高クラスのスコアを記録。**MCP (Model Context Protocol)** にネイティブ対応しており、外部ツール・API との連携が容易。タスクの各ステップで人間の承認を求める **Human-in-the-loop** 設計が安全性を担保。

## Cline のアーキテクチャ

```
Cline のコアコンポーネント:

  VS Code 拡張機能:
    ・サイドパネル UI (チャット + タスク履歴)
    ・ファイルエクスプローラー統合
    ・ターミナル統合
    ・差分ビューア (変更前後を確認)

  AI バックエンド:
    ・Claude Sonnet 4.6 / Opus 4.7 (推奨)
    ・GPT-4o / o1
    ・Gemini 1.5 Pro
    ・Ollama / LM Studio (ローカル)
    ・任意の OpenAI 互換 API

  自律アクション:
    ・ファイル作成・読み取り・編集・削除
    ・ターミナルコマンド実行
    ・ブラウザ操作 (Playwright 統合)
    ・外部 API 呼び出し

  MCP 統合:
    ・MCP サーバーをツールとして利用
    ・GitHub / Supabase / Figma MCP 対応
    ・カスタム MCP サーバー追加可能

  Human-in-the-loop:
    ・各アクション前に確認プロンプト
    ・自動承認モード (危険なアクション以外)
    ・ロールバック機能
```

## 主要機能

```
コーディングエージェント:
  ・タスクを自律的に分解して実行
  ・複数ファイルにまたがる変更
  ・テスト実行 → 失敗 → 自動修正ループ
  ・エラーログを読んで自動デバッグ

ブラウザ操作:
  ・スクリーンショットを見て UI を確認
  ・クリック・入力・ナビゲーション
  ・本番 URL を確認してバグを特定

MCP ネイティブ:
  ・Model Context Protocol で外部ツール統合
  ・GitHub MCP でリポジトリ操作
  ・Supabase MCP で DB 直接操作
  ・Figma MCP でデザイン参照

コスト管理:
  ・トークン使用量・コストをリアルタイム表示
  ・タスクごとのコスト追跡
  ・予算上限設定可能
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Flutter + Supabase 同時変更** | Cline + MCP で DB スキーマ変更→Flutter UI 更新を一括 | 複数レイヤー横断タスクを自律実行 |
| **本番 UI 確認** | Cline のブラウザ機能で本番 URL を確認してバグ特定 | Playwright なしで UI 検証 |
| **競馬 EF 開発** | Supabase MCP + Cline で EF→テスト→デプロイを自律実行 | Claude Code に近い体験を VS Code 内で |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cline', 'api',
  'Cline 実践 — インストール/Claude設定/MCP統合/自律タスク/ブラウザ操作/コスト管理/自分株式会社活用',
  $$## インストール

```bash
# VS Code 拡張機能マーケットプレイスから
# VS Code → 拡張機能 → "Cline" を検索 → インストール
# または
code --install-extension saoudrizwan.claude-dev

# JetBrains 版: "Cline" で検索 (Beta)
```

## 初期設定 (Claude 統合)

```text
設定手順:
1. VS Code サイドパネルの Cline アイコンをクリック
2. Settings (歯車アイコン) → API Provider: "Anthropic"
3. API Key: sk-ant-... を入力
4. Model: claude-sonnet-4-6 を選択
5. "Save" で設定完了

または OpenRouter 経由:
  API Provider: "OpenRouter"
  Model: anthropic/claude-sonnet-4-6
  → 複数プロバイダーをワンストップ管理
```

## 基本的な使い方

```text
タスク指示例:

Cline チャットに入力:
  "lib/pages/horse_racing_page.dart に新しい予想カードを追加して。
   DESIGN.md のデザイントークンを使い、Riverpod で状態管理して。
   テストも追加して flutter test が通るまで修正して。"

Cline の動作:
  1. DESIGN.md を読む
  2. 既存のカードコンポーネントパターンを確認
  3. 新しい Widget ファイルを作成
  4. horse_racing_page.dart に組み込み
  5. Provider を作成
  6. テストファイルを作成
  7. flutter test 実行 → 失敗 → 修正 → 再実行
  8. 全テスト通過で完了報告

各ステップで承認が必要 (または自動承認モード)
```

## MCP 統合 (Supabase + GitHub)

```json
// ~/.cline/mcp_settings.json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest"],
      "env": {
        "SUPABASE_URL": "https://your-project.supabase.co",
        "SUPABASE_SERVICE_ROLE_KEY": "your-service-role-key"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
      }
    },
    "figma": {
      "command": "npx",
      "args": ["-y", "figma-developer-mcp"],
      "env": {
        "FIGMA_PERSONAL_ACCESS_TOKEN": "your-figma-token"
      }
    }
  }
}
```

## MCP 活用タスク例

```text
Supabase MCP 活用:
  "Supabase の ai_university_content テーブルに
   新しい provider を追加する migration SQL を作成して、
   適用してデータを確認して"
  → Cline が Supabase MCP で直接 DB を操作

GitHub MCP 活用:
  "このリポジトリの未解決 Issue を確認して
   簡単に修正できるものを選んで PR を作成して"
  → Cline が GitHub MCP で Issue/PR を操作

Figma MCP 活用:
  "Figma デザイン (URL) を参照して
   対応する Flutter Widget を生成して"
  → Cline が Figma MCP でデザインを取得して実装
```

## ブラウザ操作機能

```text
本番確認タスク例:
  "https://my-web-app-b67f4.web.app/ を開いて
   競馬ページの表示を確認して、
   UI の問題があれば修正して"

Cline の動作:
  1. ブラウザを開いて URL にアクセス
  2. スクリーンショットを撮影
  3. UI を分析
  4. 問題箇所のコードを修正
  5. 再度ブラウザで確認

注意:
  ・ブラウザ操作は追加のトークンを消費
  ・Playwright が内部で動作
```

## 自動承認モード設定

```text
Cline Settings → Auto-approve:
  ✅ Read files: 自動承認
  ✅ Write files: 自動承認
  ✅ Execute commands: 自動承認 (注意)
  ✅ Browser actions: 手動承認 (推奨)
  ✅ MCP tools: 自動承認

危険なコマンドはアラート表示:
  - rm -rf は警告
  - git push --force は警告
  - DROP TABLE は警告
```

## コスト管理

```text
Cline のコスト追跡:
  - タスクごとのトークン使用量表示
  - 入力/出力コストの内訳
  - セッション合計コスト

コスト最適化:
  - Tab補完: claude-haiku-4-5 (安い)
  - 複雑タスク: claude-sonnet-4-6
  - 最高精度: claude-opus-4-7 (高い)

予算設定:
  Settings → Max tokens per task: 50000
  → これを超えたらタスクを中断してアラート
```

## .clinerules (プロジェクトルール)

```text
# .clinerules (プロジェクトルート)
# CLAUDE.md / .cursorrules 相当

## 技術スタック
Flutter Web + Supabase + Riverpod

## 禁止事項
- ダミーデータの使用
- any 型の使用
- flutter analyze エラーを無視したpush

## 必須チェック
1. dart format で整形
2. flutter analyze で 0 エラー確認
3. flutter test で全テスト通過

## Supabase
- deny-by-default: auth.uid() 必須
- マイグレーション命名: YYYYMMDDXXXXXX_name.sql
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 332→333社化: Cline 追加',
  'PS#3 S119。Cline (Claude VSCode拡張/OSS AIコーディングエージェント/ファイル+ターミナル+ブラウザ自律操作/MCP ネイティブ対応/GitHub+Supabase+Figma MCP/Human-in-the-loop/GitHub 38k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
