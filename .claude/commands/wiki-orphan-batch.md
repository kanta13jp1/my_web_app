---
description: Karpathy Lint cycle 補完 — top-N orphan/missing-index を MEMORY index へ batch wikilink 化。wiki-orphan-batch skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 142 着地)。
---

# /wiki-orphan-batch — Karpathy Lint cycle batch cleanup (orphan/missing-index)

Karpathy AI 外部脳 Lint cycle 後の orphan/missing-index 大量項目を MEMORY index へ
batch wikilink 化する slash command。裏側は `.claude/skills/wiki-orphan-batch/SKILL.md`
(Layer 3-5 Agent Skill / part 142) 経由で `scripts/wiki_orphan_batch.py` を呼ぶ。

## 実行

`wiki-orphan-batch` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
# 1. fresh lint
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md

# 2. dry-run
python scripts/wiki_orphan_batch.py --lint-json auto --top 50 --dry-run

# 3. 本番 (orphan source / project_+feedback_success_)
python scripts/wiki_orphan_batch.py --lint-json auto --top 50 \
  --source orphans --prefixes "project_,feedback_success_" \
  --marker "<!-- wiki-batch $(date +%Y-%m-%d) orphans -->"

# 4. 本番 (missing_index source / 全 prefix)
python scripts/wiki_orphan_batch.py --lint-json auto --top 250 \
  --source missing_index \
  --prefixes "project_,feedback_correction_,feedback_success_,query_artifact_,reference_,user_" \
  --marker "<!-- wiki-batch $(date +%Y-%m-%d) missing-idx -->"
```

## 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
```

## 後処理

```bash
echo "- $(date +%Y-%m-%d) wiki-orphan-batch: orphan -<N> / missing -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 関連

- skill: `wiki-orphan-batch` (.claude/skills/wiki-orphan-batch/SKILL.md)
- script: `scripts/wiki_orphan_batch.py` (part 142)
- 並列 cleanup: `/wiki-broken-cleanup` `/wiki-dup-h1-cleanup`
- 前段: `/wiki-lint`
- 実績: part 142 で orphan -440 / missing -904 / Health 0→72
