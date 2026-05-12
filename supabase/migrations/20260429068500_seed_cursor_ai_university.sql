-- PS#3 S118: AI大学 330→331社化 — Cursor (AI IDE / VSCode fork / コーディングAI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cursor', 'overview',
  'Cursor — AI IDE・VSCode fork・Composer/Agent・Claude統合・Tab補完 (GitHub 50k+ / 9/9)',
  $$## Cursor とは

**Cursor** は **VSCode をフォークした AI ネイティブ IDE**。「**Copilot の 10 倍賢いコーディングAI**」を謳う。Claude / GPT-4o をバックエンドに、**Composer (マルチファイル一括編集)** / **Agent モード (自律タスク実行)** / **Tab 補完** / **チャット** を統合した次世代 IDE。

2024 年に急成長し、**GitHub 50,000+ スター** (コアパーツ公開分)。月額 $20 の Pro プランで Claude Sonnet/Opus の高速呼び出しが無制限。エンタープライズ向けの **Business** プランも提供。「Claude Code の GUI 版」として位置付けられ、コードを書く速度が **10x** になると評判。

## Cursor のアーキテクチャ

```
Cursor のコアコンポーネント:

  IDE 本体 (VSCode fork):
    ・VSCode 互換 (拡張機能・設定ほぼ共通)
    ・AI 処理のためのカスタムレイヤー追加
    ・Cursor Settings で AI プロバイダー設定

  AI 機能レイヤー:
    ・Tab: インライン補完 (GitHub Copilot 超え)
    ・Chat: Ctrl+L でサイドパネルチャット
    ・Composer: Ctrl+I でマルチファイル編集
    ・Agent: 自律タスク実行 (ターミナル操作可)
    ・Rules for AI: プロジェクト固有ルール設定

  LLM バックエンド:
    ・Claude Sonnet 4.6 / Opus 4.7 (Anthropic)
    ・GPT-4o / o1 (OpenAI)
    ・Gemini 1.5 Pro (Google)
    ・カスタム API キー (任意のエンドポイント)

  コンテキスト管理:
    ・@file: ファイル参照
    ・@folder: フォルダ参照
    ・@codebase: RAG ベクター検索
    ・@docs: ドキュメントURL参照
    ・@web: Web 検索
    ・@git: Git 差分参照
```

## 主要機能

```
Tab 補完:
  ・GitHub Copilot より精度が高いと評判
  ・マルチライン補完
  ・編集予測 (Tab で次の変更箇所へジャンプ)

Composer (Ctrl+I):
  ・複数ファイルを一括で AI 編集
  ・「〇〇を実装して」→ 自動でファイル生成/修正
  ・Accept/Reject で差分確認

Agent モード:
  ・ターミナルコマンドも自律実行
  ・ファイル作成→テスト実行→修正 のループ
  ・複雑なタスクを自律完了

Rules for AI (.cursorrules):
  ・プロジェクト固有の AI 指示
  ・コーディング規約・スタイル・ライブラリ指定
  ・CLAUDE.md 相当のカスタマイズ
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Flutter 開発** | Composer で Widget + テストを一括生成 | 10x 速度でコンポーネント量産 |
| **Supabase EF 開発** | Agent で EF 実装→deno test→修正 ループ | 自律デプロイまで Agent が処理 |
| **Claude Code 代替** | API quota 超過時に Cursor Pro で継続 | フォールバック IDE として機能 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cursor', 'api',
  'Cursor 実践 — インストール/設定/Composer/Agent/.cursorrules/Claude統合/Tab補完マスター',
  $$## インストール

```bash
# 公式サイトからダウンロード
# https://cursor.com → Download
# Mac/Windows/Linux 対応
# VSCode の設定・拡張機能を自動インポート可能

# VSCode から移行 (設定・拡張・keybinding 引き継ぎ)
# Cursor 起動 → "Import VS Code Settings" を選択
```

## 初期設定 (Claude 統合)

```text
設定手順:
1. Cursor Settings (Ctrl+,) → "Models" タブ
2. "claude-sonnet-4-6" を有効化
3. API Keys → Anthropic API Key を設定 (BYOKモード)
   または Pro プランで Cursor 管理キーを使用

