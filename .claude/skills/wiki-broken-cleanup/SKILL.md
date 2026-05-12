---
name: wiki-broken-cleanup
description: |
  Karpathy Lint cycle 後の broken `[[wikilink]]` を 4 カテゴリに分けて backtick 化する
  自走 skill (= part 142 確立 / wiki_broken_cleanup.py thin wrapper)。
  ユーザー発話 (= 「broken link cleanup」「wikilink 修正」「dead link 一掃」
  「placeholder backtick 化」) を検知し scripts/wiki_broken_cleanup.py を呼ぶ。
  Categories: A dead memory refs / B placeholder / C repo path / D 任意 stem。
  Triggers on: "/wiki-broken-cleanup", "broken link cleanup", "wikilink 修正",
  "dead link 一掃", "placeholder backtick 化", "broken link 真陽性 cleanup".
---

# Wiki Broken Cleanup Skill (Karpathy Lint cycle 補完 / part 142)

Karpathy AI 外部脳の **Lint → 自動 cleanup 4 段 cycle** の 2 番目段。
`scripts/wiki_broken_cleanup.py` (part 142) を呼んで broken `[[wikilink]]` を
backtick 化 (= `[[xxx]]` → `` `xxx` ``) で wikilink 解析対象外にする。

## いつ実行するか

- `wiki-lint` で broken 50+ 検出時
- 月次 cleanup で dup → broken → orphan の順で本 skill を 2 番目に走らせる
- `/wiki-broken-cleanup` slash command 実行時
- 「broken link 真陽性 cleanup」「placeholder noise 排除」発話時

## 4 categories

- **A dead memory file refs**: `[[stem]]` の file が存在しない (= 真 dead)
- **B placeholder example refs**: `[[file]]` `[[<this file>]]` `[[wikilink]]` 等 (= 例文)
- **C repo path refs**: `[[scripts/foo.py]]` `[[lib/.../foo.dart]]` (= cross-reference)
- **D 任意 stem**: 動的検出された dead set

## 実行ステップ

### Step 1: 最新 lint JSON 取得

```bash
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md
```

### Step 2: dry-run で件数事前確認

```bash
python scripts/wiki_broken_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json --dry-run
```

### Step 3: 本番適用

```bash
python scripts/wiki_broken_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json
```

backup file (`.backup_part142_broken_cleanup`) が自動作成される。

### Step 4: 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
# broken 削減を確認 (= 理想 0)
```

### Step 5: backup 削除 (= clean commit 用)

```bash
find . -name "*.backup_part142_broken_cleanup" -not -path "./node_modules/*" -delete
```

### Step 6: ROADMAP-LOG 記録

```bash
echo "- $(date +%Y-%m-%d) wiki-broken-cleanup: broken -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 設計判断

- backtick 化は wikilink 解析対象外にしつつ表示は維持 (= 元情報残す)
- placeholder と dead と repo path を 1 script で同時 cleanup
- `lint script の knowledge-vault-lint/ 自参照除外` patch (= part 142) と併用必須

## 関連 skill

- `wiki-lint`: 本 skill の前段 (= 検出)
- `wiki-orphan-batch`: 並列 cleanup (= orphan)
- `wiki-dup-h1-cleanup`: 並列 cleanup (= duplicate H1)

## 実績 (= part 142 で確立)

- broken 95 → 0 (-95) ✅ 単一 part 内達成
