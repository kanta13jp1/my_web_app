---
name: wiki-dup-h1-cleanup
description: |
  Karpathy Lint cycle 後の duplicate H1 を path/stem suffix で unique 化する自走 skill
  (= part 142 確立 / wiki_dup_h1_cleanup.py thin wrapper)。
  ユーザー発話 (= 「dup H1 cleanup」「duplicate title 解消」「重複タイトル fix」
  「H1 unique 化」) を検知し scripts/wiki_dup_h1_cleanup.py を呼ぶ。
  Type A path-rule (Archive/Done/Cross-Post/Zenn/etc) + Type B stem suffix。
  Triggers on: "/wiki-dup-h1-cleanup", "dup H1 cleanup", "duplicate title 解消",
  "重複タイトル fix", "H1 unique 化", "duplicate H1 batch".
---

# Wiki Duplicate H1 Cleanup Skill (Karpathy Lint cycle 補完 / part 142)

Karpathy AI 外部脳の **Lint → 自動 cleanup 4 段 cycle** の 3 番目段。
`scripts/wiki_dup_h1_cleanup.py` (part 142) を呼んで duplicate H1 を path/stem suffix
で unique 化する。

## いつ実行するか

- `wiki-lint` で duplicate 10+ 検出時
- 月次 cleanup の 1 番目 (= dup → broken → orphan の順)
- `/wiki-dup-h1-cleanup` slash command 実行時
- 「同じ H1 が複数 file に」発話時

## 2 type strategy

- **Type A — 同 basename / 異 path**: H1 += suffix で unique 化
  - `docs/archive/` → `[Archive]`
  - `cross-instance-prs/done/` → `[Done]`
  - `blog/cross-post/` → `[Cross-Post]`
  - `blog/github-pages/` → `[GitHub Pages]`
  - `blog/zenn/` → `[Zenn]`
  - `competitor-reports/` → `[Competitor Report]`

- **Type B — 異 basename / 同 H1 (= template H1)**: H1 += `— <filename-stem>`

## 実行ステップ

### Step 1: 最新 lint JSON 取得

```bash
python scripts/knowledge_vault_lint.py \
  --json-out docs/knowledge-vault-lint/$(date +%Y-%m-%d).json \
  --output docs/knowledge-vault-lint/$(date +%Y-%m-%d).md
```

### Step 2: dry-run で件数事前確認

```bash
python scripts/wiki_dup_h1_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json --dry-run
```

### Step 3: 本番適用

```bash
python scripts/wiki_dup_h1_cleanup.py \
  --lint-json docs/knowledge-vault-lint/$(date +%Y-%m-%d).json
```

backup file (`.backup_part142_dup_cleanup`) が自動作成される。

### Step 4: 効果計測

```bash
python scripts/knowledge_vault_lint.py --report
# duplicate 削減を確認 (= 理想 0)
```

### Step 5: 残 dup 手動補正 (= 同 archive subdir の 2 重)

```bash
# e.g., docs/archive/<file>.md と docs/archive/<sub>/<file>.md 両方に [Archive] が付く
# → 後者を [Archive YYYY] に手動置換
```

### Step 6: backup 削除 (= clean commit 用)

```bash
find . -name "*.backup_part142_dup_cleanup" -not -path "./node_modules/*" -delete
```

### Step 7: ROADMAP-LOG 記録

```bash
echo "- $(date +%Y-%m-%d) wiki-dup-h1-cleanup: dup -<N> / Health +<N>" \
  >> docs/GROWTH_STRATEGY_ROADMAP.md
```

## 設計判断

- H1 一意化のみ (= file rename / delete 禁止 / human-in-the-loop)
- 既存 path-rule で大半 cover / 残 edge case は手動 patch
- backup 自動作成で reviewer 可視化

## 関連 skill

- `wiki-lint`: 本 skill の前段 (= 検出)
- `wiki-orphan-batch`: 並列 cleanup (= orphan)
- `wiki-broken-cleanup`: 並列 cleanup (= broken link)

## 実績 (= part 142 で確立)

- duplicate H1 30 → 0 (-30) ✅ 単一 part 内達成 (= 26 自動 + 4 手動補正)
