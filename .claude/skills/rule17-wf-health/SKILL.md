---
name: rule17-wf-health
description: |
  毎セッション実行する GitHub Actions ワークフロー健全チェック (CLAUDE.md Rule 9/17)。
  最近の run (20件) を集計し、失敗・cancelled パターンを自動抽出。timeout / concurrency
  設定の鮮度も確認する。PS版専任ルーチン。
  Triggers on: "/rule17-wf-health", "Rule 17 チェック", "WF health", "ワークフロー確認",
  "GitHub Actions 確認", "CI状態", "全WF status".
---

# Rule 17 Workflow Health Check Skill

## ゴール

1. 全 GHA workflow の直近 runs をチェック
2. 失敗パターン (仮性 / 本質) を分類
3. 修正可能なもの (stale comments / timeout不適正) を即修正
4. `docs/GROWTH_STRATEGY_ROADMAP.md` に「Rule 17 チェック」エントリ追記

## 実行ステップ

### Step 1: 全WF 集計

```bash
gh run list --limit 30 --json name,conclusion,status --jq 'group_by(.name) | map({
  name: .[0].name,
  runs: length,
  failed: map(select(.conclusion == "failure")) | length,
  cancelled: map(select(.conclusion == "cancelled")) | length,
  success: map(select(.conclusion == "success")) | length
}) | sort_by(-.failed) | .[]'
```

### Step 2: 失敗 WF の詳細確認

失敗した WF ごとに最新 failed run の log-failed を取得:

```bash
for wf in <failed_workflow.yml>; do
  echo "=== $wf ==="
  LATEST=$(gh run list --workflow=$wf --status failure --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run view $LATEST --log-failed 2>&1 | tail -20
done
```

### Step 3: 失敗分類

| 分類 | 判断基準 | 対応 |
| --- | --- | --- |
| **GH006 protected branch** | `error: GH006` | blog-publish Step 5 に分岐あり — fix済み |
| **Rate limit (429)** | `Rate limit` | 30秒-数分待機後リトライ |
| **Dart format** | `Check formatting` fail | VSCode版へ cross-instance-pr |
| **Deno lint** | `Deno lint` fail | VSCode版へ cross-instance-pr |
| **Deploy migration** | SQLSTATE 42P10 等 | Windows版へ cross-instance-pr (migrations scope) |
| **Token/secret** | `secret` / `auth` fail | 要 secret 再発行 → ユーザーに通知 |
| **Concurrency cancel** | `cancelled` 多発 | paths-ignore で除外 可能か検討 |

### Step 4: Concurrency + timeout 鮮度

```bash
ls .github/workflows/*.yml | xargs -I {} grep -H "timeout-minutes\|cancel-in-progress\|concurrency" {}
```

チェック項目:
- `timeout-minutes` が実態と合っているか (過去コメントに "250本" 等古い数値)
- `cancel-in-progress: true` が deploy 系のみに限定されているか (schedule系は false が安全)
- `concurrency.group` が workflow 間で意図通り重複 or 分離しているか

### Step 5: orphan branch チェック & 一括削除

blog-publish 以外にも蓄積するパターンを検知して一括削除する。

```bash
# 全orphan集計
echo "blog-publish: $(git ls-remote --heads origin 'blog-publish/*' | wc -l)"
echo "cs-check: $(git ls-remote --heads origin 'cs-check-*' | wc -l)"
echo "ai-university-update: $(git ls-remote --heads origin 'ai-university-update/*' | wc -l)"
echo "daily-report: $(git ls-remote --heads origin 'daily-report-*' | wc -l)"
echo "youtube-analysis: $(git ls-remote --heads origin 'youtube-analysis-*' | wc -l)"
echo "claude/*: $(git ls-remote --heads origin 'claude/*' | wc -l)"
```

いずれかが 5本超なら一括削除:

```bash
for pattern in "blog-publish/*" "cs-check-*" "ai-university-update/*" "daily-report-*" "youtube-analysis-*" "claude/*"; do
  count=$(git ls-remote --heads origin "$pattern" | wc -l)
  if [ "$count" -gt 5 ]; then
    echo "⚠️ $pattern: $count本 → 一括削除"
    git ls-remote --heads origin "$pattern" | awk '{print $2}' | sed 's|refs/heads/||' | \
      xargs -P 10 -I {} git push origin --delete {} 2>&1 | grep -c "deleted" || true
  fi
done
```

**注意**: blog-publish orphan は `published:true` 変更を含む場合があるため、削除前に merge する:

```bash
git fetch origin
for branch in $(git branch -r | grep "origin/blog-publish/" | sed 's|.*origin/||'); do
  git merge origin/$branch --no-edit 2>&1
  git push origin --delete "$branch"
done
```

### Step 6: ROADMAP 記録

`docs/GROWTH_STRATEGY_ROADMAP.md` 末尾に追記:

```markdown
### Rule 17 WF health check (YYYY-MM-DD HH:MM)
- 全 WF success率: XX/YY
- 失敗 WF: <list> — <原因 + 対応>
- orphan blog-publish branches: <count>
- 修正済み: <list>
```

### Step 7: Commit

```bash
git add docs/GROWTH_STRATEGY_ROADMAP.md .github/workflows/<if_fixed>
git commit -m "ci: Rule 17 WF health check <date> — <summary>"
git pull --rebase origin main && git push origin HEAD:main
```

## コンフリクト回避

- 他インスタンスが CI 修正を同時進行している可能性 → 先に `gh run list --status in_progress` で確認
- `.github/workflows/` 修正は PS scope 限定。VSCode版の CI 修正 commit を上書きしない

## 頻度

- 毎セッション 1回 (CLAUDE.md Rule 17 — 「Task: cs-check 内」または独立実行)
- 失敗 WF 発覚時 (ad hoc)

## 効果測定

- 平均 failure 率 < 10% 維持
- orphan branch 数 < 5 維持
- `timeout-minutes` コメント鮮度 > 90%
