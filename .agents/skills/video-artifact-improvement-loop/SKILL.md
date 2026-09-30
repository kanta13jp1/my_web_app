---
name: video-artifact-improvement-loop
description: Preserve, review, remediate review findings, regenerate, re-review, and commercialize first-party GPU video generations with immutable lineage using a cloud-first workflow. Treat paid regeneration and approved publication as required completion stages whenever a valid authorization envelope covers them. Use for the site's Video Studio artifact, quality-improvement, commercialization, or recurring-generation workflow.
---

# Video Artifact Improvement Loop

Use this workflow for the site's own GPU video generations. Read
`references/schema.md` before changing tables, Edge Functions, worker
completion, or the Video Studio UI.

## Keep execution cloud-first

Read `references/cloud-execution.md` at the start of every manual or scheduled
run. Keep Codex as a lightweight control plane and perform durable or heavy
work in the site's existing Supabase and GCP services.

- Query queues and authorization state with bounded server-side SQL/RPC calls.
  Return only IDs, states, scores, limits, and other small metadata needed for
  the current decision.
- Keep originals, derived evidence, hashes, and provenance in private cloud
  storage. Do not download MP4 files, model weights, or frame sequences to the
  local workspace and do not run local FFmpeg, OpenCV, or model inference.
- Generate, checksum, probe, and transcode in the GCP worker path. Use a
  short-lived signed URL only for one-at-a-time streamed inspection when the
  cloud-stored evidence is insufficient; never persist that URL or media
  locally.
- Scheduled runs must not run Flutter builds, Docker, local database stacks,
  or broad repository scans unless that run is explicitly implementing or
  validating a code change. Normal loop runs operate only on cloud state.
- If a required remote review or mutation endpoint does not exist, stop at the
  metadata-safe boundary and report the missing cloud capability. Do not fall
  back to a full local download merely to complete the run.

## Treat the full loop as the only completed mode

Every eligible lineage passes through these six stage gates in order:

1. preserve and review the current successful artifact;
2. turn every actionable review finding into a concrete prompt or setting
   change linked to the exact artifact and review;
3. execute the authorized billing path, preferring existing credits and buying
   only the approved pack when the balance is insufficient;
4. regenerate through the normal reservation and GCP worker path;
5. preserve and re-review the child artifact, then repeat from stage 2 while
   findings remain and the authorization permits another iteration;
6. create or resume the approved product draft, verify protected delivery and
   price, activate it, and verify the public listing when the publication
   packet covers the selected artifact.

No eligible stage may be silently skipped. A genuinely empty queue, sufficient
existing balance, or an already verified listing is a checked terminal result,
not a skipped stage. When authorization or evidence is missing, complete all
safe stages, keep the lineage in `pending_authorization` or
`pending_evidence`, and report the exact missing field or owner action. Do not
call that run complete and do not discard the pending work.

Use **authorized full-loop mode** whenever a current machine-checkable
authorization envelope covers the paid or public mutations. Do not stop after
review or ask for duplicate approval: execute all covered stages to a stopping
condition. Without that envelope, the run is a pending full loop, not a
successful review-only loop.

- Read `references/authorized-actions.md` before spending money, reserving
  credits, starting a GPU job, creating or activating a product, or configuring
  a recurring run to do any of those things.

An approval is consumed according to its stated scope. Never reinterpret a
one-time approval as permission for later runs, and never infer an hourly or
recurring budget from a single completed purchase.

## Resume all three queues

At the start of every manual or scheduled run, inspect all three queues. Do not
use “new succeeded or unreviewed video” as the only eligibility test.

1. **Review queue:** a succeeded job has no artifact or its artifact has no
   review. Preserve and review it.
2. **Regeneration queue:** the newest successful artifact in a lineage has a
   latest review with decision `improve`, no later child job already consumed
   that exact review, and a valid authorization envelope still has budget and
   iterations. Resume from that artifact/review even though it was already
   reviewed in an earlier run.
3. **Publication queue:** an artifact satisfies the authorization envelope's
   objective publication rule and complete publication packet, but the exact
   approved `/shop` product is not yet verified as active. Resume the draft,
   verification, activation, or rollback step as appropriate.

For scheduled cloud control, call production `video-generation-hub` with the
exact service-role bearer and one explicit owner UUID only for
`authorization_status`, `run_authorized_improvement`,
`capabilities`, `review_authorized_artifact`, or exact-job `status`. First call
the read-only `capabilities` action and require `review_authorized_artifact` in
`scheduler_actions`. Then use `review_authorized_artifact` only with the exact
authorization ID and an unreviewed artifact produced by a succeeded job under
that authorization. Base every score and finding on cloud evidence; never infer
visual quality from metadata.
The service role must never call `authorize_improvement`, ordinary `create`,
`review_artifact`, or `revoke_authorization`; those remain fresh owner actions.
Treat a missing or malformed owner UUID as a hard error. This bounded control
path may resume an already authorized lineage, but it never creates or widens
an authorization envelope.

Use the production `video-commerce-hub` as the publication control plane:

