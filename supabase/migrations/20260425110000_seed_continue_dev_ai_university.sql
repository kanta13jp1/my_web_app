-- Session PS#3-S44: AI大学 186社化 — Continue.dev 追加
-- Nate Sesti・Tyler Dunn (2023) が開発するオープンソース AI コーディングアシスタント。
-- VS Code / JetBrains で動作。Claude / GPT-4 / Gemini / Ollama など任意 LLM に接続可能。
-- チャット・オートコンプリート・コマンドを YAML で完全カスタマイズ。
-- GitHub 12k+ Stars / Apache 2.0 / プライバシー重視・ローカル LLM 対応。
-- Step 0: 8/9 (OSS / 任意LLM接続 / IDE統合 / プライバシーファースト / カスタマイズ性)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'continue_dev',
  'overview',
  'Continue.dev — オープンソース AI コーディングアシスタント (VS Code / JetBrains / 任意 LLM)',
  $md$
# Continue.dev — Open Source AI Code Assistant

**Nate Sesti** と **Tyler Dunn** が 2023 年に設立した
オープンソースの AI コーディングアシスタント。
VS Code・JetBrains の拡張機能として動作し、
**Claude / GPT-4 / Gemini / Ollama** など任意の LLM を接続できる。

GitHub Stars **12,000+** / Apache 2.0 ライセンス。

## GitHub Copilot との主な違い

| 比較項目 | Continue.dev | GitHub Copilot |
| :--- | :--- | :--- |
| ライセンス | **オープンソース** (Apache 2.0) | プロプライエタリ |
| LLM 選択 | **任意** (Claude / Ollama 等) | GPT-4o のみ |
| ローカル LLM | **対応** (Ollama / LM Studio) | 非対応 |
| コスト | **無料** (自分のキーを使用) | $10〜/月 |
| カスタマイズ | YAML で完全設定 | 限定的 |
| プライバシー | **ローカル推論可** | コードがクラウドへ |

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **Chat** | コードをコンテキストとして添付してチャット |
| **Autocomplete** | Tab 補完 (Claude / Ollama ベース) |
| **Edit** | 選択範囲を自然言語で指示して書き換え |
| **Actions** | `/edit` `/test` `/comment` などコマンド |
| **Context Providers** | ファイル・フォルダ・URL・ドキュメントをコンテキストに追加 |
| **Slash Commands** | カスタムワークフローを YAML で定義 |

## 対応 LLM プロバイダー

Claude (Anthropic) / OpenAI / Gemini / Mistral /
**Ollama** (ローカル) / LM Studio / Together AI /
OpenRouter / Azure OpenAI / AWS Bedrock

## 採用実績

個人開発者〜中堅スタートアップまで幅広く採用。
Cursor / Windsurf と異なり **既存 IDE をそのまま活かせる** 点が強み。
$md$,
  'https://docs.continue.dev/',
  '2026-04-25',
  1
),

