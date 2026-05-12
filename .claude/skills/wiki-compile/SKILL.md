---
name: wiki-compile
description: |
  Karpathy AI 外部脳 Layer 3-5 Compile サイクル自走 skill。
  memory/vault/ の Atomic Note と memory/project_*.md / docs/ から
  docs/concepts/ 概念 page + docs/INDEX.md マスターインデックスを再生成する。
  ユーザー発話 (= 「Wiki 再生成」「concepts 更新」「INDEX 再構築」「compile して」)
  を検知して scripts/wiki_compile.py を呼ぶ。
  Triggers on: "/wiki-compile", "Wiki 再生成", "concepts 更新", "INDEX 再構築",
  "compile して", "docs/concepts 更新", "Master Index 再生成".
---

# Wiki Compile Skill (Karpathy Layer 3-5 Agent Skills)

Karpathy AI 外部脳の **Compile サイクル** を自走化する skill。
`memory/vault/` の Atomic Note + `memory/project_*.md` + `docs/` から
`docs/concepts/` 概念 page + `docs/INDEX.md` マスターインデックスを再生成。

## いつ実行するか

- `wiki-ingest` で 3+ 件 Atomic Note 追加された後
- 週次 (= weekly cron 既存) の手動 trigger 補完
- 「概念 X が docs/concepts に無い」発見時
- `/wiki-compile` slash command 実行時

## 実行ステップ

### Step 1: 既存 wiki_compile.py 起動

```bash
python scripts/wiki_compile.py
```

出力:
- `docs/concepts/<slug>.md` 概念 page (= 500-1500 語要約 + 関連 link)
- `docs/INDEX.md` マスターインデックス (= 全 concept + entity + source 一覧)

### Step 2: 差分確認

```bash
git status docs/concepts/ docs/INDEX.md
git diff --stat docs/concepts/ docs/INDEX.md | head -30
```

### Step 3: dart format / flutter analyze 不要

`docs/` のみの変更なので format/analyze スキップ可.

### Step 4: commit

```bash
git add docs/concepts/ docs/INDEX.md
git commit -m "docs(second-brain): wiki-compile re-run (= +<N> concept pages)"
```

## 設計判断

- 既存 `scripts/wiki_compile.py` (part 132) を skill 層から呼ぶ thin wrapper
- 重複生成防止: 既存 `docs/concepts/<slug>.md` が新規 Atomic Note と diff 0 なら skip
- 80 行 KPI 維持: 概念 page 1 個あたり ~500-1500 語 (= Karpathy 原則準拠)

## 関連 skill

- `wiki-ingest`: raw/ → memory/vault Atomic Note 生成 (前段)
- `wiki-query`: NotebookLM 経由ゼロトークンリサーチ (後段)
- `wiki-lint`: Health Score 算出 (検証段)
