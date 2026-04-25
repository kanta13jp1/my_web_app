-- Session PS#3-S44: AI大学 187社化 — Aider 追加
-- Paul Gauthier が開発する AI ペアプログラマー CLI ツール。
-- Git リポジトリと連携し、Claude / GPT-4 / DeepSeek などで複数ファイルを一括編集。
-- GitHub 22k+ Stars / Apache 2.0 / SWE-bench 最高クラスのスコアを独自計測。
-- 変更は必ず Git コミットとして記録 — 差分が常に可視化・ロールバック可能。
-- Step 0: 8.5/9 (Git連携 / 複数ファイル編集 / 透明な変更記録 / コスト効率 / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'aider',
  'overview',
  'Aider — AI ペアプログラマー CLI (Git連携 / 複数ファイル編集 / 22k+ Stars)',
  $md$
# Aider — AI Pair Programming in Your Terminal

**Paul Gauthier** が開発する CLI ベースの AI ペアプログラマー。
Git リポジトリ内で直接動作し、自然言語の指示でコードを変更・コミットする。

GitHub Stars **22,000+** / Apache 2.0 ライセンス。
SWE-bench Verified で独自計測を実施し、コーディングエージェントとして高いスコアを記録。

## 特徴と強み

| 強み | 説明 |
| :--- | :--- |
| **Git 統合** | すべての変更を自動コミット — 差分が常に可視・ロールバック容易 |
| **複数ファイル編集** | 1 回の指示で複数ファイルを横断的に修正 |
| **任意 LLM 対応** | Claude / GPT-4 / DeepSeek / Gemini / Ollama など |
| **エディタ不問** | ターミナルだけで完結 — VS Code / Vim / Emacs との共存可能 |
| **コスト効率** | DeepSeek V3 (安価) で十分な品質を維持 |
| **透明な変更** | diff を表示してから適用 — サイレント変更なし |

## Cursor / Windsurf との違い

| 比較項目 | Aider | Cursor / Windsurf |
| :--- | :--- | :--- |
| UI | **CLI** (ターミナル) | GUI IDE |
| Git 連携 | **自動コミット** (必須) | 手動 |
| 使い方 | `aider file1.py file2.ts` | IDE 上でチャット |
| LLM 選択 | **自由** (任意モデル) | 限定的 |
| 得意な操作 | **大規模リファクタリング** | インラインコーディング |
| 学習コスト | 低い (コマンドのみ) | 中 (IDE 操作) |

## ユースケース

- 複数ファイルにまたがるリファクタリング
- テストコードの一括生成
- バグの原因ファイルを横断的に修正
- ドキュメントと実装を同時更新
- コードレビュー指摘の一括対応
$md$,
  'https://aider.chat/',
  '2026-04-25',
  1
),

(
  'aider',
  'models',
  'Aider モデル選択 & コスト最適化 — Claude / DeepSeek / GPT-4o 比較 (2026)',
  $md$
## 推奨モデルと使い分け

| モデル | コスト | 品質 | 推奨用途 |
| :--- | :--- | :--- | :--- |
| **claude-sonnet-4-6** | 中 | ★★★★★ | 複雑なリファクタリング・設計変更 |
| **claude-haiku-4-5** | 安 | ★★★★☆ | 軽微な修正・コメント追加 |
| **deepseek/deepseek-coder** | **最安** | ★★★★☆ | コスト重視のバッチ処理 |
| gpt-4o | 高 | ★★★★☆ | OpenAI 環境との統合 |
| gemini-1.5-pro | 中 | ★★★★☆ | 大規模コードベース (長コンテキスト) |
| ollama/qwen2.5-coder | 無料 | ★★★☆☆ | オフライン・プライバシー重視 |

## モデル設定

```bash
# Claude を使用 (推奨)
export ANTHROPIC_API_KEY=your_key
aider --model claude-sonnet-4-6

# DeepSeek (コスト節約)
export DEEPSEEK_API_KEY=your_key
aider --model deepseek/deepseek-chat

# Ollama (ローカル・無料)
ollama pull qwen2.5-coder:7b
aider --model ollama/qwen2.5-coder:7b

# .aider.conf.yml で永続設定
echo "model: claude-sonnet-4-6" > .aider.conf.yml
```

## コスト推定 (100 行変更の場合)

| LLM | 入力 tokens | 出力 tokens | 推定コスト |
| :--- | :--- | :--- | :--- |
| Claude Sonnet 4.6 | ~3,000 | ~500 | ~$0.02 |
| Claude Haiku 4.5 | ~3,000 | ~500 | ~$0.003 |
| DeepSeek Chat | ~3,000 | ~500 | ~$0.001 |
| GPT-4o | ~3,000 | ~500 | ~$0.04 |

## `.aider.conf.yml` — プロジェクト設定

```yaml
# プロジェクトルートに配置
model: claude-sonnet-4-6
auto-commits: true        # 変更後に自動 git commit
dirty-commits: true       # 未コミットのファイルも編集可
read: README.md           # 常にコンテキストに含めるファイル
message-tokens-limit: 4096
```
$md$,
  'https://aider.chat/docs/config/options.html',
  '2026-04-25',
  2
),

