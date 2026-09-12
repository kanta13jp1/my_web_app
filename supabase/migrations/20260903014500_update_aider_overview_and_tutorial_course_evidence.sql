-- Issues #5165 & #5160: Aider 概要・入門コースのエビデンス契約・複数ファイルGitワークフロー・更新日付の強化
UPDATE ai_university_contents
SET
  description = $md$
# Aider — AI Pair Programming in Your Terminal

**Paul Gauthier** が開発するオープンソース (Apache 2.0 / GitHub 22,000+ Stars) の CLI ベース AI ペアプログラマー。
Git リポジトリ内で直接動作し、自然言語指示で複数ファイルを安全に編集・コミット・ロールバックします。

## 対象学習者 & 到達目標
- **対象者**: ターミナル操作に慣れた開発者、複数ファイルの一括変更・リファクタリングを効率化したいエンジニア
- **到達目標**: Aider を用いて 3 ファイル以上のコード変更・テスト実行・`/diff` 確認・自動コミット・`/undo` ロールバックを 30 分以内に完遂できる

## 特徴と Cursor / Windsurf 比較 (2026)

| 比較項目 | Aider CLI | Cursor / Windsurf |
| :--- | :--- | :--- |
| **インターフェース** | **CLI** (ターミナル完結) | GUI IDE |
| **Git 連携** | **各変更を自動コミット & 即座に /undo 可** | 手動 Git 操作 |
| **ファイル指定** | `aider lib/a.dart test/a_test.dart` (明示的) | 自動インデックスまたは @ファイル |
| **LLM 自由度** | **Claude 3.7 / Sonnet 4.6 / DeepSeek / Ollama** | 指定モデルまたは BYOK |
| **スクリプト・CI 連携** | `--message "..."` でバッチ・自動化可能 | 困難 (対話中心) |

## 実践 30 分ラボ: 複数ファイル変更 & Git ロールバック

```bash
# 1. 変更対象ファイルを指定して起動
aider lib/services/auth_service.dart test/services/auth_service_test.dart

# 2. 自然言語で複数ファイル修正を指示
aider> auth_service にセッション有効期限チェックを追加し、単体テストも更新してパスさせてください

# 3. 変更差分の確認
aider> /diff

# 4. テスト実行
aider> /test flutter test test/services/auth_service_test.dart

# 5. ロールバック検証 (変更が不要な場合)
aider> /undo
```
$md$,
  source_url = 'https://aider.chat/',
  published_at = '2026-09-02'
WHERE provider_id = 'aider' AND (title LIKE '%Aider — AI ペアプログラマー%' OR id = '2240c679-a2bc-4322-8643-7499385a1bde' OR sort_order = 1);

UPDATE ai_university_contents
SET
  description = $md$
# Aider 入門 — インストール・基本操作・Git 連携ワークフロー

Aider のインストールから初期設定、日常開発での Git 連携ワークフローを網羅した実践チュートリアルです。

## インストール手順

```bash
# uv / uvx で即時実行 (推奨)
uvx aider-chat

# pip でインストール
pip install aider-chat

# macOS Homebrew
brew install aider
```

## 主要コマンド & ショートカットチートシート

| コマンド | 説明 | 使用例 |
| :--- | :--- | :--- |
| `/add <files>` | 編集対象ファイルをセッションに追加 | `/add lib/models/user.dart` |
| `/read <files>` | 読取専用コンテキストとして追加 (編集しない) | `/read docs/ARCHITECTURE.md` |
| `/drop <files>` | コンテキストからファイルを除外 | `/drop docs/ARCHITECTURE.md` |
| `/diff` | 前回の変更差分 (git diff) を表示 | `/diff` |
| `/undo` | 直前のコミットを取り消して元に戻す | `/undo` |
| `/test <cmd>` | テストを実行し、失敗時は自動でエラー修正 | `/test pytest` または `/test flutter test` |
| `/model <name>` | 使用する LLM を切り替え | `/model claude-sonnet-4-6` |

## 推奨ワークフロー
1. `aider <変更したいファイル>` で起動
2. プロンプトで明確な受け入れ条件（テスト項目、期待する入出力）を指示
3. 自動コミット内容を `/diff` で確認
4. 失敗時は `/undo` または追加指示で修正
$md$,
  source_url = 'https://aider.chat/docs/usage/tutorial.html',
  published_at = '2026-09-02'
WHERE provider_id = 'aider' AND (title LIKE '%Aider 入門%' OR sort_order = 3);
