# Public no-signup trial entry — Playwright agent test plan

## Purpose

Verify that a visitor can open the crawlable public WBS entry and follow the
no-signup trial link without authentication or production-data writes.

## Preconditions

- Seed: `test/e2e/seed.spec.ts`
- Project: `chromium`
- Base URL: `E2E_BASE_URL`, defaulting to the public production site.
- JavaScript is disabled for this flow so the deterministic crawlable shell is
  tested without depending on Flutter hydration, authentication, or API data.

## Test scenarios

### 1. Open the public WBS entry

1. Navigate to `/project-gantt`.
2. Verify the response is successful.
3. Verify the visible heading is `WBSガントチャート — 開発を公開`.

Expected result: the public WBS entry has meaningful visible content.

### 2. Continue to the no-signup trial

1. Locate the `登録なしで1件試す` link by its accessible role and name.
2. Follow the link.
3. Verify the destination carries `lp_intent=trial`.
4. Verify the landing page exposes the `自分株式会社` and
   `困っていることを書く` headings.

Expected result: the visitor reaches the public trial entry without credentials.

## Generated test mapping

- Test: `test/e2e/generated/public_no_signup_trial.spec.ts`
- CI command: `npm run e2e:agents -- --project=chromium`
- A skipped, fixed, or quarantined result is not a pass. If the UI no longer
  matches this plan, record a product/test contract defect and return it to the
  lead for review.