(
  'aider',
  'api',
  'Aider 入門 — インストール・基本操作・Git 連携ワークフロー',
  $md$
## インストール

```bash
# pip でインストール (Python 3.10+ 必須)
pip install aider-chat

# または uvx (uv 経由、インストール不要で実行)
uvx aider-chat

# Homebrew (macOS)
brew install aider
```

---

## 基本的な使い方

### 起動

```bash
# API キーを設定
export ANTHROPIC_API_KEY=your_key

# 特定ファイルを編集モードで起動
aider src/auth.py tests/test_auth.py

# フォルダ全体を対象に (--no-auto-commits で確認しながら)
aider --no-auto-commits src/

# 読み取り専用でコンテキスト追加 (編集対象外)
aider --read docs/ARCHITECTURE.md src/api.py
```

### 対話モードでの操作

```text
# aider> プロンプトで自然言語で指示
aider> src/auth.py に JWT 有効期限切れのエラーハンドリングを追加してください

# 複数ファイルを追加
aider> /add tests/test_auth.py

# 現在の編集対象ファイルを確認
aider> /ls

# 変更を取り消し
aider> /undo

# Git diff を確認
aider> /diff
```

---

## Git 連携ワークフロー

Aider はすべての変更を自動コミットし、
変更の追跡・ロールバックを容易にする。

```bash
# 1. 機能追加 (自動コミットされる)
aider src/payment.py
aider> StripeのWebhook署名検証ロジックを追加してください

# → コミットメッセージが自動生成:
#   "feat: add Stripe webhook signature verification"

# 2. 間違えた場合は /undo または git reset
aider> /undo   # 最後のコミットを取り消し

# 3. 大規模変更は --no-auto-commits で確認しながら
aider --no-auto-commits src/
aider> データベースのORMをSQLAlchemyからSQLModelに移行してください
# → 差分確認後、手動でコミット
git add -p && git commit -m "refactor: migrate to SQLModel"
```

---

## 実践的なユースケース

### バグ修正 (複数ファイル)

```bash
aider src/api.py src/models.py tests/test_api.py
aider> /test を実行すると失敗する。エラーメッセージ: KeyError: 'user_id'。修正してテストも更新してください。
```

### リファクタリング

```bash
aider --read CLAUDE.md src/services/
aider> 全 service クラスを async/await パターンに統一してください
```

### テスト生成

```bash
aider src/utils.py
aider> pytest でユニットテストを src/tests/test_utils.py に生成してください。エッジケースも含めること。
```

### コードレビュー対応

```bash
# GitHub PR のコメントを貼り付けてまとめて対応
aider src/auth.py
aider> PRレビューのコメントを反映してください: [コメント内容を貼り付け]
```

---

## クイックスタート (3 ステップ)

1. `pip install aider-chat` でインストール
2. `export ANTHROPIC_API_KEY=your_key` でキー設定
3. `aider <ファイル名>` で起動 → 自然言語で指示するだけ
$md$,
  'https://aider.chat/docs/usage/tutorial.html',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
