---
name: qiita-retry
description: |
  Qiita rate limit (rolling ~24h window) に従い JA drafts を Qiita へ dispatch
  する PS版ルーチン。Gate 1 (UTC 15:00 以降) + Gate 2 (直近 6h の 429/成功
  履歴チェック) の 2 段階ゲート方式。JST 00:00 固定リセットは**誤前提** — 2026-04-20
  PS版#2 で確認 (memory/feedback_correction_20260420_qiita_rolling_limit.md)。
  Triggers on: "/qiita-retry", "Qiita リトライ", "Qiita 投稿", "Qiita 429 後",
  "JA版を投稿", "Qiita 記事 dispatch".
---

# Qiita Retry Skill

Qiita rate limit (1日4本) リセット後に JA 未投稿 drafts を dispatch する。

## 実行前チェック (Step 0: 2段階ゲート)

**重要**: Qiita 429 は **rolling ~24h window** (JST 00:00 固定リセットではない)。
UTC 15:00 跨ぎ直後でも直近 24h 内の試行が多すぎれば 429 継続。2026-04-20 PS版#2 で
37本 dev.to dispatch 同時 Qiita 試行 → reset 4h 後も 429 継続を確認
(`memory/feedback_correction_20260420_qiita_rolling_limit.md`)。

### Gate 1: UTC 時刻チェック

```bash
TZ=UTC date
# 15:00 UTC 未満なら即停止 (リセット前)
```

### Gate 2: 直近 6h Qiita 試行履歴チェック (必須追加)

```bash
# 直近 6h (360分) 以内の blog-publish run を確認
SINCE=$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
     || date -u -v -6H +%Y-%m-%dT%H:%M:%SZ)
RECENT=$(gh run list --workflow=blog-publish.yml --limit 20 \
  --json databaseId,createdAt \
  --jq ".[] | select(.createdAt > \"$SINCE\") | .databaseId")

# それぞれ 429 含むか確認
QIITA_429=0
QIITA_OK=0
for rid in $RECENT; do
  if gh run view "$rid" --log 2>&1 | grep -q "too_many_requests"; then
    QIITA_429=$((QIITA_429+1))
  fi
  if gh run view "$rid" --log 2>&1 | grep -qE "https://qiita\.com/kanta13jp1/items/[a-z0-9]+"; then
    QIITA_OK=$((QIITA_OK+1))
  fi
done
echo "recent 6h: 429=$QIITA_429 success=$QIITA_OK"
```

**判定ロジック**:
- `QIITA_429 >= 1` (直近 6h に 429 あり) → **12h 待機必須 / 即停止**
- `QIITA_OK + 未確定 >= 4` (4本近い試行済み) → **12h 待機必須**
- 両方 0 かつ Gate 1 通過 → Step 1 へ進む

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

429 検出 → **最低 12h 待機後**に再試行 (rolling 24h window のため単純 "翌日" は不十分)。
24h フル空け推奨。window 飽和状態では reset 境界跨ぎでも解放されない。

## 今日の Qiita 投稿数確認 (4本上限)

```bash
# 今日の Qiita 投稿済み記事数を ROADMAP から確認
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
grep -c "qiita.com" docs/GROWTH_STRATEGY_ROADMAP.md 2>/dev/null || echo "0"
```
