# Paddle Sandbox Checkout Runbook

Issue: [#2845](https://github.com/kanta13jp1/my_web_app/issues/2845)

## Scope

This runbook verifies the Flutter Web and Paddle.js boundary without changing
the production Stripe billing flow. The route rejects live client-side tokens,
does not call a backend API, and does not persist checkout data.

Paddle's official documentation requires sandbox mode to be set before other
Paddle.js methods, a sandbox client-side token beginning with `test_`, a price
from the sandbox catalog, and a default payment link whose domain matches the
test origin. Client-side tokens are publishable frontend credentials; Paddle
API keys must never be passed to this page.

Primary sources:

- [Paddle.js sandbox environment](https://developer.paddle.com/paddle-js/methods/paddle-environment-set/)
- [Build an overlay checkout](https://developer.paddle.com/build/checkout/build-overlay-checkout/)
- [Paddle.js events](https://developer.paddle.com/paddle-js/events/)
- [Paddle sandbox and test cards](https://developer.paddle.com/sdks/sandbox/)
- [Manage client-side tokens](https://developer.paddle.com/paddle-js/about/client-side-tokens/)

## Prerequisites

In the Paddle sandbox dashboard:

1. Create a sandbox product and price, then copy its `pri_...` ID.
2. Create a client-side token under **Developer tools > Authentication**. It
   must begin with `test_`.
3. Under **Checkout > Checkout settings**, set a default payment link whose
   approved domain matches the test site. Paddle allows `localhost` for sandbox
   testing.
4. Do not copy a Paddle API key into Flutter, a dart-define, screenshots, logs,
   or this repository.

## Cloud-first validation

Do not build Flutter Web or install Playwright locally for routine validation.
Push the scoped branch and open a pull request. The
`Paddle Sandbox Validation` workflow then runs the focused Flutter tests,
targeted analysis, Web build, and desktop/mobile browser checks on GitHub-hosted
runners. Browser checks inject a Paddle.js mock and never create a transaction.

The same workflow can build a one-day private artifact with real sandbox
configuration. Add these repository secrets through GitHub's encrypted secret
UI; do not paste either value into an Issue, PR, shell log, or chat:

- `PADDLE_SANDBOX_CLIENT_TOKEN`: exact `test_...` client-side token
- `PADDLE_SANDBOX_PRICE_ID`: sandbox catalog `pri_...` value

The configured artifact also reuses the repository's existing DEV public
Supabase settings (`SUPABASE_URL_DEV` and
`SUPABASE_PUBLISHABLE_KEY_DEV`, with `SUPABASE_ANON_KEY_DEV` as the legacy
fallback) so the full Flutter app can reach `runApp`. The deterministic mock
job uses non-routable CI-shaped public values and does not connect to a real
Supabase project.

Then dispatch the configured build from GitHub Actions, or with GitHub CLI:

```powershell
gh workflow run paddle-sandbox-validation.yml `
  -f build_configured_sandbox=true
```

The workflow rejects a non-`test_` token before building. Download
`paddle-sandbox-configured-web-<run-id>` only when manual checkout evidence is
being collected; it expires after one day. The client-side token is intended
for frontend use, but the artifact must not be promoted as a production build.

Without all three compile-time values, or on a non-Web build, the launch button
stays disabled. A `live_` token is rejected by both Dart and JavaScript guards.

### Minimal local fallback

If no existing cloud preview can host the private artifact, serve the downloaded
artifact without rebuilding the app:

```powershell
$env:PORT = "7357"
node scripts/serve_flutter_spa.mjs path/to/downloaded/build/web
```

Open `http://localhost:7357/paddle-sandbox` and confirm the page says
**検証専用・実課金なし**. This fallback consumes only the downloaded Web
artifact; Flutter, Dart analysis, package installation, and browser automation
remain on GitHub-hosted runners.

## Execute the three scenarios

Record the timestamp, browser, observed Paddle event, Flutter result text, and
sandbox transaction ID where applicable.

| Scenario | Paddle sandbox action | Expected event | Expected Flutter result |
| --- | --- | --- | --- |
| Success | Use test card `4242 4242 4242 4242`, any future expiry, any name, security code `100` | `checkout.completed` | `Sandbox 決済が完了しました`; transaction ID shown |
| Failure | Use declined test card `4000 0000 0000 0002`, any future expiry and any name | `checkout.payment.failed` or `checkout.payment.error` | `Sandbox 決済が拒否されました`; retry remains available |
| Cancel | Close the overlay before submitting payment | `checkout.closed` | `チェックアウトを閉じました`; page states that payment did not complete |

After the success scenario, verify the transaction exists in the Paddle
sandbox dashboard. Do not treat a mocked browser test or a Flutter widget test
as proof of a real Paddle sandbox transaction.

### Evidence template

```text
Executed at (JST):
Browser and version:
Flutter commit:
Sandbox price ID (non-secret):
Scenario: success / failure / cancel
Observed event:
Observed Flutter result:
Sandbox transaction ID (success only):
Screenshot or dashboard evidence URL:
Console errors:
```

## Automated evidence boundaries

`.github/workflows/paddle-sandbox-validation.yml` produces two distinct kinds
of cloud evidence:

| Evidence | Trigger | Proves | Does not prove |
| --- | --- | --- | --- |
| `paddle-sandbox-mock-browser-<run-id>` | Pull request or manual run | Fail-closed configuration, event state machine, focused widget/static tests, Web compilation, and desktop/mobile mocked Paddle.js events | Paddle accepted a real sandbox payment |
| `paddle-sandbox-configured-web-<run-id>` | Manual run with `build_configured_sandbox=true` | Repository secrets form a buildable sandbox-only Web artifact | The artifact was hosted or a transaction completed |

The deterministic placeholder values used by the first job only verify code
and compilation. Only the timestamped scenarios below, including a Paddle
sandbox dashboard transaction ID for success, satisfy real checkout evidence.

## Known boundary for #2846

This sandbox route displays Paddle's tax-ID field (`showAddTaxId: true`) so the
later VAT test can use the same checkout. It does not yet prefill a business,
store Paddle customer/transaction IDs, create authenticated customer-portal
sessions, or download invoices. Those remain in #2846 after #2845 has real,
timestamped sandbox evidence.
