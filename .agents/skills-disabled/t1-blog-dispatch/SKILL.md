---
name: t1-blog-dispatch
description: |
  T-1 ブログ弾を dev.to (+ 任意で Qiita) へ dispatch する PowerShell版ルーチン。
  Triggers on: "/t1-blog-dispatch", "T-1 第XX弾 dispatch", "ブログdispatch", "dev.toに投稿",
  "T-1 dispatch", "next T-1", "第XX弾 投稿".
  引数: draft slug (例: `voice-ai-chat-conversation-memory`) or 省略 (= 未投稿draft自動選択)
---

# T-1 Blog Dispatch Skill

PowerShell版インスタンスの定型作業。未投稿の JA/EN draft ペアを `blog-publish.yml` へ dispatch する。

## 対象プラットフォーム判断

- **dev.to (EN)**: 常に投稿可。Rate limit 30秒/post → 連続3本以上は間隔空ける
- **Qiita (JA)**: **rolling ~24h window** で 429 (JST 00:00 固定リセットではない — 2026-04-20 PS版#2 確認:
  `memory/feedback_correction_20260420_qiita_rolling_limit.md`)。documented 1日4本だが実際はより厳しい。

**デフォルト**: `platforms="devto"` のみ dispatch (Qiita rate limit 回避)。Qiita を含める場合は **Step 2.5 の rolling-window pre-check 必須**。

## 実行ステップ

### Step 1: 未投稿 draft 検索

引数なしの場合、以下で unpublished drafts を列挙:

```bash
for f in docs/blog-drafts/*-en.md; do
  pub=$(grep '^published:' "$f" | head -1 | awk '{print $2}')
  [ "$pub" = "false" ] && echo "$f"
done
```

引数ありの場合、`docs/blog-drafts/<slug>.md` + `docs/blog-drafts/<slug>-en.md` の存在を確認。

### Step 2: Draft ペア確認

```bash
ls docs/blog-drafts/<slug>.md docs/blog-drafts/<slug>-en.md
head -5 docs/blog-drafts/<slug>.md  # frontmatter確認 (title/tags/published)
```

### Step 2.1: dev.to 4-tag cap pre-check (必須 — PS#2 S14/S15 追加)

`supabase/functions/schedule-hub/index.ts:303` の `rawTags.slice(0, 4)` により dev.to は
**先頭 4 個のタグのみ送信 (警告 log ゼロ)**。frontmatter に 5 tags 書くと 5 番目が silent drop。

```bash
# JA + EN 両 draft のタグ数を確認
for f in docs/blog-drafts/<slug>.md docs/blog-drafts/<slug>-en.md; do
  TAGS=$(grep '^tags:' "$f" | head -1 | sed 's/^tags:[[:space:]]*//')
  COUNT=$(echo "$TAGS" | tr ',' '\n' | wc -l | tr -d ' ')
  echo "$f: $COUNT tags = $TAGS"
  if [ "$COUNT" -gt 4 ]; then
    DROPPED=$(echo "$TAGS" | awk -F',' '{for(i=5;i<=NF;i++) printf "%s ", $i}')
    echo "  ⚠️ SILENT DROP: $DROPPED → 並び替え必要 (価値降順: 最具体 > カテゴリ > 業界 > 運動 > 汎用)"
  fi
done
```

**判定**:

- 全 draft が **4 tags 以下** → 進行 OK
- 5+ tags + 5 番目が汎用 (webdev / programming 等) → 許容し進行 OK
- 5+ tags + 5 番目が specific (SaaS / 製品名等) → **並び替え必須**。
  価値順則: 最具体 (製品名) > 技術カテゴリ > 業界 > 運動 (buildinpublic) > 汎用 (webdev)。
  並び替えて commit → Step 2.3 へ。

関連: `docs/cross-instance-prs/20260420_constraint_devto_4tag_cap.md` /
`memory/feedback_correction_20260420_devto_4tag_cap.md`

### Step 2.3: 並行 dispatch 検出 (dev.to 422 "Title already used in last 5min" 防止 — 必須)

2026-04-20 PS版#2 S1 で 53 秒差 dispatch → 422 duplicate collision 発生
(`memory/feedback_success_20260420_parallel_devto_422.md`)。Step 3 の前に直近 run
を確認して並行 instance を検出する:

```bash
# 直近 5 分以内の blog-publish run を列挙
SINCE=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
     || date -u -v -5M +%Y-%m-%dT%H:%M:%SZ)
RECENT_RUNS=$(gh run list --workflow=blog-publish.yml --limit 5 \
  --json databaseId,status,createdAt \
  --jq ".[] | select(.createdAt > \"$SINCE\") | .databaseId")

if [ -n "$RECENT_RUNS" ]; then
  for rid in $RECENT_RUNS; do
    # 自 draft と同じ slug を dispatch 中か確認
    DRAFT_IN_RUN=$(gh run view "$rid" --log 2>&1 \
      | grep -oE 'DRAFT_PATH[=:_VAR:]*[[:space:]]+docs/blog-drafts/[a-z0-9_-]+\.md' \
      | head -1 | grep -oE 'docs/blog-drafts/[a-z0-9_-]+\.md')
    if [ "$DRAFT_IN_RUN" = "docs/blog-drafts/<slug>.md" ]; then
      echo "⚠️ 並行 dispatch 検出: run $rid が同 draft を処理中 → skip (別 instance が処理中)"
      exit 0
    fi
  done
fi
```

**判定**:

