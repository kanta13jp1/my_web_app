---
name: qiita-retry
description: |
  Qiita の 1日4本制限リセット後 (JST 00:00 = UTC 15:00) に未投稿 JA drafts を
  Qiita へ一括 dispatch する PS版ルーチン。
  Triggers on: "/qiita-retry", "Qiita リトライ", "Qiita 投稿", "Qiita 429 後",
  "JA版を投稿", "Qiita 記事 dispatch".
---

# Qiita Retry Skill

Qiita rate limit (1日4本) リセット後に JA 未投稿 drafts を dispatch する。

## 実行前チェック

```bash
# 現在の UTC 時刻確認 (リセット = 15:00 UTC = JST 00:00)
TZ=UTC date
# → 15:00 UTC 以降なら実行可
```

UTC 15:00 未満の場合は **実行しない**。

## Step 1: 未投稿 JA draft 一覧

```bash
for f in docs/blog-drafts/*.md; do
  [[ "$f" == *"-en.md" ]] && continue
  pub=$(grep '^published:' "$f" | head -1 | awk '{print $2}')
  [ "$pub" = "false" ] && echo "$f"
done
```

## Step 2: 1日 4本ずつ dispatch (Qiita 制限)

```bash
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/<slug>.md" \
  -f draft_path_en="docs/blog-drafts/<slug>-en.md" \
  -f platforms="qiita" \
  -f dry_run="false"
```

- 1本ずつ dispatch → run 完了確認 → 30秒待機 → 次の1本
- 4本で今日の上限 → 残りは翌日 (次回 UTC 15:00 以降)

## Step 3: run 完了確認 & URL 抽出

```bash
until gh run list --workflow=blog-publish.yml --limit 1 --json status \
  --jq '.[0].status == "completed"' | grep -q true; do sleep 5; done

RUN_ID=$(gh run list --workflow=blog-publish.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view $RUN_ID --log 2>&1 | grep -oE "https://qiita\.com/[a-z0-9_-]+/items/[a-z0-9]+" | sort -u
```

## Step 4: orphan branch マージ + 削除

```bash
git fetch origin
BRANCH=$(git branch -r | grep "blog-publish/${RUN_ID}" | sed 's/.*origin\///')
git merge origin/$BRANCH --no-edit
git push origin --delete "$BRANCH"
```

## Step 5: ROADMAP 記録

```bash
cat >> docs/GROWTH_STRATEGY_ROADMAP.md << EOF
- T-1 第XX弾 Qiita: <タイトル>
  - https://qiita.com/kanta13jp1/items/XXXX
EOF
git add docs/GROWTH_STRATEGY_ROADMAP.md
git commit -m "docs: Qiita retry 第XX弾 <slug>"
git pull --rebase origin main && git push origin HEAD:main
```

## 429 エラー時

```bash
gh run view $RUN_ID --log 2>&1 | grep -iE "429|rate limit" | head -3
```

429 検出 → 翌日 UTC 15:00 以降に再試行。

## 今日の Qiita 投稿数確認 (4本上限)

```bash
# 今日の Qiita 投稿済み記事数を ROADMAP から確認
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
grep -c "qiita.com" docs/GROWTH_STRATEGY_ROADMAP.md 2>/dev/null || echo "0"
```
