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
- **Qiita (JA)**: 1日4本超で 429 → 翌日 15:00 UTC (JST翌日0:00) 以降リトライ

**デフォルト**: `platforms="devto"` のみ dispatch (Qiita rate limit 回避)

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

### Step 3: Dispatch

```bash
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/<slug>.md" \
  -f draft_path_en="docs/blog-drafts/<slug>-en.md" \
  -f platforms="devto" \
  -f dry_run="false"
```

**Qiita も投稿する場合** (今日のQiita投稿数 < 4本):

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

429 検出 → 30秒以上待って再 dispatch。

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
4. **Qiita 403 vs 429**: 403 = 無効トークン (要再発行) / 429 = rate limit (翌日リトライ)

## 自動化可能範囲

全 Step 1-9 を 1コマンドで実行できるように統合可。推奨: `scripts/t1-dispatch.sh` へ抽出。
