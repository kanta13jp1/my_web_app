---
name: wiki-orphan-batch
description: |
  Karpathy Lint cycle 後の orphan/missing-index 大量項目を MEMORY index へ
  batch wikilink 化する自走 skill (= part 142 確立 / wiki_orphan_batch.py thin wrapper)。
  ユーザー発話 (= 「orphan batch やって」「missing index 一掃」「memory index 追記」
  「wikilink batch」) を検知し scripts/wiki_orphan_batch.py を呼ぶ。
  --source orphans|missing_index + --prefixes <csv> で柔軟化。月次分割
  MEMORY_<period>.md へ自動振分。
  Triggers on: "/wiki-orphan-batch", "orphan batch", "missing index 一掃",
  "memory index 追記", "wikilink batch", "MEMORY index 拡張", "vault index cleanup".
---

# Wiki Orphan Batch Skill (Karpathy Lint cycle 補完 / part 142)

Karpathy AI 外部脳の **Lint → 自動 cleanup 4 段 cycle** の cleanup 段を担う skill。
`scripts/wiki_orphan_batch.py` (part 142) を呼んで top-N 件の memory file orphan を
MEMORY index へ `[[stem]]` 行として batch 追記する。

## いつ実行するか

- `wiki-lint` で orphan 100+ or missing-idx 200+ 検出時
- 月次 cleanup の前段 (= dup → broken → orphan の順)
- `/wiki-orphan-batch` slash command 実行時
- 「memory index 拡張したい」「orphan 多すぎ」発話時

## 実行ステップ

### Step 1: 最新 lint JSON 取得

```bash
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md
```

### Step 2: dry-run で件数事前確認

```bash
python scripts/wiki_orphan_batch.py --lint-json auto --top 50 --dry-run
```

### Step 3: 本番適用

```bash
# orphan source (= default)
python scripts/wiki_orphan_batch.py --lint-json auto --top 50 \
  --source orphans --prefixes "project_,feedback_success_" \
  --marker "<!-- wiki-batch $(date +%Y-%m-%d) orphans -->"

# missing_index source (= idx 拡張)
python scripts/wiki_orphan_batch.py --lint-json auto --top 250 \
  --source missing_index \
  --prefixes "project_,feedback_correction_,feedback_success_,query_artifact_,reference_,user_" \
  --marker "<!-- wiki-batch $(date +%Y-%m-%d) missing-idx -->"
```

### Step 4: 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
# orphan / missing-idx 削減を確認
```

### Step 5: ROADMAP-LOG 記録

```bash
echo "- $(date +%Y-%m-%d) wiki-orphan-batch: orphan -<N> / missing -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 設計判断

- 既存 `scripts/wiki_orphan_batch.py` を skill 層から呼ぶ thin wrapper
- `--marker` で重複防止 (= 同一 batch 二重 append 不能)
- 月次分割 `MEMORY_<period>.md` へ `extract_yyyymm()` で自動振分
- 自動修正は memory dir の MEMORY*.md のみ (= repo 影響なし / human-in-the-loop)

## 関連 skill

- `wiki-lint`: 本 skill の前段 (= 検出)
- `wiki-broken-cleanup`: 並列 cleanup (= broken link)
- `wiki-dup-h1-cleanup`: 並列 cleanup (= duplicate H1)
- `wiki-compile`: index 構築の上位

## 実績 (= part 142 で確立)

- batch 1-5 で orphan 2553→2113 (-440) / missing-idx 907→3 (-904)
- Health Score 0→72 単一 part 内達成
