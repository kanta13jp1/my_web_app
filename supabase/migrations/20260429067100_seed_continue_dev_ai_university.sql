-- PS#3 S117: AI大学 329→330社化 — Continue.dev (IDE AI コーディングアシスタント/OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'continue-dev', 'overview',
  'Continue.dev — OSS IDE AI コーディングアシスタント・VS Code/JetBrains・Claude統合 (GitHub 19k+ / 9/9)',
  $$## Continue.dev とは

**Continue.dev** は **VS Code / JetBrains 向けのオープンソース AI コーディングアシスタント**。GitHub 19,000+ スター。「**GitHub Copilot の OSS 版で、どの LLM でも使える**」が特徴。Claude・GPT・Gemini・Ollama (ローカル) など任意の LLM をコーディングアシスタントとして設定できる。

**config.json** で LLM・コンテキストプロバイダー・スラッシュコマンドを自由に設定でき、**企業のプライバシーポリシーに合わせてローカル LLM (Ollama) とも接続可能**。Tab 補完・インラインチャット・コード編集・コンテキスト参照など GitHub Copilot と同等の機能を持ちながら、プロバイダーに縛られない自由度が強み。

## Continue.dev のアーキテクチャ

```
Continue.dev のコアコンポーネント:

  IDE 拡張機能:
    ・VS Code Extension (主要)
    ・JetBrains Plugin (IntelliJ / WebStorm)
    ・サイドパネル チャット UI
    ・インライン編集 (Cmd+I / Ctrl+I)

  config.json (カスタマイズ設定):
    ・models: 使用 LLM の設定
    ・tabAutocompleteModel: Tab 補完用モデル
    ・contextProviders: コンテキスト参照先
    ・slashCommands: カスタムコマンド
    ・customCommands: プロンプトテンプレート

  コンテキストプロバイダー:
    ・@file: 現在のファイルを参照
    ・@folder: フォルダを参照
    ・@codebase: プロジェクト全体 (RAG)
    ・@docs: ドキュメント参照
    ・@git: Git 差分を参照
    ・@web: Web 検索

  機能:
    ・チャット: 選択コードを含めて質問
    ・インライン編集: コードをその場で書き換え
    ・Tab 補完: GitHub Copilot 互換
    ・Quick Actions: Explain / Fix / Optimize
```

## 主要機能

```
コーディング支援:
  ・コード生成・補完・修正
  ・バグ修正の提案
  ・リファクタリング
  ・テストコード生成
  ・ドキュメント生成

LLM サポート:
  ・Anthropic Claude (claude-sonnet-4-6 / claude-haiku-4-5)
  ・OpenAI GPT-4o
  ・Google Gemini
  ・Ollama (完全ローカル)
  ・LM Studio / Jan
  ・Groq / Together AI / Fireworks AI

プライバシー:
  ・コードを外部送信しないローカルモード
  ・エンタープライズ向け自社サーバー経由モード
  ・オープンソースで完全監査可能
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Flutter 開発** | claude-sonnet-4-6 で Widget 生成・Dart 最適化 | Copilot より Claude の深い理解 |
| **Supabase EF 開発** | @codebase で EF 全体を参照しながら新 action 追加 | コンテキスト豊富な EF 生成 |
| **ローカルプライベート** | Ollama + Continue.dev で API キー不要のコーディング | コスト 0 のオフライン開発 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'continue-dev', 'api',
  'Continue.dev 実践 — インストール/config.json/Claude設定/Ollama/コンテキストプロバイダー/スラッシュコマンド',
  $$## インストール

```bash
# VS Code 拡張機能
# VS Code → 拡張機能 → "Continue" を検索 → インストール
# または
code --install-extension Continue.continue

