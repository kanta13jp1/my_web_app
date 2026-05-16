---
description: Karpathy AI 外部脳 Compile サイクル — memory/vault/ の Atomic Note + memory/project_*.md + docs/ から docs/concepts/ + docs/INDEX.md を再生成。wiki-compile skill を呼ぶ thin slash wrapper (Karpathy Layer 3-2 / part 140 着地)。
---

# /wiki-compile — Karpathy Compile サイクル

Karpathy AI 外部脳の Compile フェーズを slash command 経由で呼び出す。
裏側は `.claude/skills/wiki-compile/SKILL.md` (Layer 3-5 Agent Skill / part 139) を経由し、
`scripts/wiki_compile.py` (part 132) が走る。

## 実行

`wiki-compile` skill を Skill tool 経由で起動する。skill が未 surface の場合は直接:

```bash
python scripts/wiki_compile.py
```

出力:
- `docs/concepts/<slug>.md` 概念 page (= 500-1500 語要約 + 関連 link)
- `docs/INDEX.md` マスターインデックス (= 全 concept + entity + source 一覧)

## 後処理

```bash
git status docs/concepts/ docs/INDEX.md
git diff --stat docs/concepts/ docs/INDEX.md | head -30
git add docs/concepts/ docs/INDEX.md
git commit -m "docs(second-brain): wiki-compile re-run (= +<N> concept pages)"
```

`docs/` のみの変更なので dart format / flutter analyze スキップ可。

## 関連

- skill: `wiki-compile` (.claude/skills/wiki-compile/SKILL.md)
- script: `scripts/wiki_compile.py` (part 132)
- principle: `docs/SECOND_BRAIN_PRINCIPLES.md` 原則 #4
- 連鎖: `/wiki-lint` (= compile 後 vault Health 確認)
