# Paddle B2B VAT and invoice sandbox verification

Issues: [#2845](https://github.com/kanta13jp1/my_web_app/issues/2845),
[#2846](https://github.com/kanta13jp1/my_web_app/issues/2846)

This is a sandbox-only verification path. It does not replace the production
Stripe billing flow and is hidden from Flutter release builds. Heavy analysis,
browser tests, Web builds, and real Paddle interaction run on GitHub-hosted
runners to avoid consuming contributor disk and memory.

## Verified Paddle behavior and design boundary

The implementation is based on Paddle's primary documentation:

- [`Paddle.Checkout.open()`](https://developer.paddle.com/paddle-js/methods/paddle-checkout-open/)
  supports the `showAddTaxId` setting and business tax identifiers. Address and
  tax data are validated and used by Paddle for tax calculation.
- [Checkout settings](https://developer.paddle.com/build/checkout/set-up-checkout-default-settings/)
  describe the buyer-facing **Add tax number** control.
- Paddle explains its
  [Merchant of Record VAT role](https://www.paddle.com/help/sell/tax/how-paddle-handles-vat-on-your-behalf)
  and the possible reverse-charge treatment of qualifying cross-border B2B
  transactions. The outcome is not assumed to be tax-free for every country or
  transaction.
- The hosted
  [Customer Portal](https://developer.paddle.com/concepts/sell/customer-portal/)
  lets a buyer authenticate by email, review transactions, and download PDF
  invoices.
- Paddle's [sandbox documentation](https://developer.paddle.com/sdks/sandbox/)
  states that sandbox customer emails go directly to addresses on the
  account's registered domain; messages for other domains are forwarded to the
  account's main email address. Confirm that the resulting inbox can receive
  the Customer Portal magic link.
- An authenticated
  [customer portal session](https://developer.paddle.com/build/customers/integrate-customer-portal/)
  is temporary. A
  [transaction invoice URL](https://developer.paddle.com/api-reference/transactions/get-transaction-invoice/)
  expires after one hour. Neither kind of temporary URL may be persisted or
  compiled into Flutter.

For the current sandbox milestone, the account/billing page links only to the
stable generic sandbox Customer Portal URL. Paddle performs the email magic-link
authentication. This avoids adding a Paddle API key or customer-ID mapping
before the payment-provider adoption decision is complete.

## Cloud configuration

### Official sandbox VAT scenario status

On 2026-09-02 UTC, Paddle Seller Support confirmed that Paddle does not provide
a documented sandbox-specific VAT/tax identifier for B2B validation or reverse
charge testing. Support could not provide a country, postal code, identifier,
and guaranteed tax outcome combination. Successful tax-ID validation still
requires a valid VAT/tax identifier. The sanitized response summary is recorded
in [#2846](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5511613768).

Do not substitute a third party's VAT ID, Paddle's own tax number, or an
unverified example. The real B2B job must remain guarded and skipped unless the
Owner has a legitimate identifier for the matching buyer country and address
and explicitly authorizes its use in the sandbox-only Actions secret.

Create these repository secrets. Never paste their values into an Issue, PR,
artifact, log, or screenshot:

| Secret | Purpose |
| --- | --- |
| `PADDLE_SANDBOX_CLIENT_TOKEN` | Paddle frontend token beginning with `test_`. |
| `PADDLE_SANDBOX_B2B_EMAIL` | Sandbox purchaser email whose direct or forwarded inbox can receive Customer Portal magic links. |
| `PADDLE_SANDBOX_B2B_TAX_IDENTIFIER` | Owner-controlled valid VAT/Tax ID for the matching sandbox buyer scenario. Paddle does not provide a sandbox-only value. |

Create these repository variables:

| Variable | Example shape | Purpose |
| --- | --- | --- |
| `PADDLE_SANDBOX_PRICE_ID` | `pri_...` | Sandbox price under test. |
| `PADDLE_SANDBOX_CUSTOMER_PORTAL_URL` | `https://sandbox-customer-portal.paddle.com/cpl_...` | Stable generic sandbox portal URL copied from Paddle. No query string or temporary token. |
| `PADDLE_SANDBOX_B2B_COUNTRY_CODE` | two uppercase letters | Billing country that legitimately matches the Owner-controlled identifier. |
| `PADDLE_SANDBOX_B2B_COUNTRY_NAME` | Paddle's English country label | Playwright option label for the same country. |
| `PADDLE_SANDBOX_B2B_POSTAL_CODE` | valid postal code | Matching billing-address evidence. |
| `PADDLE_SANDBOX_B2B_BUSINESS_NAME` | non-personal test name | Sandbox business name. |
| `PADDLE_SANDBOX_B2B_EXPECTED_TAX` | digits in Paddle minor units | Expected post-VAT-ID tax from the confirmed scenario. Use `0` only when Paddle's rules and the chosen transaction support it. |

The sandbox default payment link must allow `localhost`; the real job serves a
short-lived debug build at `http://localhost:7357` only on its GitHub-hosted
runner.

## Run and acceptance evidence

1. In Paddle sandbox, confirm the product, price, default payment link, generic
   Customer Portal URL, and an Owner-controlled valid B2B
   country/address/VAT-ID scenario. If no such scenario is available, leave the
   real B2B job disabled.
2. Set the secrets and variables above.
3. In GitHub Actions, run **Paddle Sandbox Checkout Cloud Validation** with
   **Run the real Paddle sandbox checkout and B2B VAT matrix** enabled.
4. Confirm the serial, retry-free Playwright job is green.
5. Download the 14-day evidence artifact. Confirm that the B2B event log shows:
   a pre-VAT financial snapshot; `hasBusiness: true` and
   `hasTaxIdentifier: true`; the expected final tax; a changed tax or total;
   and `checkout.completed` with a transaction ID.
6. Confirm that the evidence contains no email, business name, address, full
   VAT/Tax ID, token, or payment-field value.

The event bridge deliberately exports only currency, subtotal, tax, total, and
boolean business/tax-ID flags. A VAT ID value is never passed to Dart or the
evidence artifact.

| Date (JST) | Scenario | Expected | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-08-30 | Receipt email and attached PDF | Paddle is the issuer and a paid PDF invoice is retrievable | Passed for the #2845 sandbox checkout: USD 1.00 subtotal + USD 0.09 sales tax = USD 1.09 total. This does not prove B2B VAT or Customer Portal access. | [Owner screenshot review](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5468736129); source images were not persisted because they contain personal and sandbox transaction data. |
| 2026-08-31 | Customer Portal invoice path | Purchase-email magic-link login exposes payment history and an invoice action for a completed transaction | Passed: the Owner authenticated through the generic sandbox portal, saw four paid USD 1.09 payments, opened one payment detail, and reached **View invoice**. The detail showed the expected product and USD 1.00 subtotal + USD 0.09 sales tax = USD 1.09 total. | [Owner screenshot review](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5468736129); source images were not persisted because they contain sandbox transaction data. |
| Blocked | B2B VAT recalculation | Confirmed expected tax and changed tax/total | Not run: Paddle does not provide a sandbox-specific identifier, and no Owner-controlled valid scenario was authorized | [Paddle Support summary](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5511613768) |
| Blocked | Valid card completion | Completed transaction ID | Not run: the guarded B2B scenario requires a valid VAT/Tax ID | [Paddle Support summary](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5511613768) |
| Blocked | B2B invoice portal | The B2B transaction is visible through the already-verified portal path and exposes its invoice | Not run: no completed B2B VAT sandbox transaction exists | [Paddle Support summary](https://github.com/kanta13jp1/my_web_app/issues/2846#issuecomment-5511613768) |

## Invoice retrieval UX check

In the sandbox-enabled debug artifact, open `/subscription-billing` and inspect
**Paddle 請求書（インボイス）**:

1. The help states that Paddle, acting as Merchant of Record, issues the
   invoice.
2. It tells the buyer to enter the purchase email, open the magic link, then
   use **Payments / Download invoice**.
3. **Paddleで過去の請求書を開く** opens only the configured generic sandbox
   portal host.
4. Sign in with the completed transaction's email, find that transaction, and
   download its PDF invoice.
5. Record a redacted screenshot and the GitHub run URL. Do not commit the PDF
   because it can contain personal and tax information.

The generic portal, purchase-email magic link, payment-history list, payment
detail, and **View invoice** action were verified by the Owner on 2026-08-31.
If an Owner-controlled valid VAT scenario is authorized later, the remaining
portal check is limited to confirming that its B2B transaction appears through
the same path; no new portal design or credential mechanism is required.

If the URL is missing, points to the live portal, uses HTTP, has extra path
segments, or contains any query parameter, the button stays disabled. The UI
never promises that entering a VAT ID always makes tax zero.

## Completion record

PR #5106 merged the sandbox-only implementation with required CI green. Issue
#2846 was closed as **not planned** on 2026-09-03 JST after Paddle confirmed the
upstream sandbox limitation. GitHub Issues WBS Sync then completed successfully.
This closure does not claim that VAT-ID recalculation or reverse charge was
verified.

Reopen #2846 only if Paddle publishes an official sandbox identifier/scenario,
or if the Owner supplies a legitimate matching VAT/Tax ID and explicitly
authorizes its sandbox-only handling. In either case, collect dated evidence for
the three blocked rows before changing the result to passed.
