---
name: digital-product-publishing-loop
description: Prepare explicitly exported or local AI-assisted artifacts for human-reviewed staging in this repository's digital product store. Use for artifact intake, provenance, risk gates, readiness review, rejection/retry, or publication rollback; it does not authorize live publication or financial actions.
---

# Digital Product Publishing Loop

Turn intermediate artifacts into reviewable product candidates while keeping publication authority with a human.

## Boundaries

- Accept only paths the user explicitly provides. For ChatGPT, accept explicit exports only. For Codex, Claude Code, and Antigravity, accept explicit local workspace/artifact paths or exports.
- Never scrape consumer UIs, inspect unrelated task history or auth caches, or use third-party OAuth to control Antigravity.
- Never transmit artifact content or secrets. The local intake helper records hashes, MIME, size, provenance, and finding counts without matched values.
- Preparation and dry-run staging do not authorize Stripe Product/Price creation, charges, live Storage uploads, live database writes, `is_active = true`, deployment, deletion, refunds, or external messages.
- Ask for explicit authorization immediately before each external/live mutation, name the exact target and environment, and preserve proof of outcome. Stop if authorization or proof is missing.
- Do not describe idea briefs as exclusive property or guaranteed copyright. Describe them as non-exclusive reference or planning material.

## Workflow

1. Read `docs/ARTIFACT_PUBLISHING_LOOP.md` and `docs/DIGITAL_PRODUCT_STORE.md`. Preserve existing `/shop` checkout, purchase, and download semantics.
2. Confirm the explicit input paths, source tool, and intake method. Do not broaden the scan root.
3. Run `python scripts/artifact_intake.py ... --output <local-manifest> --fail-on-risk`. Add `--artifact-kind design|prompt|idea|game|...` for ambiguous file types and run different product kinds separately. A risk exit code is a review result, not permission to bypass a gate.
4. Review the manifest locally. Stop and require redaction or replacement for secrets/PII; require human decisions for rights, face/voice consent, ChatGPT Voice Output, and concrete human contribution.
5. Prepare candidate/provenance/check data idempotently by SHA-256. Keep files and matched sensitive values out of the database. Initial products remain inactive.
6. Use `/admin/artifact-publishing` to inspect readiness and record decisions only in their evidence stage: automated scans in `automated_checks`, rights/contribution in `human_review`, and price/object/integrity in `staged`. Use reject/retry or rollback instead of skipping stages.
7. Record concrete human contribution when approving. When moving an approved candidate to staged, link an existing inactive product and enter the reviewed JPY price and private `product-downloads` path. Do not create the Stripe Price, Storage object, or active listing automatically. Verify display price, private bucket/path, object size, and SHA-256.
8. Treat `ready` as a decision packet, not approval to publish. A human must separately authorize the live action with target/environment/rollback proof before `is_active = true` or deployment.
9. If a live product has a problem, stop new sales by explicitly setting it inactive before moving `published` back to `ready`. Never delete purchases, entitlements, or the private artifact as rollback.

Read [references/safety-gates.md](references/safety-gates.md) when evaluating readiness, deciding whether a check may be not-applicable, or preparing a live handoff.
