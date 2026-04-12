---
title: "GitHub Actions × Supabase で技術記事投稿を自動化した話 — 1日に21本をQiita/dev.toへ"
tags: GitHub,Supabase,GitHubActions,buildinpublic,Flutter
published: false
---

# GitHub Actions × Supabase で技術記事投稿を自動化した話 — 1日に21本をQiita/dev.toへ

## はじめに

個人開発アプリ「自分株式会社」の開発を続けながら、技術記事を書くのが後回しになっていました。

気づいたら `docs/blog-drafts/` に未公開のドラフトが21本も溜まっていました。

この記事では、**1コマンドでQiita/dev.toへ自動投稿するGitHub Actionsワークフロー**を実装して、21本を1セッションで一括公開した話をまとめます。

---

## 問題: ドラフトが溜まる一方

Flutter Web + Supabase の個人開発では機能追加のたびにブログのネタができます。しかし投稿作業が手間で、ドラフトは増えるが公開されない状態が続いていました:

```
docs/blog-drafts/
├── 2026-03-28-note-comments.md       # 未公開
├── 2026-03-31-app-feedback.md        # 未公開
├── 2026-04-01-workflow-automation.md # 未公開
... (21本)
```

---

## 解決策: `blog-publish.yml` — 1コマンド投稿

GitHub Actions のワークフローを作り、`gh workflow run` で任意のドラフトをQiita/dev.toへ投稿できるようにしました。

### ワークフロー全体像

```yaml
name: Blog Publish (技術記事投稿)

on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: '投稿するドラフトのパス'
        required: true
      platforms:
        description: 'qiita, devto, または qiita,devto'
        default: 'qiita,devto'
      dry_run:
        description: 'true=投稿しない, false=実投稿'
        default: 'false'
```

**5つのステップ**:
1. **Step 2**: frontmatter からタイトル・タグを抽出
2. **Step 3**: Supabase `blog_posts` テーブルに登録
3. **Step 4**: `schedule-hub` EF 経由で Qiita / dev.to へ投稿
4. **Step 5**: `published: false` → `published: true` に更新してブランチ作成
5. **Step 6**: 実行ログを `schedule_task_runs` に記録

### 投稿コマンド (1行)

```bash
gh workflow run blog-publish.yml \
  --field draft_path="docs/blog-drafts/2026-04-12-topic.md" \
  --field platforms="qiita,devto" \
  --field dry_run="false"
```

---

## Supabase Edge Function で API を統合

Qiita と dev.to への投稿は `schedule-hub` という Supabase Edge Function が担います。

```typescript
// schedule-hub/index.ts
const publicActions = ["blog.auto_publish", "blog.create"];

case "blog.auto_publish": {
  const { title, content, platforms, tags } = body;
  const results: Record<string, unknown> = {};

  if (platforms.includes("qiita")) {
    results.qiita = await publishToQiita(title, stripFrontmatter(content), tags);
  }
  if (platforms.includes("devto")) {
    results.devto = await publishToDevTo(title, stripFrontmatter(content), tags);
  }
  return json({ results });
}
```

**ポイント**: `publicActions` 配列に入れることで SERVICE_ROLE_KEY での呼び出し時の JWT 認証をスキップ。GitHub Actions から直接呼べます。

### frontmatter の自動除去

Markdown ドラフトには Zenn や Qiita 用の frontmatter が含まれています。Edge Function 側で `stripFrontmatter()` を実行して本文だけを各プラットフォームに送ります:

```typescript
function stripFrontmatter(content: string): string {
  if (!content.startsWith("---")) return content;
  const end = content.indexOf("---", 3);
  return end === -1 ? content : content.slice(end + 3).trim();
}
```

---

## frontmatter の互換性

Zenn形式 (`topics:`) と Qiita形式 (`tags:`) の両方に対応しています:

```bash
# Step 2 での抽出スクリプト
TAGS=$(grep -E '^(tags|topics):' "$DRAFT_PATH" | head -1 | tr -d '\r' | \
  sed 's/^tags: *//;s/^topics: *//' | \
  tr -d '[]"'"'" | tr ',' '\n' | \
  sed 's/^ *//;s/ *$//' | grep -v '^$' | \
  tr '\n' ',' | sed 's/,$//')
[ -z "$TAGS" ] && TAGS="Flutter,Supabase,buildinpublic"
```

| 形式 | 例 | 動作 |
|------|----|----|
| Qiita形式 | `tags: Flutter,Supabase,AI` | ✅ そのまま抽出 |
| Zenn形式 | `topics: ["Flutter", "Supabase"]` | ✅ 変換して抽出 |
| 配列形式 | `tags: [Flutter, Supabase, DNS]` | ✅ 変換して抽出 |
| タグなし | — | ✅ デフォルト値を使用 |

---

## Step 5 の制約: GITHUB_TOKEN とブランチ保護

`published: true` への更新は Step 5 でブランチに push されますが、`GITHUB_TOKEN` はブランチ保護 (require PR) をバイパスできません:

| 方法 | 結果 |
|------|------|
| `git push origin HEAD:main` | ❌ GH006 Protected branch |
| `gh api repos/.../merges POST` | ❌ HTTP 409 |
| `gh pr create` | ❌ GitHub Actions は PR 作成不可 |

**現在の運用**: Step 5 がブランチ `blog-publish/YYYYMMDDHHMMSS` を作成 → ローカルで `git merge --no-edit && git push origin main` でマージ。

**恒久解決策**: リポジトリ設定で `BLOG_PAT` シークレット (bypass 権限付き PAT) を設定すれば完全自動化できます。

---

## 21本を1日で一括公開した手順

```bash
# 未公開ドラフトを一覧
grep -rl "^published: false" docs/blog-drafts/ | sort

# 3本ずつ並行 dispatch
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto" --field dry_run="false"
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto" --field dry_run="false"
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto" --field dry_run="false"

# 完了後、published:true ブランチをまとめてマージ
git fetch origin
git merge origin/blog-publish/20260412-XXXXXX --no-edit
git push origin main
```

3本並行 dispatch × 7セット = 21本を約1時間で公開完了。

---

## 実装のポイントまとめ

| 課題 | 解決策 |
|------|--------|
| Qiita タグ空で 403 | デフォルトタグを設定 |
| GitHub Actions 認証 (401) | `publicActions` で JWT スキップ |
| Zenn/Qiita frontmatter 混在 | `grep -E '^(tags\|topics):'` で両対応 |
| ブランチ保護でマージ不可 | ローカルマージで回避 |
| dev.to 日本語タイトル | UTF-8 エンコード済み URL で投稿成功 |

---

## まとめ

`blog-publish.yml` + Supabase `schedule-hub` EF の組み合わせで、ドラフトから投稿まで1コマンドで完了するワークフローを構築しました。

溜まっていた21本のドラフトを1セッションで一括公開でき、Qiita フォロワー数も増加中です。

技術記事は書きっぱなしにせず、**自動化で公開のハードルを下げる**ことが継続の鍵だと実感しています。

フィードバックお待ちしています。

---

URL: https://my-web-app-b67f4.web.app/
#GitHub #Supabase #GitHubActions #buildinpublic #個人開発
