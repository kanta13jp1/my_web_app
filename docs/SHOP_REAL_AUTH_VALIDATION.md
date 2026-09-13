# Shop — disposable real Auth validation

2026-09-13. The user approved test implementation, PR updates and cloud CI only.
Production DB, main merge, deployment, customer reviews and actual payments remain
separately gated. Claude Code review is optional; human risk acknowledgement and
deterministic validation are not replaced by this lane.

## Purpose and isolation

`Shop Real Auth Validation` adds real Auth-issued user JWTs and PostgREST to the
existing SQL and mocked-HTTP test suites. It does not replace those tests or alter
their assertions. The previous HexCiv/Lumen Path integration remains intact.

```text
Exact PR source → fresh GitHub-hosted runner
                    ├─ unique isolated CLI config (never repository config)
                    ├─ real PG17 + Auth + PostgREST + private empty Storage
                    │    └─ original shop migrations + synthetic fixtures
                    ├─ actual JWT / RLS / column-permission contract tests
                    └─ unchanged application → real password login and reviews
                           └─ desktop + mobile / sanitized evidence
Finalization → stop this run's server and containers → runner disposed
```

CLI `2.84.2` and external Actions are pinned. Actual image tags/digests, PG version,
source SHA and four migration SHA256 values are retained. CLI configuration is
copied to `$RUNNER_TEMP/hexciv-auth-{run_id}-{attempt}` with a unique project ID.
No `link`, `db push`, remote project credentials, GitHub environment secrets, hosted
database, Stripe endpoint or real email is used. Password signup is disabled;
the local Auth admin API creates four confirmed `example.test` users. Credentials
and Auth sessions must never become artifacts. Self-hosted/local runs, nonloopback
endpoints, conflicting hosted credentials and broad temporary paths fail closed.

`auth.enable_signup=false` disables public registration. Keep
`auth.email.enable_signup=true`: in pinned CLI 2.84.2 this maps to the email login
provider switch, not just registration. The suite asserts public signup remains
rejected and creates no extra Auth user. See the [pinned CLI configuration mapping](https://github.com/supabase/cli/blob/v2.84.2/internal/start/start.go#L544-L553).
Do not run this workload on the resource-constrained developer PC.

An isolated Docker bridge defaults published bindings to `127.0.0.1`; the lane
checks actual bindings before applying application SQL. Browser requests pass
through unmodified to localhost. Public renderer/font CDN GETs are the only
external browser allowance. Other external attempts fail the test. Auth/REST
responses, sessions and auth events are **not mocked**.

## Database prerequisites

Apply the checked-in, unchanged files in this order:

1. `20260728010000_create_shop_product_downloads.sql`
2. `20260821015546_generalize_digital_product_store.sql`
3. `20260912041437_shop_product_releases_reviews.sql`
4. `20260912091100_shop_post_funnel_attribution.sql`

Between (2) and (3), explicit privileges model the pre-existing catalog contract:
anon/authenticated SELECT on products; authenticated SELECT on their RLS-scoped
purchases/download events; service-role administration of those old tables.
This is a fixture prerequisite, **not proof of production grants**. New review,
release and attribution grants/RLS come exclusively from the original migrations.
No fake `auth.uid()`, fake `auth.users`, `SET ROLE` impersonation, security-definer
test helper or hosted dump is used. `shop_review_private` is not API-exposed.

The original product seed is changed only in the empty test DB to a clearly
synthetic version and non-matching SHA. Verify that the feature migration does not
publish its Stage 4M seed for that SHA. A separate synthetic release, unpublished
release and future release exercise visibility without inventing a real release
date. The Stripe price ID is synthetic and no checkout/download is executed.

## Acceptance matrix

| Test identity / concern | Required behavior |
|---|---|
| Guest / nonbuyer B | Public releases/reviews readable; posting and private ownership retrieval denied |
| Buyer A | Real JWT; RPC and direct REST create/edit/delete, server version, trim, one review, aggregate |
| Other buyer C | Cannot change/delete A's row; own-review RPC does not return A; private schema inaccessible |
| Refunded buyer D | Can read/delete own prior content; cannot create/edit after refund |
| Direct invalid requests | Bad stars/length, protected version/date/visibility/product, duplicate or forged ownership denied |
| Moderation | Hidden rows excluded from public count/mean; edits do not republish; moderation alone does not forge date |
| Releases | Draft/future filtered; mismatched package SHA never inserts public Stage 4M seed |
| Attribution | No direct client read/write; synthetic server writes exercise four allowed stages and deduplication |
| Browser | Real password Auth, product + UTM continuation, post/reload/edit/delete on desktop and mobile |
| Open editor + logout | Test bridge calls actual Supabase `signOut`; unsent draft invalidated, no new write, guest UI restored |

Denials must be a 4xx or the specifically allowed zero-row RLS response, with
service-role snapshots proving reviews, releases, purchases and attribution did
not change. Service-role is used only for temporary setup/inspection/moderation;
ordinary user operations use that user's actual JWT.

The test-only `test/e2e-real-auth/app.dart` invokes the unchanged `lib/main.dart`.
Its sole JS bridge calls the real client's `auth.signOut()` while the editor is
open. It refuses any other compile-time environment or URL. Production/default
entrypoints never import the bridge. This is not a normal UI logout-button test
nor a test of a queued login callback occurring concurrently with logout; the
existing deterministic callback-race widget tests remain separate.

## Evidence and interpretation

`shop-real-auth-{run_id}-{attempt}` retains environment metadata, completed/pass
flags for API/prepare checks, a browser JSON report and explicit product-only PNGs.
No automatic failure screenshot, trace, video, raw network request/response,
Auth state, service key, password, build defines or frontend build is uploaded.
The allowlist/secret scanner must succeed before upload; partial/failed suites
remain failures, even when earlier individual checks passed.

The browser suite locates email/password controls by their accessible labels.
An obscured field is an HTML `input type=password`, which does not supply an
implicit textbox role. Input operations have a 20-second bound; a failure records
only the input phase and value-free element types, not typed credentials. Safe
API path/method/status observations are attached on failure as well as success.
See [Playwright label locators](https://playwright.dev/docs/locators#locate-by-label)
and [the pinned Flutter input implementation](https://github.com/flutter/flutter/blob/3.38.10/engine/src/flutter/lib/web_ui/lib/src/engine/semantics/text_field.dart#L320-L328).

Passing this lane does **not** prove production P1, sales, bank deposits, the
hosted project's grants/exposed schemas/redirect allowlist, email delivery,
OAuth/MFA, Stripe webhook processing or real customer entitlements. Synthetic
attribution writes are not a production funnel sample. Existing webhook and
mocked purchase/checkout tests remain useful but separate. Do not combine synthetic
events with H1/H2/H4/H7 measurement or describe them as genuine reviews.

References: [official local development](https://supabase.com/docs/guides/local-development),
[CI testing](https://supabase.com/docs/guides/deployment/ci/testing),
[password authentication](https://supabase.com/docs/guides/auth/passwords),
[pinned CLI release](https://github.com/supabase/cli/releases/tag/v2.84.2).
