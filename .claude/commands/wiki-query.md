---
description: Karpathy AI 外部脳 Query サイクル — NotebookLM CLI 経由でゼロトークンリサーチを実行し docs/concepts/ + memory/vault/ + memory/project_*.md を横断検索。wiki-query skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 140 着地)。
---

# /wiki-query — Karpathy Query サイクル (ゼロトークン)

Karpathy AI 外部脳の Query フェーズを slash command 経由で呼び出す。
裏側は `.claude/skills/wiki-query/SKILL.md` (Layer 3-5 Agent Skill / part 139) を経由し、
`notebooklm` CLI / `deep-research` skill が走る。NotebookLM 側で実行 → Claude Code context
には full 回答だけ load (= ゼロトークンリサーチ)。

## 引数

`$ARGUMENTS` で質問を渡す。例:

- `「これと類似の判断 過去にあった?」`
- `「競合 21 社のうち AI 大学 type を提供しているのは?」`
- `「Karpathy 4 サイクルの Lint フェーズ 自動化 status」`

## 実行

`wiki-query` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
notebooklm query "$ARGUMENTS" --notebook jibun-master-brain
```

または `deep-research` skill 経由 (= topic / file path / URL を引数渡し)。

## 後処理

回答が新規洞察 (= 過去 vault に無い概念) を含む場合, 連鎖で `/wiki-ingest` 起動:

```bash
python scripts/memory_ingest.py --input-file <回答 markdown> --mode draft --tag karpathy --tag query-result
```

重要洞察は `docs/GROWTH_STRATEGY_ROADMAP.md` 末尾追記 + `memory/log.md` 1 行追記。

## 関連

- skill: `wiki-query` (.claude/skills/wiki-query/SKILL.md)
- skill: `notebooklm` / `deep-research`
- principle: `docs/SECOND_BRAIN_PRINCIPLES.md` 原則 #1 (citation 必須)
- 連鎖: `/wiki-ingest` (= 新規洞察を Atomic Note 化)
