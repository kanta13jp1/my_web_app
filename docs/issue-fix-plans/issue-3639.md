# Issue Fix Plan #3639

- Issue: [[追加要望] 💰 Stripe本番課金 go-live 統括 — 最優先 (収益化 #1)](https://github.com/kanta13jp1/my_web_app/issues/3639)
- Labels: 追加要望,priority:critical,monetization
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28307600933

## Goal

[追加要望] 💰 Stripe本番課金 go-live 統括 — 最優先 (収益化 #1)

## Current Context

```text
## 💰 収益化 最優先 統括Issue — 「最初の¥1」までのクリティカルパス

WBS + ソースコードの全レイヤー監査（6並列エージェント）の結論：**Stripeサブスク課金パイプラインは既に約90%実装済み・設計通り正しい**。WBSの「課金機能実装 (Stripe) 0%/未着手」は**陳腐化**。設計Issue #1305 はCLOSED（design-complete）だが、**本番go-live（アカウント有効化・secrets・法務ページ・webhook登録）は未実施**。本Issueはその go-live を最優先タスクとして統括する。

### 実装済み（コード側）
- 課金UI: `lib/pages/subscription_billing_page.dart`（`/billing`・`/subscription-billing`、Free¥0 / Pro¥980 / Team¥2,980）
- `lib/services/billing_service.dart`（status / create_checkout_session / create_portal_session）
- Edge: `supabase/functions/schedule-hub/index.ts:1624`（Checkout）・`:1657`（Portal）
- Edge: `supabase/functions/stripe-webhook/index.ts`（HMAC署名検証=暗号学的に正しい / billing_subscriptions upsert）
- DB: `supabase/migrations/20260505203000_create_billing_tables.sql`（`billing_subscriptions` / `billing_usage_counters`、schema一致・RLSはservice roleでbypass）
- Deploy: `.github/workflows/deploy-prod.yml`@HEAD が両関数を `--no-verify-jwt` で自動デプロイ

### 重要な制約
- **Stripe JPY最低課金額は¥50** → 文字通りの「¥1」はStripe不可。最初の実収益 = 設定する最小価格（Pro¥980 もしくは新設の一回払い≥¥50）。真の¥1は非Stripe経路（note¥1チップ等）のみ。
- **実際の入金には、ユーザー本人によるStripeアカウント有効化（JP本人確認+銀行口座KYC、数時間〜数日）が必須**。コードでは短絡不可。

### ユーザーのみ実施可能な runbook（本番入金まで）
1. **Stripe本番(live)アカウント有効化**（JP本人確認+銀行口座）
2. Stripeで Product + 月額Price作成: Pro¥980（≥¥50）、任意でTeam¥2,980 → `price_...` 控える。Customer Portal も有効化
3. 運営者の**実名+連絡先**（電話/住所、または改正特商法の請求時開示+到達可能メール）+ 返金/解約文言を確定し、特商法/利用規約ページのプレースホルダに記入（**販売者名はStripeアカウント法人名と完全一致。「自分株式会社」は登記法人でないため使用不可**）
4. Supabase本番プロジェクト `smmkxxavexumewbfaqpy` の Edge secrets 設定: `STRIPE_SECRET_KEY` `STRIPE_WEBHOOK_SECRET` `STRIPE_PRO_PRICE_ID` `STRIPE_TEAM_PRICE_ID` `PUBLIC_SITE_URL=https://my-web-app-b67f4.web.app`、`SERVICE_ROLE_KEY`（この正確な名前で）。全STRIPE_*は同一mode(live)
5. Stripe webhook登録: `https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/stripe-webhook`（`/functions/v1/` 必須）→ `checkout.session.completed` / `customer.subscription.created|updated|deleted` / `invoice.payment_failed` → `whsec_...` を `STRIPE_WEBHOOK_SECRET` に
6. 本番デプロイ: `gh workflow run "Deploy to Production"`（docs-onlyはpaths-ignoreでデプロイされない）。`schedule-hub`/`stripe-webhook` が `--no-verify-jwt` でデプロイされたかログ確認
7. 本番DBに `billing_subscriptions` / `billing_usage_counters` が存在するか確認
8. **検証**: 本番 `/billing` → Pro「Stripeで開始」→ 実カードで¥980決済 → `?billing=success` 戻り + `billing_subscriptions`(tier=pro/active)行を確認 = **最初の実収益**。検証のみなら Customer Portal で解約

### 子タスク（コード側はClaudeが実施 → PR）
- [ ] 特定商取引法に基づく表記ページ（P0・法務必須）
- [ ] 利用規約ページ（P0・法務必須）
- [ ] プライバシーポリシー 決済(Stripe)追記・「課金なし」削除（P0・法務必須）
- [ ] 課金導線discoverable化（dead アップグレードボタン→/billing + CTA + 「完全無料」コピー修正）（P0・GTM）
- [ ] 返却URLタイポ b6f7f4→b67f4 修正（P0・correctness）
- [ ] webhook堅牢化（payment_status guard + event-id冪等台帳）（P1）
- [ ] サーバー側エンタイトルメント paywall（P1）
- [ ] 使用量メータリング（P1）
- [ ] post-checkout成功UX（P1）
- [ ] 一回払い 支援/投げ銭 経路（P2・真の¥1 fallback）

参照: 設計 #1305 / `docs/MONETIZATION_DESIGN.md` / 監査レポート（本セッション）


```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
