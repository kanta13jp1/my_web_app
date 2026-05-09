---
description: Karpathy AI 外部脳 Ingest サイクル — raw/ の素材から Atomic Note を生成し memory/vault/ に保存。wiki-ingest skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 140 着地)。
---

# /wiki-ingest — Karpathy Ingest サイクル

Karpathy AI 外部脳の Ingest フェーズを slash command 経由で呼び出す。
裏側は `.claude/skills/wiki-ingest/SKILL.md` (Layer 3-5 Agent Skill / part 139) を経由し、
`scripts/memory_ingest.py` (part 111) が走る。

## 引数

`$ARGUMENTS` で以下のいずれかを渡す:

- file path: `raw/articles/<slug>.md`
- URL: `https://...`
- GitHub Issue 番号: `#1234`
- 省略時: `raw/articles/` `raw/papers/` `raw/repos/` `raw/datasets/` の未処理 file を自動検出

## 実行

`wiki-ingest` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
# file
python scripts/memory_ingest.py --input-file <path> --mode draft --tag karpathy --tag ingest-auto --print

# URL
python scripts/memory_ingest.py --url <URL> --mode draft --tag karpathy --tag ingest-auto --print

# GitHub Issue
python scripts/memory_ingest.py --gh-issue <N> --mode draft --print
```

draft 確認後 `--mode save` で `memory/vault/` 確定。

## 関連

- skill: `wiki-ingest` (.claude/skills/wiki-ingest/SKILL.md)
- script: `scripts/memory_ingest.py` (part 111)
- principle: `docs/SECOND_BRAIN_PRINCIPLES.md` 原則 #3
- 連鎖: `/wiki-compile` (= 3+ 件 ingest 後)
