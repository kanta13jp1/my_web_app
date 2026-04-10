---
description: 重いドキュメント分析を Gemini に委譲してトークンを節約する（ゼロトークンリサーチ）。引数にトピックまたはファイルパスを渡す。
---

**ゼロトークンリサーチ**: 指定されたトピックやドキュメントの重い分析を Gemini API に委譲し、Claude は結果の整理・統合だけを担当する。

## 引数の解釈

`$ARGUMENTS` を以下のいずれかとして処理する:

- **テキスト/トピック**: そのまま Gemini への質問として使う
- **ファイルパス**: ファイルを読み込んで内容を Gemini に渡す
- **複数ファイル (スペース区切り)**: 全ファイルを読んでまとめて分析

## 実行手順

### Step 1: 分析内容を確認

`$ARGUMENTS` を解析し、何を分析するか1行で確認する。

### Step 2: gemini_research.py で分析を実行

```bash
python gemini_research.py "[分析クエリ]"
```

ファイルが指定された場合:

```bash
python gemini_research.py --files "[ファイルパス1]" "[ファイルパス2]" --query "[質問]"
```

スクリプトが存在しない場合や GEMINI_API_KEY が未設定の場合は、その旨を伝えてセットアップ手順を案内する。

### Step 3: 結果を整理・統合

Gemini の出力を受け取り:

1. 重複・冗長な部分を除去
2. このプロジェクトのコンテキストに合わせて解釈
3. アクションアイテムを抽出
4. 必要であれば `docs/` や COMPRESSED_PROMPT_V3.md への反映を提案

### Step 4: 結果の保存 (オプション)

重要な発見は `memory/project_YYYYMMDD.md` に保存することを提案する。

## セットアップ確認

`gemini_research.py` がない場合:

```
⚠️ gemini_research.py が見つかりません。
以下を実行してください:
  python gemini_research.py --setup
または GEMINI_API_KEY 環境変数を設定してから再実行してください。
```

## 使用例

```
/deep-research 競合21社の最新動向をまとめて
/deep-research lib/pages/landing_page.dart のパフォーマンス改善点
/deep-research --files docs/DESIGN.md supabase/functions/ai-assistant/index.ts --query APIとUIの整合性チェック
```
