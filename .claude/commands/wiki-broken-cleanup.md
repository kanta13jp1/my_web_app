---
description: Karpathy Lint cycle 補完 — broken `[[wikilink]]` 真陽性を 4 カテゴリで backtick 化。wiki-broken-cleanup skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 142 着地)。
---

# /wiki-broken-cleanup — Karpathy Lint cycle broken link cleanup

Karpathy AI 外部脳 Lint cycle 後の broken `[[wikilink]]` を 4 カテゴリに分けて
backtick 化する slash command。裏側は `.claude/skills/wiki-broken-cleanup/SKILL.md`
(Layer 3-5 Agent Skill / part 142) 経由で `scripts/wiki_broken_cleanup.py` を呼ぶ。

## 4 categories

- **A dead memory file refs**: `[[stem]]` の file が存在しない (= 真 dead)
- **B placeholder example refs**: `[[file]]` `[[<this file>]]` `[[wikilink]]` 等 (= 例文)
- **C repo path refs**: `[[scripts/foo.py]]` `[[lib/.../foo.dart]]` (= cross-reference)
- **D 任意 stem**: 動的検出された dead set

## 実行

`wiki-broken-cleanup` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
# 1. fresh lint
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md

# 2. dry-run
python scripts/wiki_broken_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json --dry-run

# 3. 本番
python scripts/wiki_broken_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json
```

## 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
# broken 削減を確認 (= 理想 0)
```

## 後処理

```bash
find . -name "*.backup_part142_broken_cleanup" -not -path "./node_modules/*" -delete
echo "- $(date +%Y-%m-%d) wiki-broken-cleanup: broken -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 関連

- skill: `wiki-broken-cleanup` (.claude/skills/wiki-broken-cleanup/SKILL.md)
- script: `scripts/wiki_broken_cleanup.py` (part 142)
- 並列 cleanup: `/wiki-orphan-batch` `/wiki-dup-h1-cleanup`
- 前段: `/wiki-lint`
- 実績: part 142 で broken 95 → 0 (-95)
