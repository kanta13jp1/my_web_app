---
description: Karpathy Lint cycle 補完 — duplicate H1 を path/stem suffix で unique 化。wiki-dup-h1-cleanup skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 142 着地)。
---

# /wiki-dup-h1-cleanup — Karpathy Lint cycle duplicate H1 cleanup

Karpathy AI 外部脳 Lint cycle 後の duplicate H1 を path/stem suffix で unique 化する
slash command。裏側は `.claude/skills/wiki-dup-h1-cleanup/SKILL.md`
(Layer 3-5 Agent Skill / part 142) 経由で `scripts/wiki_dup_h1_cleanup.py` を呼ぶ。

## 2 type strategy

- **Type A — 同 basename / 異 path**: H1 += suffix で unique 化
  - `docs/archive/` → `[Archive]`
  - `cross-instance-prs/done/` → `[Done]`
  - `blog/cross-post/` → `[Cross-Post]`
  - `blog/github-pages/` → `[GitHub Pages]`
  - `blog/zenn/` → `[Zenn]`
  - `competitor-reports/` → `[Competitor Report]`

- **Type B — 異 basename / 同 H1 (= template H1)**: H1 += `— <filename-stem>`

## 実行

`wiki-dup-h1-cleanup` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
# 1. fresh lint
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md

# 2. dry-run
python scripts/wiki_dup_h1_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json --dry-run

# 3. 本番
python scripts/wiki_dup_h1_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json
```

## 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
# duplicate 削減を確認 (= 理想 0)
```

## 残 dup 手動補正

Type A archive 内の subdir 2 重 (e.g., `docs/archive/<file>.md` + `docs/archive/<sub>/<file>.md`) は
両方に同 suffix が付くため、後者を `[Archive YYYY]` 等に手動置換。

## 後処理

```bash
find . -name "*.backup_part142_dup_cleanup" -not -path "./node_modules/*" -delete
echo "- $(date +%Y-%m-%d) wiki-dup-h1-cleanup: dup -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 関連

- skill: `wiki-dup-h1-cleanup` (.claude/skills/wiki-dup-h1-cleanup/SKILL.md)
- script: `scripts/wiki_dup_h1_cleanup.py` (part 142)
- 並列 cleanup: `/wiki-orphan-batch` `/wiki-broken-cleanup`
- 前段: `/wiki-lint`
- 実績: part 142 で duplicate 30 → 0 (= 26 自動 + 4 手動補正)