- call `publication_status` to inspect only the owner's bounded authorization
  rows;
- call `authorize_publication` only from a fresh complete owner packet;
- call `publish_authorized` for an `active` exact artifact/review packet and
  let the endpoint perform the private Storage copy, idempotent Stripe
  Product/Price creation, inactive staging, verification, activation, and
  public catalog check;
- call `rollback_publication` only when the packet's approved rollback action
  is `deactivate_listing`.

Do not reproduce those commerce mutations with ad-hoc SQL or direct Stripe
commands during routine runs. If the endpoint is absent or its authorization
row is incomplete, report `blocked_remote_publication` or the exact missing
packet field and keep the queue pending.

Only report `新規レビュー対象なし` after the review queue is empty. Do not
report that the whole improvement loop has no work until the regeneration and
publication queues are also empty. If either later queue has work but no valid
authorization envelope, report that pending artifact/review and the exact
missing or exhausted authorization fields instead of silently treating it as
no target.

## Preserve every successful output

1. Treat the private `video-generations` Storage object as the immutable
   original. Keep the stable storage path in `video_artifacts`; expose only a
   fresh short-lived signed URL.
2. Create exactly one artifact for every succeeded job, including older jobs
   during migration. Do not create an artifact for failed, refunded, queued,
   or incomplete jobs.
3. Record generator, model revision, prompt snapshot, output settings, file
   size, SHA-256 when available, and parent lineage. Never replace this
   provenance with a mutable display URL.
4. Start the artifact as `sale_candidate` but keep rights and privacy at
   `review_required`. “Sale candidate” means preserved for possible product
   work; it is not a public listing.

## Review and improve

1. Let only the artifact owner read it. Perform review writes through the
   authenticated Edge Function and service-role RPC; do not grant browser
   insert/update access to artifact tables.
2. Append a review rather than overwriting an earlier review. Collect four
   1–5 scores, keep/improve/reject, strengths, improvement request, a concrete
   next prompt, notes, rights status, and privacy status.
3. When the decision is `improve`, visibly copy the saved suggested prompt and
   the source settings into the composer. Show which artifact/review is being
   applied and let the user clear it.
4. Review submission alone is not payment authorization. In review-only mode,
   prepare the next generation without charging. In authorized full-loop mode,
   validate and consume the approved budget, then use the normal consent,
   quote, reservation, and idempotency path without requiring a second manual
   button press.
5. Link the new job to both the exact parent artifact and exact applied review
   before waking the GPU worker. If lineage cannot be linked, cancel the queued
   job and restore reserved credits.
6. After every authorized regeneration, wait for a terminal job state and
   append a new review. Continue only while the authorization envelope still
   has remaining iterations and budget and the stopping rules in
   `references/authorized-actions.md` permit another attempt.
7. A reviewed `improve` result remains pending work across scheduled runs. Do
   not require another manual “generate” click when the current envelope
   already authorizes the exact lineage, settings, spend, and iteration.
8. When no recurring authorization ID exists, route the owner to Video
   Studio's bounded authorization form. It must capture expiry, total
   iterations, total credits, and confirmations. Persist the complete envelope
   even when the first reservation is blocked. If the exact review, balance,
   and queue are ready, reserve the first job in the same transaction; if not,
   store `pending_review`, `pending_funding`, or `pending_execution` with exact
   machine-readable reasons and no credit reservation or GPU job. On later
   reviews, reuse the same unexpired envelope for the newest exact unconsumed
   review in the same lineage.
9. A review finding is fixed only when its concrete prompt or setting change
   was applied to a child job and the child artifact was re-reviewed. Copying a
   suggested prompt into the composer or merely reporting the finding does not
   count as remediation.
10. Before registering a fresh envelope, resolve any display title to the exact
    artifact and latest review, then check current balance, active jobs, and
    whether that exact review was already consumed. A consumed review must not
    be replayed and fewer than 300 credits must not create a job. Persist the
    envelope with `review_consumed` / `insufficient_credits` pending reasons,
    classify the operational stages as `blocked_review_consumed` or
    `blocked_insufficient_credits`, retain the requested limits and
    authorization ID in the report, and name the newest eligible lineage review
    or required credit shortfall. They are resumable pending preconditions, not
    an unimplemented workflow.

## Recover failed execution before retrying

A refunded inference failure is unresolved engineering work. Inspect bounded
cloud job and worker diagnostics, implement a scoped fix or missing diagnostic
capture, and validate it in cloud CI. Prepare the concrete change before asking
for any release authority not already supplied by the user. Exhausted generation
authority prevents another GPU job, not read-only diagnosis or scoped code repair.

Do not append an unchanged visual review merely to obtain an unconsumed review
ID for retrying a failed job. Keep the failed job, applied review, refund and
repair PR linked in the cloud issue/PR record. Retry only through the supported
authorized path after the cause or diagnostic gap is addressed and the remaining
attempt budget is revalidated. Never reset consumed attempts after a refund.

