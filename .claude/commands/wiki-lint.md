---
description: Karpathy AI 外部脳 Lint サイクル — vault Health Score 算出 + orphan/broken/dup/missing-index 検出。wiki-lint skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 140 着地)。
---

# /wiki-lint — Karpathy Lint サイクル (Health Score)

Karpathy AI 外部脳の Lint フェーズを slash command 経由で呼び出す。
裏側は `.claude/skills/wiki-lint/SKILL.md` (Layer 3-5 Agent Skill / part 139) を経由し、
`scripts/knowledge_vault_lint.py` (part 105) が走る。

## 実行

`wiki-lint` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
python scripts/knowledge_vault_lint.py --report
```

出力: Health Score (0-100) + 4 カテゴリ counts:

- **orphan**: docs/INDEX.md / wiki link どこからも参照されない note
- **broken**: `[[link]]` 先 file が存在しない
- **duplicate**: title 同一 file 複数
- **missing index**: vault に存在 / INDEX.md 未掲載

## 閾値判定

- Health < 50 → **即 cleanup**
- 50-80 → 計画 cleanup
- 80+ → 健全

## cleanup 提案

- orphan: link 追加 or 削除
- broken: link 修正 or 不在 file 作成
- duplicate: merge or rename
- missing index: `/wiki-compile` 再実行で解決

## 後処理

```bash
echo "- $(date +%Y-%m-%d) wiki-lint: Health <X>/100 (orphan <N> / broken <N> / dup <N>)" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 関連

- skill: `wiki-lint` (.claude/skills/wiki-lint/SKILL.md)
- script: `scripts/knowledge_vault_lint.py` (part 105)
- principle: `docs/SECOND_BRAIN_PRINCIPLES.md` 原則 #5 (human-in-the-loop / 自動修正禁止)
- 連鎖: `/wiki-compile` (= missing index 解消)
