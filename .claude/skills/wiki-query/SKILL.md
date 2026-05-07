---
name: wiki-query
description: |
  Karpathy AI 外部脳 Layer 3-5 Query サイクル自走 skill。
  ユーザー発話 (= 「Wiki に聞いて」「ナレッジベースから探して」「過去の判断確認」
  「Master Brain で確認」) を検知し、NotebookLM CLI (= deep-research / notebooklm) 経由で
  ゼロトークンリサーチを実行する。docs/concepts/ + memory/vault/ + memory/project_*.md を
  cross-reference して引用付き回答を生成。
  Triggers on: "/wiki-query", "Wiki に聞いて", "ナレッジベースから探して",
  "過去の判断確認", "Master Brain で確認", "knowledge base 検索", "過去 session で",
  "Wiki search".
---

# Wiki Query Skill (Karpathy Layer 3-5 Agent Skills)

Karpathy AI 外部脳の **Query サイクル** を自走化する skill。
NotebookLM CLI 経由でゼロトークンリサーチを実行し、`docs/concepts/` + `memory/vault/`
+ `memory/project_*.md` を横断検索して引用付き統合回答を生成。

## いつ実行するか

- 「過去にこの判断したことある?」「以前同じ問題解いた?」発話時
- 競合分析・リサーチで重い文書解析が必要な時 (= Claude Code token 節約)
- セッション冒頭の Master Brain 確認 (= `notebooklm use jibun-master-brain`)
- `/wiki-query` slash command 実行時

## 実行ステップ

### Step 1: NotebookLM CLI 起動

```bash
notebooklm query "<質問>" --notebook jibun-master-brain
```

または `deep-research` skill 経由:

```bash
# topic / file path / URL を引数渡し
deep-research "<topic>"
```

### Step 2: 結果を memory/vault に option 保存

回答が新規洞察 (= 過去 vault に無い概念) を含む場合, `wiki-ingest` skill で
Atomic Note 化:

```bash
python scripts/memory_ingest.py \
  --input-file <回答 markdown> \
  --mode draft \
  --tag karpathy --tag query-result
```

### Step 3: 回答を ROADMAP-LOG / memory/log.md に記録

重要洞察は `docs/GROWTH_STRATEGY_ROADMAP.md` 末尾追記 + `memory/log.md` 1 行追記.

## 設計判断

- **ゼロトークン**: NotebookLM 側で実行 → Claude Code context に full 回答だけ load
- **既存 deep-research / notebooklm skill 再利用**: skill chain 化のみ (新規 script 0)
- **引用必須**: NotebookLM は source citation 自動付与 (= Karpathy 原則準拠)

## 関連 skill

- `wiki-ingest`: 回答が新規洞察なら Atomic Note 化
- `wiki-compile`: query 結果を `docs/concepts/` に統合
- `notebooklm`: NotebookLM 直接操作 (= 本 skill が呼ぶ)
- `deep-research`: ゼロトークンリサーチ (= 本 skill が呼ぶ)
