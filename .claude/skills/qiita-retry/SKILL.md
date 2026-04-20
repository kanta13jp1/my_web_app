---
name: qiita-retry
description: |
  Qiita rate limit (>72h 長期 cooldown) に従い JA drafts を Qiita へ dispatch
  する PS版ルーチン。Gate 1 (直前 72h の Qiita 429 が 0 件) + Gate 2 (直近 6h の
  429/成功履歴チェック) + Gate 3 (burst 防止: 1 本/1h+) の 3 段階ゲート方式。
  JST 00:00 固定リセットは**誤前提** / rolling 24h も甘い — 2026-04-20 PS#2 S3
  で 72h 経過でも 429 継続を確認
  (memory/feedback_correction_20260420_qiita_72h_still_429.md)。
  Triggers on: "/qiita-retry", "Qiita リトライ", "Qiita 投稿", "Qiita 429 後",
  "JA版を投稿", "Qiita 記事 dispatch".
---

# Qiita Retry Skill

Qiita rate limit (>72h 長期 cooldown) 解放後に JA 未投稿 drafts を dispatch する。

## 実行前チェック (Step 0: 3段階ゲート)

**重要**: Qiita 429 は **> 72h 長期 cooldown** (rolling 24h ではない・JST 00:00
固定リセットでもない)。4 本連続投稿 (数十秒 burst) は長期 penalty を発動する。
2026-04-20 PS#2 S3 で 2026-04-17T04:04Z から 72h 経過した probe でも 429 継続を確認
(`memory/feedback_correction_20260420_qiita_72h_still_429.md`)。

### Gate 1: 直前 72h Qiita 429 チェック (ROLLING の真の長さ)

```bash
SINCE=$(date -u -d '72 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
     || date -u -v -72H +%Y-%m-%dT%H:%M:%SZ)
RECENT72=$(gh run list --workflow=blog-publish.yml --limit 50 \
  --json databaseId,createdAt \
  --jq ".[] | select(.createdAt > \"$SINCE\") | .databaseId")
Q429_72H=0
for rid in $RECENT72; do
  if gh run view "$rid" --log 2>&1 | grep -q "too_many_requests"; then
    Q429_72H=$((Q429_72H+1))
  fi
done
echo "72h 429 count: $Q429_72H"
# Q429_72H >= 1 なら即停止 (penalty window 内)
```

**判定**:
- `Q429_72H >= 1` → **72h 追加待機必須** (最後の 429 時刻 + 72h 以降に再挑戦)
- `Q429_72H == 0` → Gate 2 へ

### Gate 2: 直近 6h Qiita 試行履歴チェック (burst 検出用)

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

**判定ロジック** (Gate 1 通過後のみ):
- `QIITA_429 >= 1` (直近 6h に 429 あり) → **72h 待機必須 / 即停止** (Gate 1 と整合)
- `QIITA_OK >= 2` → **burst 警戒**: 1h 以上空けてから次の 1 本 (1日 1-2 本上限)
- 両方 0 かつ Gate 1 通過 → Gate 3 (burst 間隔) へ

### Gate 3: Burst 間隔 (1 本/1h+ 絶対ルール)

```bash
# 直近 1h 以内に Qiita 成功があれば停止 (burst 禁止)
SINCE_1H=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -v -1H +%Y-%m-%dT%H:%M:%SZ)
RECENT_1H=$(gh run list --workflow=blog-publish.yml --limit 10 \
  --json databaseId,createdAt \
  --jq ".[] | select(.createdAt > \"$SINCE_1H\") | .databaseId")
BURST=0
for rid in $RECENT_1H; do
  if gh run view "$rid" --log 2>&1 | grep -qE "https://qiita\.com/kanta13jp1/items/[a-z0-9]+"; then
    BURST=1
  fi
done
echo "1h burst risk: $BURST"
# BURST=1 なら即停止 (次の 1 本は 1h+ 後に dispatch)
```

**判定**: `BURST=1` → 1h+ 待機。`BURST=0` かつ Gate 1/2 通過 → Step 1 へ進む。

## Step 1: 未投稿 JA draft 一覧

```bash
for f in docs/blog-drafts/*.md; do
  [[ "$f" == *"-en.md" ]] && continue
  pub=$(grep '^published:' "$f" | head -1 | awk '{print $2}')
  [ "$pub" = "false" ] && echo "$f"
done
```

## Step 2: 1日 1-2 本のみ dispatch (Qiita 72h cooldown 回避)

```bash
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/<slug>.md" \
  -f draft_path_en="docs/blog-drafts/<slug>-en.md" \
  -f platforms="qiita" \
  -f dry_run="false"
```

- **1本ずつ dispatch → run 完了確認 → 1h 以上待機 → 次の 1 本**
- **1 日 1-2 本上限** (workflow 側の circuit breaker=4 は信用しない)
- 4 本連続 burst は **数十秒間** でも >72h cooldown を発動するため厳禁 (PS#2 S3 教訓)
- 40 本 backlog 完遂 → 最短 20-40 日 (1-2 本/日 ペース)

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

429 検出 → **最低 72h 待機後**に再試行 (>72h 長期 cooldown のため 12h や 24h では
不十分)。PS#2 S3 (2026-04-20T07:53Z) で 2026-04-17T04:04Z 最終成功から 72h 経過
した probe でも 429 継続を確認
(`memory/feedback_correction_20260420_qiita_72h_still_429.md`)。

**対処フロー**:
1. 429 検出 → その時刻 + 72h を「次の再挑戦不可時刻」として memory に記録
2. 並行 dispatch の `platforms="qiita,devto"` → **`platforms="devto"` に変更** (devto は生き続ける)
3. Qiita は別日単独 retry
4. それでも継続する場合 → Qiita support
   (<https://support.qiita.com/hc/ja/requests/new>) 経由で大量投稿の事前承認を取る
   (429 エラー message 内にリンクあり)

## 今日の Qiita 投稿数確認 (1-2 本上限)

```bash
# 今日の Qiita 投稿済み記事数を ROADMAP から確認
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
grep -c "qiita.com" docs/GROWTH_STRATEGY_ROADMAP.md 2>/dev/null || echo "0"
```

workflow 側 circuit breaker は 4 本上限だが、Qiita API の 72h cooldown を踏まえ
**実運用は 1-2 本/日**。burst (数秒〜数分内の連投) は絶対禁止。