# JetBrains
# Settings → Plugins → "Continue" を検索 → インストール
```

## config.json の設定 (Claude)

```json
// ~/.continue/config.json
{
  "models": [
    {
      "title": "Claude Sonnet 4.6",
      "provider": "anthropic",
      "model": "claude-sonnet-4-6",
      "apiKey": "YOUR_ANTHROPIC_API_KEY"
    },
    {
      "title": "Claude Haiku 4.5 (高速)",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "apiKey": "YOUR_ANTHROPIC_API_KEY"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Tab補完 (Haiku)",
    "provider": "anthropic",
    "model": "claude-haiku-4-5",
    "apiKey": "YOUR_ANTHROPIC_API_KEY"
  },
  "contextProviders": [
    { "name": "code" },
    { "name": "docs" },
    { "name": "diff" },
    { "name": "terminal" },
    { "name": "problems" },
    { "name": "folder" },
    {
      "name": "codebase",
      "params": {
        "nRetrieve": 25,
        "nFinal": 5,
        "useReranking": true
      }
    }
  ],
  "slashCommands": [
    { "name": "edit", "description": "コードを編集する" },
    { "name": "comment", "description": "コメントを追加する" },
    { "name": "share", "description": "会話をMarkdownでエクスポート" },
    { "name": "cmd", "description": "ターミナルコマンドを提案" }
  ],
  "customCommands": [
    {
      "name": "flutter-widget",
      "description": "Flutter Widgetを生成",
      "prompt": "以下の説明から Flutter Widget を生成してください。DESIGN.md のデザイントークンに従い、Riverpod で状態管理してください:\n{{{ input }}}"
    },
    {
      "name": "supabase-ef",
      "description": "Supabase Edge Function のアクションを追加",
      "prompt": "以下の要件で Supabase Edge Function のアクションを追加してください。既存の EF パターンに従い、deny-by-default 原則を守ってください:\n{{{ input }}}"
    }
  ]
}
```

## Ollama (ローカル完全オフライン) 設定

```json
{
  "models": [
    {
      "title": "Llama 3.2 (ローカル)",
      "provider": "ollama",
      "model": "llama3.2"
    },
    {
      "title": "CodeLlama (コード特化)",
      "provider": "ollama",
      "model": "codellama:13b"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen2.5-Coder (高速補完)",
    "provider": "ollama",
    "model": "qwen2.5-coder:1.5b"
  }
}
```

## 主な使い方 (VS Code)

```text
チャット:
  - Cmd+L (Mac) / Ctrl+L (Win): チャットパネルを開く
  - コードを選択してからチャット → 選択コードが自動追加
  - @file, @folder, @codebase でコンテキスト追加

インライン編集:
  - Cmd+I (Mac) / Ctrl+I (Win): インライン編集
  - 「このメソッドを最適化して」などの自然言語指示
  - 差分を確認してから Accept / Reject

Tab 補完:
  - コード入力中に自動サジェスト表示
  - Tab キーで補完を承認

Quick Actions (コード選択後):
  - 右クリック → "Continue" → Explain / Fix / Optimize
```

## コンテキストプロバイダーの使い方

```text
チャット入力時に @ を入力:
  @codebase  → プロジェクト全体を RAG 検索 (ベクター化)
  @file      → 特定ファイルをコンテキストに追加
  @folder    → フォルダをコンテキストに追加
  @docs      → ドキュメント URL を参照
  @diff      → Git 差分を表示
  @terminal  → ターミナル出力を参照
  @problems  → VSCode の問題タブを参照

例:
  "@codebase Supabase のクライアント初期化はどこにある？"
  "@file lib/pages/horse_racing_page.dart このページにバグがある"
  "@diff このコミットの変更を説明して"
```

## カスタムスラッシュコマンド

```json
{
  "slashCommands": [
    {
      "name": "keiba-review",
      "description": "競馬予想コードをレビュー",
      "prompt": "以下の競馬予想コードをレビューしてください。\n\n注目点:\n1. 予想ロジックの妥当性\n2. エッジケース処理\n3. パフォーマンス\n4. Supabase クエリの最適化\n\n```\n{{{ input }}}\n```"
    }
  ]
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 329→330社化: Continue.dev 追加',
  'PS#3 S117。Continue.dev (OSS IDE AIコーディングアシスタント/VS Code+JetBrains/Claude+Ollama統合/Tab補完/インライン編集/@codebase RAG/config.json完全カスタマイズ/ローカルLLM対応/GitHub 19k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
