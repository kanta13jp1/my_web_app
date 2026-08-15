# SEO 監査 2026-07 — 10仮説 × 対応状況 × 決定事項

**監査手法**: 「10の仮説をたてて全て検証する」方式（ユーザー指示 2026-07 / WEB版セッション）
**目的**: Google 検索で各種キーワード上位表示を狙う（オーガニック流入の資産化）
**対象**: 本番 <https://my-web-app-b67f4.web.app/>（Flutter Web + Supabase + Firebase Hosting）

> **正本**: このファイルが SEO 監査の canonical。将来セッション/インスタンスは着手前に本ファイルを参照し、**決定事項（H8 / 独自ドメイン）を蒸し返さないこと**。

---

## 根本原因（一言）

**インデックス性の崩壊** = 全URLが同一 SPA シェル（`index.html`）を配信し、canonical がトップ固定、本文は CanvasKit の canvas 描画で非JSクローラーに不可視。これが他全施策の前提だった。解決の本命は「**ビルド時 per-route 静的HTML（prerender / SSR）**」。

---

## 10仮説 監査結果

| # | 仮説 | 初期判定 | 対応内容 | 状態 | PR |
|---|------|---------|---------|------|-----|
| **H1** | 全ルートが同一 `index.html` を配信（indexability collapse の核） | confirmed / high | 厳選ルートを build 時 prerender し per-route 静的HTMLを Firebase 優先配信 | ✅ 完了 | #3899 / #3915 |
| **H2** | SPAルートに prerender/SSR が無く、title/meta が全URL非ユニーク | confirmed / high | prerender + per-route meta。公開メモ/ブログは core-hub で SSR | ✅ 完了 | #3899 / #3915 / #3925 |
| **H3** | sitemap 肥大・陳腐化・二重管理（`web/sitemap.xml` 1990 URL、dead root sitemap.xml/robots.txt） | confirmed / high | `generate_sitemap.py` で 47 URL に精選 + fresh lastmod、死にファイル削除 | ✅ 完了 | #3899 |
| **H4** | title/meta description が全インデックス対象URLで非ユニーク | confirmed / high | 各ページ自己参照 canonical + per-route title/description、`vsMatch` に決定的 fallback | ✅ 完了 | #3895 / #3915 |
| **H5** | キーワード戦略の焦点分散（代替スタッフィング / 無スペース語形 / doorway 化） | partially / medium | 厳選30社に刈込・実ページ化、可視 H2 を高需要日本語見出しへ差替 | ✅ 完了 | #3899 / #3915 |
| **H6** | デフォルト `web.app` サブドメインでブランド弱・E-E-A-T 運営者情報が client-side のみで非クロール | partially / medium | 法務フッター（経営哲学 / 特定商取引法 / 利用規約 / プライバシー）+ 運営者情報を実リンク化。**独自ドメインは保留（下記決定）** | 🟡 一部完了 | #3915 |
| **H7** | 被リンク・オーソリティ皆無、dev.to へ authority 流出、公開ブログが非クロール | partially / medium | 公開ブログを SSR + クロール可能URL化（`/blog/post?id=X`）、dev.to `canonical_url` を自サイトへ向け authority 集約 | ✅ 完了 | #3925 / #3927 |
| **H8** | Core Web Vitals：11.2MB 無サブセット NotoSansJP を CanvasKit 起動 critical path で同梱 | partially / medium | **Skip（下記決定）** — 静的サブセットは UGC（公開メモ/ブログ）の無限漢字で豆腐（□）リスク | ⏭ Skip 決定 | — |
| **H9** | 構造化データの網羅不足（Organization / WebSite / Article） | partially / medium | `<head>` に `@graph` で Organization + WebSite(+SearchAction) + Article/BlogPosting/BreadcrumbList/FAQPage JSON-LD を静的追加 | ✅ 完了 | #3895 |
| **H10** | インデックス制御（canonical / hreflang / robots） | partially / medium | 自己参照 canonical + robots 整備。hreflang は JP 単一言語のため対応不要と判断 | ✅ 完了 | #3895 |

**サマリ**: 10仮説中 **9つ実装完了**（H1–H7・H9・H10）、**H8 は意図的 Skip の決定**。新規に着手すべき未対応仮説は無し。残るはいずれも「実装より先に方針判断が要る」項目で、下記で決着済み。

---

## 決定事項（2026-07-11）

### H8 フォント / Core Web Vitals → **A: Skip**

- 実測上、期待の「15MB→1–2MB」は日本語グリフを壊さず達成不能（安全に削れるのは約18%のみ）。
- 公開メモ / ブログのユーザー生成日本語は**使用漢字が無限**のため、`allowRuntimeFetching=false`（フル同梱）前提の静的サブセットだと稀漢字で**豆腐（□）**が発生する。
- 3.3ポイント程度の LCP 改善のためにユーザー可視の文字化けを招くのは割に合わない → **現状維持（11.2MB フル同梱）**。
- CWV 改善は将来、**初回JS遅延ロード等の非破壊手段**で別途検討する。

### H6 独自ドメイン → **a: 保留**

- authority / ブランド / E-E-A-T の底上げにはなるが、ドメイン取得・DNS・Firebase Hosting 設定・全 canonical/sitemap/OG の URL 移行を伴う。
- 現時点では `my-web-app-b67f4.web.app` を継続。他レバー優先。将来再検討。

---

## 実装アーティファクト（参照）

- `scripts/prerender_seo_routes.py` — `build_route_html`（/vs-* 比較ページ）+ `build_public_route_html`（主要公開ページ）
- `scripts/generate_sitemap.py` — `PUBLIC_ROUTES` + comparison-routes から 47 URL 生成
- `web/seo/comparison-routes.json` — 厳選30社 / `web/seo/public-routes.json` — 主要8公開ルート
- `supabase/functions/core-hub/public_memo_view.ts` / `blog_view.ts` — 公開メモ / ブログの匿名 SSR（HTML/JSON/MD/txt + JSON-LD）
- `supabase/functions/schedule-hub/blog_canonical.ts` — dev.to `canonical_url` を自サイト `/blog/post?id=X` へ向けるヘルパー
- `.github/workflows/public-memo-smoke.yml` — 日次 smoke（06:07 JST）。memo/blog の匿名アクセス + prerender 済 /vs-notion を回帰検知
- `.github/workflows/deploy-prod.yml` — prerender + sitemap 生成ステップを内包

## 関連 PR

| PR | 内容 |
|----|------|
| #3895 | metadata hardening（Organization/WebSite/Article JSON-LD + public canonical fixes） |
| #3899 | prerender 厳選30社の /vs-* 静的ページ + sitemap 刈込 |
| #3902 | `trailingSlash=false`（/vs-<slug> を 200 で prerender 配信） |
| #3915 | 主要公開ページ prerender 拡張 + 可視H2の日本語化 |
| #3925 | 公開ブログを SSR + クロール可能URL化（H7 土台） |
| #3927 | dev.to `canonical_url` を自サイトへ向ける（H7 本体） |
