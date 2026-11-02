# Paddle.js sandbox checkout verification

Issue: [#2845](https://github.com/kanta13jp1/my_web_app/issues/2845)

This flow validates Paddle.js without replacing or modifying the production
Stripe checkout. The Paddle card is hidden by default and is always hidden in a
Flutter release build.

## Cloud-first validation

Run the heavy validation in GitHub Actions instead of on a contributor's local
machine. The `Paddle Sandbox Checkout Cloud Validation` workflow runs
automatically for relevant pull requests and can also be started with
**Actions > Paddle Sandbox Checkout Cloud Validation > Run workflow**.

The GitHub-hosted runner performs the project analysis, focused VM and Chrome
tests, sandbox-enabled debug compilation, and the release-guard compilation.
It uploads the logs and the final `build/web` directory as a seven-day
artifact. Compile-only values in this workflow are deliberately invalid public
placeholders; the workflow does not open Paddle or create a transaction.

After the project-specific sandbox is provisioned, keep the real checkout on a
GitHub-hosted runner too:

1. Store the sandbox client-side token as the repository secret
   `PADDLE_SANDBOX_CLIENT_TOKEN`.
2. Store the sandbox price ID as the repository variable
   `PADDLE_SANDBOX_PRICE_ID`.
3. Set the sandbox default payment link domain to `localhost` in Paddle.
4. Configure the Customer Portal value described in
   [`PADDLE_B2B_VAT_INVOICE_VERIFICATION.md`](PADDLE_B2B_VAT_INVOICE_VERIFICATION.md).
5. Run **Paddle Sandbox Checkout Cloud Validation** with
   `run_real_sandbox_e2e=true` and `run_b2b_vat_e2e=false` (the default).
   This runs cancel, declined-card, and success without any B2B settings.
   Keep `run_static_validation=true` unless the same commit already passed
   the static cloud job.
6. Only when the Owner has a legitimate matching VAT/Tax ID and explicitly
   authorizes its sandbox-only use, configure the B2B values and additionally
   select `run_b2b_vat_e2e=true`. Both flags must be true for B2B testing.

Without an authorized valid VAT/Tax ID, keep `run_b2b_vat_e2e=false`.
Paddle does not provide a documented sandbox-specific identifier. Do not
substitute another company's identifier, Paddle's tax number, or an example
value. A green basic matrix with B2B skipped does not verify VAT or reverse
charge. Selecting B2B with missing configuration fails before SDK setup or
checkout; it is never silently downgraded to a basic-only run.

The real job builds a non-release app, serves it only on the runner's temporary
`localhost:7357`, and runs the selected scenarios serially without retries. It uploads sanitized
Paddle event data, the Playwright report, and screenshots with checkout iframes
masked (including any still-open failed-card form). Automatic screenshots,
traces, and video remain disabled. Never put a Paddle API key in
GitHub Actions or Flutter; this flow accepts only a `test_` client-side token.

Keep local preflight work lightweight:

```powershell
node --check web/paddle_sandbox_bridge.js
git diff --check
```

Do not repeat the full analyzer, Chrome tests, or Web builds locally when the
cloud workflow is available. A real checkout remains an interactive external
verification and is recorded separately in the scenario matrix below.

## Prerequisites

Prepare these values in a Paddle **sandbox** account:

- A client-side token beginning with `test_`. This token is designed for
  frontend use; never put a Paddle API key in Flutter or browser code.
- A sandbox price ID beginning with `pri_`.
- A default payment link configured under **Checkout > Checkout settings**.
  `localhost` may be used for sandbox testing.

Sandbox and live catalogs are separate. A live token or a live-only price ID
must not be used in this flow.

## Run the real sandbox checkout

The GitHub Actions real-sandbox job above is the primary execution path. Use the
interactive fallback below only when Paddle changes its hosted form and the
cloud automation needs a visual diagnosis.

From the repository root, run a non-release Flutter Web session:

```powershell
flutter run -d chrome --web-port 7357 `
  --dart-define=PADDLE_SANDBOX_ENABLED=true `
  --dart-define=PADDLE_SANDBOX_CLIENT_TOKEN=test_REPLACE_ME `
  --dart-define=PADDLE_SANDBOX_PRICE_ID=pri_REPLACE_ME
```

Open `http://localhost:7357/subscription-billing`. Confirm that:

1. Existing Stripe plan and supporter buttons remain present.
2. A separate **Paddle checkout 検証 / SANDBOX ONLY** card appears.
3. Browser network activity does not request Paddle.js until **Paddle sandbox
   を開く** is pressed.
4. Pressing the button loads
   `https://cdn.paddle.com/paddle/v2/paddle.js` and opens an overlay marked as
   test mode.

If the card is absent, confirm this is not a release build and that
`PADDLE_SANDBOX_ENABLED=true` was passed. If the card is visible but disabled,
confirm the `test_` token and `pri_` price ID.

## Scenario matrix

Use an email address you control, any supported country, any future expiry,
and security code `100` where requested.

| Scenario | Steps | Expected Flutter result | Paddle evidence |
| --- | --- | --- | --- |
| Success | Pay with `4242 4242 4242 4242`. | Green completion message and **ホームへ戻る** action. A later `checkout.closed` event must not replace the success state. | Sandbox transaction is present with the captured transaction ID. |
| Failure | Pay with declined card `4000 0000 0000 0002`. | Red failure message; checkout may be retried. Closing after the failure must not relabel it as a cancellation. | Failed payment attempt is visible in sandbox events/console. |
| Cancel | Open the overlay and close it before payment. | Amber cancellation message stating that no charge occurred; retry remains available. | `checkout.closed` is emitted without `checkout.completed`. |

For each scenario, record the date/time (JST), browser and version, result,
checkout ID, transaction ID when available, and a screenshot with personal and
payment data redacted.

## Browser and responsive checks

Run the acceptance matrix in current Chromium. Before enabling Paddle for a
supported release, repeat the matrix in current Edge and any other browser in
that release's support policy. At minimum, also inspect the billing page at
desktop width (1440x900) and mobile width (390x844):

- No overflow or clipped checkout controls.
- The sandbox label and status message remain readable.
- Keyboard focus reaches the launch, retry, and continuation controls.
- No uncaught Flutter or Paddle errors remain in the console.

Safari/Firefox should be checked before claiming cross-browser completion if
they are in the supported browser matrix for the release.

## Production guard

The cloud workflow compiles a release build with the enable flag present. The
release-mode configuration and widget tests verify that the sandbox card has no
UI call path. If troubleshooting requires a local reproduction, use:

```powershell
flutter build web --release `
  --dart-define=PADDLE_SANDBOX_ENABLED=true `
  --dart-define=PADDLE_SANDBOX_CLIENT_TOKEN=test_guard_check `
  --dart-define=PADDLE_SANDBOX_PRICE_ID=pri_guard_check
```

The local `paddle_sandbox_bridge.js` may be present as a dormant bridge, but it
must not load Paddle's CDN script until called, and the release UI provides no
call path.

## Execution record

The project-specific Paddle sandbox matrix completed on a GitHub-hosted runner
without retries. The linked run retains the sanitized event JSON, Playwright
report, and post-result screenshots in artifact
`paddle-real-sandbox-evidence-33308666661-1` until 2026-09-13. The failure and
success tests close the remaining Paddle overlay and then assert that Flutter
still renders **もう一度試す** and **ホームへ戻る**, respectively.

| Date (JST) | Browser | Scenario | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-08-30 20:24:24 | Chromium 151.0.7922.34 | Success | Pass: `checkout.completed`; **ホームへ戻る** remained after overlay close | [run 33308666661](https://github.com/kanta13jp1/my_web_app/actions/runs/33308666661); checkout and transaction IDs captured in the private artifact |
| 2026-08-30 20:24:04 | Chromium 151.0.7922.34 | Failure | Pass: `checkout.payment.failed`; **もう一度試す** remained after overlay close | [run 33308666661](https://github.com/kanta13jp1/my_web_app/actions/runs/33308666661); checkout and failed transaction IDs captured in the private artifact |
| 2026-08-30 20:23:45 | Chromium 151.0.7922.34 | Cancel | Pass: `checkout.closed` without `checkout.completed`; Flutter rendered the no-charge cancellation state | [run 33308666661](https://github.com/kanta13jp1/my_web_app/actions/runs/33308666661); checkout and incomplete transaction IDs captured in the private artifact |

The evidence was captured from Git commit
`a9f61e389dd0265b1d45c48f099dc23eba48e64a`. Playwright reported three
expected passes, zero retries, zero unexpected results, and zero flaky tests.

Do not copy a client-side token, API key, full card form, customer address, or
unredacted personal information into this document, an Issue, or a PR.