Report `review_fix=pending_child_verification` until a successful child has been
visually re-reviewed against the original findings. A changed prompt or passing
code test alone cannot establish that the visual defect was fixed. A published
older artifact also cannot satisfy publication of a different new child.

## Commercialization gates

- Keep the original private and durable even when a review rejects it.
- A rights or privacy block sets both lifecycle and commerce state to blocked.
- Clearing rights and privacy may advance the artifact to productizing, but it
  must remain an inactive candidate until the approved product-preparation flow
  creates and verifies a draft.
- In authorized full-loop mode, product creation and publication are required
  completion steps when the exact artifact, price, currency, territory,
  license, channels, rights/privacy confirmation, and rollback target are all
  included in the unexpired authorization envelope.
- Without that publication packet, stop at an inactive draft or sale candidate
  and request the missing approval. Do not silently treat “publish it” as an
  approval of unspecified pricing or licensing terms.
- When a product draft is eventually linked, prefer the existing private
  digital-product delivery system and preserve the artifact ID in product
  metadata.
- Marketing posts, third-party marketplace uploads, and additional sales
  channels remain out of scope unless they are separately named in the
  authorization envelope.

## Verification

Run checks proportional to each changed layer:

```powershell
flutter analyze lib/ui/features/video_studio test/ui/features/video_studio
flutter test test/ui/features/video_studio
deno test supabase/functions/video-generation-hub/artifact_review_test.ts supabase/functions/video-worker-hub/worker_security_test.ts
deno test supabase/functions/video-commerce-hub/publication_test.ts
deno lint supabase/functions/video-generation-hub supabase/functions/video-worker-hub supabase/functions/video-commerce-hub
python -m unittest test_worker.py
powershell -ExecutionPolicy Bypass -File scripts/test_first_party_video_sql.ps1
```

Run the Python test from `services/video-inference-worker`. The SQL contract
needs Docker. If Docker is unavailable, report that exact limitation and run
`supabase db push --dry-run --include-all`; do not present the dry run as an
executed migration test.

Verify these invariants in code and tests:

- A succeeded job produces exactly one private artifact and capture event.
- Existing succeeded jobs are backfilled.
- Direct browser mutation remains denied and RLS is owner-scoped.
- The original storage path and provenance cannot be changed.
- Reviews append and rights/privacy gates cannot auto-publish.
- An improvement job records both parent artifact and applied review.
- Failed generation still refunds and produces no sellable artifact.
- Authorized credit purchases and regenerations cannot exceed the envelope's
  per-run and lifetime limits, and every mutation has an idempotency record.
- Registering an envelope from Video Studio always returns one idempotent
  authorization ID for a valid complete packet. It returns a first queued job
  only when all reservation preconditions pass; otherwise it persists exact
  pending reasons with zero reservation and zero GPU job. A successful
  `improve` review is rediscovered after page reload until consumed.
- Publication first creates an inactive draft, verifies price and protected
  delivery, then activates only the exact approved artifact and can be rolled
  back without deleting provenance or purchase records.
- `video_publication_authorizations` is owner-readable but browser-immutable;
  it fixes the exact artifact/review, product terms and clearance assertions.
- Stripe Product/Price creation and `/shop` activation are idempotent for one
  authorization ID, and any failed public verification deactivates the listing.

For production rollout, apply schema before APIs that query artifact tables.
Deploy the provenance-reporting worker before the worker Edge Function starts
requiring its digest fields. Then deploy the generation Edge Function and UI.
Apply the publication authorization migration before deploying
`video-commerce-hub`; never deploy the endpoint against a schema without its
lease, staging, finalize and rollback RPCs.
Do not spend credits on a production smoke generation without a valid
authorization envelope. Report the amount charged, credits consumed, artifact
and review lineage, publication identifiers, verification evidence, remaining
budget, and the reason the loop stopped.

The verification commands above apply when their corresponding code layer was
changed. A routine scheduled improvement run should instead verify cloud
records, terminal job state, refunds, protected delivery, and listing state by
bounded API or SQL reads, without cloning files or creating local build output.

## Emit a machine-checkable stage ledger

Every manual or scheduled run that applies this skill must include one compact
ledger line in its final report:

```text
VIDEO_LOOP_RUN status=<complete|pending> review=<result> review_fix=<result> charge=<result> regenerate=<result> rereview=<result> publish=<result>
```

Use `done` for an executed mutation, `no_target` for an evaluated empty queue,
`not_needed` only when credits already cover the authorized regeneration,
`already_verified` only after checking the live listing, and a `blocked_*`
value for a missing authorization, evidence, refund, or remote capability.
`status=complete` is valid only when all six fields are present and none is
`blocked_*`, `pending`, or `not_run`. A pending ledger must name the exact next
cloud action or one-time owner action; the next scheduled run must resume that
lineage rather than starting over.

Codex lifecycle hooks may add this three-queue contract to scheduled turns and
may request one bounded continuation when a run tries to stop after checking
only the review queue. Hooks reinforce the workflow; the authorization
envelope, production quote/reservation path, idempotency records, and commerce
gates remain the authority for paid or public mutations.
