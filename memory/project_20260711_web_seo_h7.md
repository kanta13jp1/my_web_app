---
name: WEB版 2026-07-11 — SEO H7 実装詳細 (blog SSR / dev.to canonical / publish 経路の table 差異)
description: blog.auto_publish の id は blog.create が作る hub_data 行由来で /blog/post(blog_posts) では解決しない → canonical は blog.publish_post のみ安全。blog.publish_post の postId=blog_posts.id で直後 status='posted' 更新 → canonical 先必ず解決。font: allowRuntimeFetching=false + 11.2MB フル同梱で静的サブセット不可。WBS-SYNC は web sandbox 403 で skip。
type: project
---

# WEB版 2026-07-11 — SEO 監査 H7 実装詳細

## 軸: 公開ブログを検索/LLM にクロール可能化 + dev.to authority 集約

## 新規発見: blog publish の 2 経路と参照テーブルの差異 (重要)
- **`blog.publish_post`** (admin UI + blog-publish.yml review-approved step) — `postId` は
  **`blog_posts.id`**。投稿成功直後に `status='posted'` へ更新され、core-hub `blog_view.ts` が
  `/blog/post?id=X` で SSR 配信する。→ **canonical_url を向けて安全** (必ず解決)。
- **`blog.auto_publish`** (T-1 自動 syndication / blog-publish.yml Step4 + batch_publish.py) — `id` は
  Step3 `blog.create` が作る **`hub_data`** 行 (source='blog_post') 由来。`/blog/post` は `blog_posts`
  を読むため **解決しない**。→ canonical を向けると 404 先宣言になるので**意図的に除外**。
  auto_publish 記事の canonical 集約には blog_posts 化が必要 (別 issue / スコープ外)。

## 実装 (マージ済)
- **#3925 (H7土台)**: `blog_view.ts` + 匿名 action `blog.public.view`/`blog.public.list`
  (status='posted' のみ / HTML/JSON/MD + BlogPosting JSON-LD + 自己参照 canonical)。
  `PublicBlogPostPage` が URL クエリ `?id=X` からも id 解決。日次 smoke に blog.public.list 追加。
- **#3927 (H7本体)**: `blog_canonical.ts` `buildOwnSiteBlogPostUrl(id)` を `blog.publish_post` の
  dev.to payload に `article.canonical_url` として付与。
- **#3941 (監査 doc)**: `docs/seo/SEO_AUDIT_2026-07.md` に H1-H10 × 対応 × 決定を正本化。

## core-hub 匿名 action パターン (再確認)
GET query→action body / HEAD preflight を GET 扱い / `searchParamsToActionBody` が `&amp;` 化け URL の
`amp;` prefix key を救済 / `format=html|json|md|txt`。RLS `public_read_published` (status='posted' のみ anon 可読)。

## Firebase Hosting
`trailingSlash: false` で `/vs-<slug>` を 301 なしに 200 で prerender 静的 HTML 配信 (static > `**` rewrite)。

## font (H8=Skip の技術根拠)
`GoogleFonts.config.allowRuntimeFetching = false` + `web/assets/fonts/NotoSansJP-Regular.ttf` 11.2MB
フル同梱。公開メモ/ブログの UGC は使用漢字が無限 → 静的サブセットだと稀漢字で豆腐(□)。安全減は約18%のみ。

## 決定事項 (2026-07-11)
- H8 フォントサブセット = **Skip** (UGC 豆腐リスク)
- H6 独自ドメイン = **保留** (移行コスト大 / 他レバー優先)

## WBS-SYNC skip 理由
web sandbox から Supabase (`tools-hub` EF) は 403 で到達不可のため wbs.update_progress 実行不能。
SEO 作業の進捗は PR #3925/#3927/#3941 (全マージ済) で追跡可能。次回 local インスタンスで
該当 WBS タスクがあれば更新すること (skip-wbs-sync 相当 / 環境制約による)。