(
  'continue_dev',
  'models',
  'Continue.dev 設定 — config.yaml で LLM・オートコンプリート・コンテキストをカスタマイズ',
  $md$
## config.yaml — 全機能を YAML で設定

Continue.dev の設定ファイルは `~/.continue/config.yaml`。

```yaml
# ~/.continue/config.yaml

models:
  # チャット用モデル (Claude を使用)
  - name: claude-sonnet-4-6
    provider: anthropic
    model: claude-sonnet-4-6
    apiKey: $ANTHROPIC_API_KEY

  # 高速チャット用 (Haiku)
  - name: claude-haiku-4-5
    provider: anthropic
    model: claude-haiku-4-5-20251001
    apiKey: $ANTHROPIC_API_KEY

  # ローカル LLM (無料・プライバシー保護)
  - name: qwen2.5-coder:7b
    provider: ollama
    model: qwen2.5-coder:7b

tabAutocompleteModel:
  # オートコンプリート用 (高速モデル推奨)
  name: qwen2.5-coder:1.5b
  provider: ollama
  model: qwen2.5-coder:1.5b

contextProviders:
  # 利用可能なコンテキストプロバイダー
  - name: code          # @code でファイル・関数を添付
  - name: docs          # @docs でドキュメントを参照
  - name: diff          # @diff で Git diff を添付
  - name: terminal      # @terminal でターミナル出力を添付
  - name: problems      # @problems で VS Code の問題を添付
  - name: folder        # @folder でフォルダ全体をスキャン
  - name: codebase      # @codebase でコードベース全体を検索

slashCommands:
  # カスタムコマンド定義
  - name: edit
    description: "選択コードを指示で修正"
  - name: test
    description: "ユニットテストを生成"
  - name: comment
    description: "コードにコメントを追加"
  - name: share
    description: "会話を markdown に出力"

embeddingsProvider:
  provider: transformers.js   # ローカルエンベディング (無料)
```

## モデル別推奨用途

| 用途 | 推奨モデル | 理由 |
| :--- | :--- | :--- |
| チャット (品質重視) | claude-sonnet-4-6 | 高品質コード理解 |
| チャット (コスト節約) | claude-haiku-4-5 | 高速・安価 |
| オートコンプリート | qwen2.5-coder:1.5b (Ollama) | 低レイテンシ必須 |
| プライバシー重視 | Ollama ローカルモデル | コードを外部送信しない |
| 大規模コードベース | claude-sonnet-4-6 | 長コンテキスト対応 |

## コンテキストプロバイダー活用法

```text
# チャットで使用
@code src/auth.ts の認証フローを説明してください
@diff このコミットで導入したバグを特定してください
@docs React hooks の最新仕様を参照してください
@codebase ErrorBoundary コンポーネントがどこで使われているか調べて
```
$md$,
  'https://docs.continue.dev/yaml-reference/config',
  '2026-04-25',
  2
),

(
  'continue_dev',
  'api',
  'Continue.dev 入門 — インストール・初回セットアップ・主要ショートカット',
  $md$
## インストール

### VS Code

```bash
# VS Code マーケットプレイス
code --install-extension Continue.continue

# または: 拡張機能タブで "Continue" を検索してインストール
```

### JetBrains (IntelliJ / PyCharm / WebStorm / Android Studio)

JetBrains Marketplace で **"Continue"** を検索してインストール。

---

## 初回セットアップ (5 分)

1. 拡張機能をインストール後、サイドバーの Continue アイコンをクリック
2. **Quick Start** でモデルを選択 (Claude / GPT-4 / Ollama など)
3. API キーを入力 (Anthropic / OpenAI など)
4. または `~/.continue/config.yaml` を直接編集

```bash
# Ollama でローカル LLM を使う場合 (インターネット不要)
brew install ollama
ollama pull qwen2.5-coder:7b   # コーディング特化モデル
ollama pull qwen2.5-coder:1.5b # オートコンプリート用 (高速)
# → config.yaml の provider: ollama に設定
```

---

## 主要キーボードショートカット (VS Code)

| アクション | ショートカット |
| :--- | :--- |
| チャットを開く | `Ctrl+Shift+L` / `Cmd+Shift+L` |
| 選択コードをチャットに添付 | `Ctrl+Shift+L` (選択後) |
| インラインで編集 | `Ctrl+I` / `Cmd+I` |
| 選択範囲を説明 | `Ctrl+Shift+E` / `Cmd+Shift+E` |
| チャットをクリア | `Ctrl+Shift+Backspace` |

---

## 実践ワークフロー例

### バグ修正

```text
# ① エラーのある行を選択 → Cmd+Shift+L でチャットへ
# ② プロンプト例:
@problems このエラーを修正してください: TypeError: Cannot read property 'map' of undefined
```

### コードレビュー

```text
@diff この PR の変更点をレビューして、潜在的なバグや改善点を挙げてください
```

### テスト生成

```text
# テストしたいコードを選択 → /test コマンド
/test この関数の単体テストを Jest で書いてください
```

### ドキュメント参照

```text
# ライブラリのドキュメントをリアルタイムで参照
@docs supabase クライアントの RLS ポリシーをサーバーサイドで無効化する方法は？
```

---

## クイックスタート (3 ステップ)

1. VS Code に Continue 拡張をインストール
2. Anthropic API キーを設定 (またはローカル Ollama を起動)
3. `Cmd+Shift+L` でチャット開始 / `Cmd+I` でインライン編集
$md$,
  'https://docs.continue.dev/getting-started/install',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
