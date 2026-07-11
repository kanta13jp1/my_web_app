---
name: WEB版 2026-07-11 — SEO H7 (公開ブログ SSR + dev.to canonical) 着地 + 監査 doc 化
description: 匿名read-only SSR を public_memo_view→blog_view 再利用で最小差分クロール可能化。高リスク path (schedule-hub) は独立ヘルパー抽出で unit test 化。H8 は実測で honest pushback → Skip 決定受容。会話ベース監査を SEO_AUDIT_2026-07.md に正本化。
type: feedback
---

# 成功パターン (WEB版 2026-07-11 / SEO 監査 H7 完了)

## 1. 既存 SSR パターンの再利用で最小差分クロール可能化
公開ブログ (`/blog/post`) が SPA アプリ内ナビ引数依存でクロール不可だった問題を、既存の
`public_memo_view.ts` の匿名 read-only SSR パターン (GET query→action body / HEAD preflight /
format=html|json|md|txt / JSON-LD) を `blog_view.ts` に再利用して解決 (#3925)。汎用ヘルパー
(escapeHtml / clampLimit / searchParamsToActionBody 等) を re-export して重複ゼロ。

## 2. 高リスク path 変更は「独立ヘルパーモジュール抽出」で unit test 化
schedule-hub は単一 `index.ts` の top-level `serve()` で、index.ts を test import すると
サーバが起動してしまう。dev.to canonical URL builder を `blog_canonical.ts` に抽出して
`buildOwnSiteBlogPostUrl(id)` を export → `blog_canonical_test.ts` で 3 test (URL 形状 /
encodeURIComponent injection 防止 / 自ドメイン指定)。高リスクゲートの test 要件を満たしつつ副作用回避 (#3927)。

## 3. ユーザー期待を実測で覆す honest pushback が受容された
H8 フォントサブセット「15MB→1-2MB」期待に対し、実測で「安全に削れるのは約18%のみ / UGC の
無限漢字で豆腐(□)発生」を提示し **Skip を推奨**。ユーザーは「1=A(Skip)」で受容。数値裏取り +
ユーザー可視被害の明示 = 説得力ある engineering 判断。

## 4. 会話ベース監査の doc 正本化で再議論を防ぐ
10仮説 SEO 監査は会話に散在していた → `docs/seo/SEO_AUDIT_2026-07.md` に H1-H10 × 対応 × 決定
(H8=Skip / 独自ドメイン=保留) を正本化 (#3941)。将来セッション/インスタンスが蒸し返さない防波堤。

**Why:** 既存パターン再利用 + 独立モジュール抽出 + 実測 pushback + 決定の doc 化 は、いずれも
「最小差分で正しく・検証可能に・持続的に」進める再現可能な型。
**How to apply:** 新 SSR は public_memo_view/blog_view を雛形に。高リスク EF 変更は純関数を別モジュール抽出して test。ユーザー期待と実測が乖離したら数値で pushback。監査/戦略判断は必ず docs/ に正本化。
