---
description: 重いドキュメント分析を NotebookLM に委譲してトークンを節約する（ゼロトークンリサーチ）。引数にトピック・ファイルパス・URLを渡す。
---

# /deep-research — ゼロトークンリサーチ

**原則**: 30ファイル以上の分析・競合調査・外部ドキュメント収集はすべて NotebookLM に委譲する。
Claude は **結果の整理・統合・アクション抽出のみ** を担当する。

引数: `$ARGUMENTS`

---

## Step 1: 引数を解析

`$ARGUMENTS` を以下のいずれかとして処理する:

| パターン | 処理方法 |
|---------|---------|
| テキスト/トピック | NotebookLM の Web リサーチ機能で調査 |
| ファイルパス (スペース区切り) | ファイルを読んで NotebookLM に送信 |
| `--url https://...` | URL を NotebookLM に追加して分析 |
| `--files f1 f2 --query 質問` | 複数ファイル + 質問 |

---

## Step 2: セットアップ確認

まず認証状態を確認する:

```bash
PYTHONUTF8=1 python notebooklm_research.py --setup
```

**セットアップ未完了の場合**:
```
セットアップが必要です。以下を実行してください:
  pip install "notebooklm-py[browser]"
  playwright install chromium
  notebooklm login
その後 /deep-research を再実行してください。
```

セットアップが完了している場合はStep 3へ進む。

---

## Step 3: NotebookLM でリサーチ実行

### トピック/質問の場合

```bash
PYTHONUTF8=1 python notebooklm_research.py "$ARGUMENTS"
```

### ファイル分析の場合

```bash
PYTHONUTF8=1 python notebooklm_research.py --files [ファイルパス...] --query "[質問]"
```

### URL 分析の場合

```bash
PYTHONUTF8=1 python notebooklm_research.py --url "[URL]" --query "[質問]"
```

### 複数ファイル + URL 混在の場合

引数を分解して必要に応じて複数回実行し、結果をまとめる。

---

## Step 4: 結果を整理・統合

NotebookLM の出力を受け取り、以下を行う:

1. **重複・冗長な部分を除去**
2. **このプロジェクトのコンテキストに合わせて解釈**
   - 競合調査なら → 自分株式会社への影響と対応策を抽出
   - コード分析なら → 修正すべき箇所とその優先度を整理
   - 技術調査なら → 実装に使えるパターンを抽出
3. **アクションアイテムを抽出**（番号付きリストで提示）
4. **必要なら `docs/` や GROWTH_STRATEGY_ROADMAP.md への反映を提案**

---

## Step 5: 重要な発見の保存（オプション）

発見が今後も参照価値を持つ場合は memory/ に保存することを提案する:

```
保存先: C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\project_YYYYMMDD.md
```

---

## 使用例

```
/deep-research 競合21社の最新動向をまとめて
/deep-research lib/pages/landing_page.dart のパフォーマンス改善点
/deep-research --url https://flutter.dev/docs/release/whats-new --query Flutter最新機能は？
/deep-research --files docs/DESIGN.md supabase/functions/ai-assistant/index.ts --query APIとUIの整合性チェック
/deep-research Notion 3.4の新機能と自分株式会社への影響
```

---

## トークン節約の目安

| 作業 | 通常の Claude 消費 | このワークフロー |
|------|------------------|----------------|
| 30ファイル分析 | ~150K tokens | ~5K tokens (要約整理のみ) |
| 競合調査 (10社) | ~80K tokens | ~3K tokens |
| 技術ドキュメント調査 | ~60K tokens | ~2K tokens |

**月 $20 プランで $200 相当の作業ができる。**
