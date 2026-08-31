# Authorized paid regeneration and publication

Read this reference whenever the loop may purchase credits, reserve credits,
start a GPU job, or publish a product. A complete improvement loop includes
those actions when they are explicitly authorized; it must not become an
unbounded spending or publishing loop.

## Authorization envelope

Capture the user's approval as structured run state before the first external
mutation. The envelope must identify:

- environment and owner account;
- validity window and whether the approval is one-time or recurring;
- maximum yen spend per run and in total, allowed credit pack, maximum credits
  and regeneration count per run and in total;
- source artifact ID, applied review ID, generation settings, and the user's
  rights/permission, age, terms, and prohibited-content confirmations;
- for publication: exact artifact or an objective selection rule, product ID,
  title, description, price, currency, territory/audience, license, publication
  channels, rights/privacy confirmation, and rollback action.

Store only the approval facts needed for auditability. Do not store payment
credentials, browser tokens, signed download URLs, or other secrets in the
envelope.

Recurring authorization must state both a per-run ceiling and a lifetime or
expiry ceiling. A completed one-time purchase or generation has no remaining
authority. If any required field is absent, perform the safe review work and
report a proposed envelope instead of guessing. When the owner is using Video
Studio, provide a registration action in the product rather than leaving the
item indefinitely in a report-only state.

## Product registration fallback

For a reviewed `improve` artifact without an authorization ID, Video Studio
must offer an explicit bounded form with:

- a 24-hour, 7-day, or 30-day validity window;
- a total regeneration limit and the derived total credit ceiling;
- the fixed 300-credit per-run limit and one generation per run;
- the exact source artifact/review and current generation settings;
- rights, adult, terms, and prohibited-content confirmations; and
- a visible automatic-purchase ceiling.

The balance-only form sets automatic purchase and both yen limits to zero.
Saving the form and reserving the first 300-credit generation are one atomic
operation. If the balance, source review, limits, or queue state fails
validation, no authorization ID is created. This prevents the recurring task
from repeatedly reporting “authorization missing” while also preventing a
stranded approval that never starts.

After the first result is reviewed, a still-active envelope follows the latest
`improve` descendant of its root artifact. Each exact review may create only
one child job. Cloud state, not a local file or scheduled-task prompt, holds
remaining credits, attempts, expiry, and idempotency.

## Paid regeneration sequence

1. Re-read the envelope immediately before payment or credit reservation.
   Reject expired, exhausted, mismatched-owner, or mismatched-environment
   authorization.
2. Prefer existing credits. Purchase only the named pack and only when the
   approved regeneration cannot be funded from the available balance. Record
   the payment/checkout identifier and count it against both spending ceilings.
3. Reserve credits through the production quote, consent, reservation, and
   idempotency flow. Link the exact parent artifact and applied review before
   waking the worker. Never create an unlinked paid generation.
4. Wait for a terminal state. A failed job must refund its reserved credits and
   must not produce a sale candidate. Do not retry a payment or job under a new
   idempotency key until the prior operation's state is known.
5. For success, preserve the immutable output and provenance, append the four
   scores and decision, and debit the envelope once. If the decision remains
   `improve`, continue only when another authorized iteration remains.

Stop on the first of: authorization expiry, budget exhaustion, iteration limit,
failed refund verification, ambiguous external state, rights/privacy block,
two consecutive non-improving iterations, or a result that meets the approved
publication rule. Never buy extra credits merely to use the remaining yen
budget.

## Publication sequence

Publication is part of authorized full-loop completion, not an optional report,
when the publication packet is complete and the selected artifact passes its
rule.

1. Confirm the selected artifact and checksum, review decision/scores, human
   rights/privacy clearance, and all product terms against the packet.
2. Copy or register the exact immutable file in the existing private product
   delivery system. Preserve artifact ID, job ID, review ID, model revision,
   checksum, and lineage in product metadata.
3. Create the Stripe Product/Price and shop record as inactive. Verify currency,
   amount, title, license text, protected delivery, preview safety, and that the
   original artifact remains private.
4. Activate only the approved product and channels. Verify the public listing,
   price consistency, checkout linkage, and unauthenticated download denial.
5. On verification failure, execute the approved rollback by deactivating the
   listing. Preserve the immutable file, audit trail, and any purchase records.

Do not substitute a newer or higher-scoring artifact unless the authorization
packet contains an objective selection rule that selects it. Never publish an
artifact whose rights or privacy state is `review_required` or `blocked`.

## Recurring runs

Each scheduled run must atomically lease one eligible artifact/review chain and
must not overlap another paid run for that chain. Record spend, credits,
iterations, idempotency keys, external product IDs, and remaining authorization
after each run.

When no valid recurring envelope exists, the scheduled run remains review-only
and reports the exact missing fields plus the Video Studio registration path.
When a valid envelope exists, reporting
alone is not completion: execute the approved payment, regeneration, review,
and publication steps until a stopping condition is reached.
