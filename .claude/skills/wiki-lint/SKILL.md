---
name: wiki-lint
description: |
  Karpathy AI 外部脳 Layer 3-5 Lint サイクル自走 skill。
  ユーザー発話 (= 「Wiki 健康チェック」「knowledge vault audit」「orphan 検出」
  「Health Score 確認」) を検知し scripts/knowledge_vault_lint.py を呼ぶ。
  orphan / broken link / duplicate title / missing index entries を検出し
  Health Score を算出。weekly cron 既存だが手動補完用.
  Triggers on: "/wiki-lint", "Wiki 健康チェック", "knowledge vault audit",
  "orphan 検出", "Health Score 確認", "vault lint", "memory cleanup status",
  "broken link 検出".
---

# Wiki Lint Skill (Karpathy Layer 3-5 Agent Skills)

Karpathy AI 外部脳の **Lint サイクル** を自走化する skill。
`scripts/knowledge_vault_lint.py` (part 105) を呼んで Vault Health Score を算出.

## いつ実行するか

- 月次 (= 既存 weekly cron 補完 / 手動 trigger)
- `wiki-ingest` で 10+ 件 Atomic Note 追加された後 (= 一括検証)
- 「最近 vault 状態どう?」「cleanup 必要?」発話時
- `/wiki-lint` slash command 実行時

## 実行ステップ

### Step 1: vault lint 実行

```bash
python scripts/knowledge_vault_lint.py --report
```

出力: Health Score (0-100) + 4 カテゴリ counts:
- orphan: docs/INDEX.md / wiki link どこからも参照されない note
- broken: `[[link]]` 先 file が存在しない
- duplicate: title 同一 file 複数
- missing index: vault に存在 / INDEX.md 未掲載

### Step 2: 閾値判定

Health Score < 50 → 即 cleanup. 50-80 → 計画 cleanup. 80+ → 健全.

### Step 3: cleanup 提案

orphan: link 追加 or 削除 提案
broken: link 修正 or 不在 file 作成 提案
duplicate: merge or rename 提案
missing index: `wiki-compile` 再実行で解決

### Step 4: ROADMAP-LOG 記録

```bash
echo "- $(date +%Y-%m-%d) wiki-lint: Health <X>/100 (orphan <N> / broken <N> / dup <N>)" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 設計判断

- 既存 `scripts/knowledge_vault_lint.py` を skill 層から呼ぶ thin wrapper
- 「audit が新たな task を生成する」reflexive pattern (= part 105 確立)
- 自動修正は実行しない (= human-in-the-loop / Karpathy 原則 #5 準拠)

## 関連 skill

- `wiki-ingest`: ingest 後の検証段
- `wiki-compile`: missing index は compile 再実行で解決
- `wiki-query`: lint 結果を NotebookLM に投げて改善案 query