.cursorrules (プロジェクトルート):
- このファイルが AI への指示書として機能
- CLAUDE.md 相当の役割
```

## .cursorrules の書き方

```text
# .cursorrules
# 自分株式会社 Flutter プロジェクト

## 技術スタック
- Flutter Web (Dart)
- Supabase (PostgreSQL + Edge Functions)
- Riverpod (状態管理)
- GoRouter (ルーティング)

## コーディング規約
- Dart の命名規則に従う (camelCase/PascalCase)
- Widget は StatelessWidget を優先
- 副作用は Riverpod Provider で管理
- 日本語コメントOK

## デザインシステム
- docs/DESIGN.md のトークンを使用
- Orange (#f97316) + Indigo (#4f46e5) ダークテーマ
- Material 3 ベース

## Supabase Edge Function
- deny-by-default 原則
- auth.uid() で認証チェック必須
- Deno / TypeScript

## 禁止事項
- ダミーデータの使用
- 未使用の import
- any 型の使用
```

## Composer の使い方 (マルチファイル編集)

```text
Composer を開く:
  - Ctrl+I (Mac: Cmd+I)
  - サイドパネルに Composer が表示

使い方例:
  1. "Riverpod を使った Horse Racing ページを実装して"
     → lib/pages/horse_racing_page.dart 自動生成
     → lib/providers/horse_racing_provider.dart 自動生成
     → 差分を Accept/Reject で確認

  2. @file lib/pages/existing.dart を参照して
     "このページと同じパターンで新しいページを作成"
     → 既存パターンを学習して新規ファイル生成

  3. "全ての Widget に const コンストラクタを追加"
     → 複数ファイルを一括で修正

コンテキスト指定:
  @file: 特定ファイルを参照
  @folder: フォルダ全体を参照
  @codebase: プロジェクト全体を RAG 検索
  @docs: URL のドキュメントを参照
```

## Agent モードの使い方

```text
Agent を有効化:
  - Composer → "Agent" ボタンをクリック
  - または Ctrl+Shift+I でエージェントモード

Agent の動作例:
  1. "Flutter のテストが通るまで修正して"
     → flutter test 実行
     → エラーを確認
     → コードを修正
     → 再度 flutter test 実行
     → 全テスト通過まで繰り返す

  2. "Supabase Edge Function の edge-function-name を
     Deno でデプロイして動作確認して"
     → supabase functions deploy 実行
     → curlでテスト
     → ログ確認
     → 問題あれば修正

制限:
  - ターミナルコマンドは実行前に確認プロンプトあり
  - 承認が必要な操作は停止して確認
```

## Tab 補完のコツ

```text
Tab 補完の特徴:
  ・マルチライン: 複数行を一度に補完
  ・編集予測: 次の変更箇所を予測して Tab でジャンプ
  ・パターン学習: 同じファイル内のパターンを学習

効果的な使い方:
  1. 関数の最初の数文字を書いて Tab → 全体を補完
  2. コメントを書いて改行 → 実装を補完
  3. 一つ修正したら Tab → 同じパターンの次の箇所へ

// コメント駆動開発:
// 競馬の予想スコアを計算して返す
// 入力: horses: List<Horse>
// 出力: 各馬の予測確率マップ
Map<String, double> calculatePredictions(List<Horse> horses) {
  // ← ここで Tab → 実装を自動補完
```

## BYOK (Bring Your Own Key) 設定

```text
Cursor Settings → API Keys:
  Anthropic: sk-ant-...
  OpenAI: sk-...

BYOK のメリット:
  - 自分のAPI枠を使用 (Cursor の制限なし)
  - 最新モデルを即座に使用可能
  - コスト追跡が自分のダッシュボードで可能

Pro プランとの違い:
  - Pro: Cursor が API コストを負担 (月$20 固定)
  - BYOK: API 従量課金 (ヘビーユーザーはBYOKが安い場合も)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 330→331社化: Cursor 追加',
  'PS#3 S118。Cursor (AI IDE/VSCode fork/Composer マルチファイル編集/Agent 自律実行/Tab補完/Claude+GPT統合/.cursorrules/GitHub 50k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
