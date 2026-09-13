# HexCiv shop integration candidate

## Source boundary

- Base: PR #5397 at `4682e6e6158bca87e1749b6a7b6259d02f0dd9b1`, including main `8133d8915d03bcb623aeb581ad3a0f0a3c52dc51`.
- Selected shop changes: `codex/hexciv-shop-browser-20260912` at `cc792b870489b9a8f6451303b0537e366948b208` (which includes funnel PR #5388 at `c20ed4b58228887438d9533391fceadbab758144`).
- Three-way product-page merge used common base `d363f141b799855c70a8a85cc259ac26a41c996e`. It preserves release/review navigation, product-specific repositories and the existing checkout/download contracts.
- This is scoped integration, not a merge or closure of the other PR/branch. Their historical finance sorting-test edits and finance-only guard were not introduced. Main's fixed-date asset-management test remains unchanged and covered by full CI.

## Included behavior

The ordinary product route now has one default funnel service, while an injected service still takes precedence. Its stable visitor identity accompanies the checkout request; failed telemetry must not block shopping. Error text no longer displays internal exception details. Pending entitlements are described as unconfirmed, not paid. Button contrast, loading announcements and actual gallery decode/selection are preserved alongside distribution version, release history and purchaser reviews.

## Verification

- The base candidate passed full CI34679196873 (3334 VM tests, 2 browser import tests, analysis, formatting and release Web build), focused community CI34679196881 (41 tests and SQL PASS), and visual CI34679196908 (6 baseline comparisons). These are **base evidence**, not proof of this integrated candidate.
- Run community validation, shop/funnel regression, existing baseline comparisons, isolated desktop/mobile shop fixtures, and full PR CI on the exact new candidate.
- Added a narrow widget test: a real HTTP-mocked telemetry outage does not prevent review save and owned download.
- Added a real Flutter browser-route fixture covering distribution version, review navigation/empty state and retained owned-download controls. HTTP/auth remain fake and confined to runner localhost; this is not authenticated backend E2E or production P1.
- No package versions, production credentials, schema/RLS, billing rules or game ZIPs changed in this integration.

## Remaining release work

Claude Code review is optional. Required human schema/RLS acknowledgement, approved-environment authenticated E2E, applicable AT verification, and explicit production approval remain. Do not create fake public customer reviews. Deploy through the existing guarded production pipeline only after authorization.

H1/H2 recording is still awaiting production verification. H4/H7 still need post-level attribution (`utm_content` and campaign propagation through checkout/webhook). H9 demo distribution and H5 marketplace setup are separate. H10 update visibility remains preparation, not measured sales evidence. Prices, experiment criteria and conclusions are unchanged.