- 直近 5 分以内 run が **同 draft_path** を処理中/完了 → **skip**。別 instance の結果 URL を Step 5 で採用 (orphan branch 片方マージ + 両方削除)
- 直近 5 分以内 run が **別 draft** → 進行可 (blog-publish.yml は run-level concurrency なし)

### Step 2.5: Qiita 同時投稿時の Rolling Window Pre-Check (platforms に qiita 含む場合のみ必須)

`platforms="devto"` 固定なら **このステップはスキップ**。Qiita を含める場合のみ実行:

```bash
# 直近 6h 以内の blog-publish run を確認
SINCE=$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
     || date -u -v -6H +%Y-%m-%dT%H:%M:%SZ)
RECENT=$(gh run list --workflow=blog-publish.yml --limit 20 \
  --json databaseId,createdAt \
  --jq ".[] | select(.createdAt > \"$SINCE\") | .databaseId")

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

**判定**:

- `QIITA_429 >= 1` → Qiita を外して `platforms="devto"` のみで dispatch (rolling window 飽和中)
- `QIITA_OK >= 3` → Qiita 外す (次の試行で 429 リスク高)
- 両方 0 → `platforms="qiita,devto"` で進行可

### Step 3: Dispatch

```bash
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/<slug>.md" \
  -f draft_path_en="docs/blog-drafts/<slug>-en.md" \
  -f platforms="devto" \
  -f dry_run="false"
```

**Qiita も投稿する場合** (Step 2.5 で両方 0 を確認):

```bash
-f platforms="qiita,devto"
```

### Step 4: Run 完了待ち

```bash
until gh run list --workflow=blog-publish.yml --limit 1 --json status --jq '.[0].status == "completed"' | grep -q true; do
  sleep 5
done
gh run list --workflow=blog-publish.yml --limit 1 --json databaseId,conclusion --jq '.[] | "\(.databaseId) \(.conclusion)"'
```

### Step 5: URL 抽出

```bash
gh run view <RUN_ID> --log 2>&1 | grep -oE "https://dev\.to/[a-z0-9-]+/[a-z0-9-]+" | sort -u | head -1
gh run view <RUN_ID> --log 2>&1 | grep -oE "https://qiita\.com/[a-z0-9_-]+/items/[a-z0-9]+" | sort -u | head -1
```

### Step 6: 429 Rate Limit リカバリ

Step 5 で URL が取れない場合、ログ確認:

```bash
gh run view <RUN_ID> --log 2>&1 | grep -iE "429|rate limit" | head -3
```

429 検出 (dev.to) → 30秒以上待って再 dispatch。
429 検出 (Qiita) → **最低 12h 待機** (rolling 24h window。`qiita-retry` skill 参照)。

### Step 7: Orphan branch マージ (workflow_dispatch は branch経由のため)

```bash
# branch名: blog-publish/<RUN_ID>-YYYYMMDD-HHMMSS
git fetch origin "blog-publish/<RUN_ID>-*"
git merge origin/blog-publish/<RUN_ID>-* --no-edit
git pull --rebase origin main && git push origin HEAD:main
git push origin --delete "blog-publish/<RUN_ID>-*"
```

**注意**: `blog-publish.yml` Step 5 は JA のみ `published:true` 更新する。EN も手動で更新:

```bash
sed -i 's/^published: false/published: true/' docs/blog-drafts/<slug>-en.md
git add docs/blog-drafts/<slug>-en.md
git commit -m "docs: <slug> EN published:true"
```

### Step 8: ROADMAP 記録

`docs/GROWTH_STRATEGY_ROADMAP.md` 末尾の PS版セッション記録セクションに:

```markdown
- T-1 第XX弾: <タイトル> → dev.to 投稿成功
  - <URL>
```

### Step 9: Commit + Push

```bash
git add docs/GROWTH_STRATEGY_ROADMAP.md
git commit -m "docs: PS版#XX T-1第XX弾 <title> dev.to投稿成功"
git pull --rebase origin main && git push origin HEAD:main
```

## コンフリクト回避

- **並列 PS セッション**: 同じ drafts を同時 dispatch しない。Step 1 で unpublished list を確認 → 選択 draft を mentally reserve → Step 2 で published:true 化を確認してから Step 3。
- **VSCode版**: `docs/blog-drafts/` 新規作成は VSCode scope。PS 版は dispatch のみ。
- **Windows版**: AI大学 provider ブログは Windows版が書く場合あり。重複避けるため最新 git log を先に確認。

## 既知の落とし穴

1. **GH006 protected branch**: 手動 dispatch は branch 経由 (schedule のみ main 直push 可)
2. **EN frontmatter**: Step 5 が旧版だと EN `published:false` 残る → 手動補完
3. **Zenn published:true**: drafts に既に `published:true` あっても blog-publish は続行 (Zenn check は情報のみ)
4. **Qiita 403 vs 429**: 403 = 無効トークン (要再発行) / 429 = rate limit **rolling 24h window** (JST 00:00 固定リセットではない — 最低 12h 待機)
5. **dev.to 422 "Title already used in last 5min"**: 並行 instance が 5 分以内に同タイトル投稿 →
   workflow は success 扱いだが実投稿は失敗。**Step 2.3 の pre-check で検出**。発生時は先発 run
   (`gh run list --workflow=blog-publish.yml --limit 5`) の URL を採用し、両方の orphan branch を
   diff 比較 (identical なら片方マージ + 両方削除)。詳細: `memory/feedback_success_20260420_parallel_devto_422.md`

## 自動化可能範囲

全 Step 1-9 を 1コマンドで実行できるように統合可。推奨: `scripts/t1-dispatch.sh` へ抽出。
