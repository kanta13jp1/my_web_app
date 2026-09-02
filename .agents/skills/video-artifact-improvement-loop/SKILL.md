---
name: video-artifact-improvement-loop
description: Preserve, review, improve, and commercialize first-party GPU video generations with immutable lineage. Supports review-only operation and an explicitly authorized full loop that may purchase credits, regenerate, re-review, and publish an approved product. Use for the site's Video Studio artifact, quality-improvement, commercialization, or recurring-generation workflow.
---

# Video Artifact Improvement Loop

Use this workflow for the site's own GPU video generations. Read
`references/schema.md` before changing tables, Edge Functions, worker
completion, or the Video Studio UI.
Read `references/cloud-execution.md` for manual and scheduled runs so media,
queue state, review evidence, and inference stay in Supabase/GCP rather than
the local PC.

## Choose the operating mode

- Use **review-only mode** when no current authorization envelope exists. It
  preserves and reviews outputs, prepares the next prompt, and reports the
  exact approval needed for chargeable or public actions.
- Use **authorized full-loop mode** when the user has supplied a current,
  machine-checkable authorization envelope. In this mode, do not stop after
  review: purchase the approved credit pack when needed, perform the approved
  regeneration, review the result, and publish the specifically approved
  product when its release gates pass.
- Read `references/authorized-actions.md` before spending money, reserving
  credits, starting a GPU job, creating or activating a product, or configuring
  a recurring run to do any of those things.

An approval is consumed according to its stated scope. Never reinterpret a
one-time approval as permission for later runs, and never infer an hourly or
recurring budget from a single completed purchase.

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
   Scheduled re-review must call `review_authorized_artifact`, never the
   owner-only `review_artifact` action. The bounded action requires one explicit
   owner and authorization ID; its atomic RPC accepts only an unreviewed
   artifact produced by a succeeded job under that exact authorization.
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
7. When a reviewed `improve` artifact has no recurring authorization ID, route
   the owner to Video Studio's bounded authorization form. The form must
   capture expiry, total iterations, total credits, and confirmations, then
   atomically save the envelope and reserve its first job.
8. On a later review in the same lineage, reuse the still-active envelope by
   consuming the exact new artifact/review once. Never ask for a duplicate
   approval while its expiry and remaining limits are valid.

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
deno lint supabase/functions/video-generation-hub supabase/functions/video-worker-hub
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
- Scheduled review rejects already-reviewed artifacts and artifacts outside the
  exact owner authorization.
- An improvement job records both parent artifact and applied review.
- Failed generation still refunds and produces no sellable artifact.
- Authorized credit purchases and regenerations cannot exceed the envelope's
  per-run and lifetime limits, and every mutation has an idempotency record.
- Registering an envelope from Video Studio either returns both an
  authorization ID and first queued job, or rolls back both; a successful
  `improve` review is rediscovered after page reload until consumed.
- Publication first creates an inactive draft, verifies price and protected
  delivery, then activates only the exact approved artifact and can be rolled
  back without deleting provenance or purchase records.

For production rollout, apply schema before APIs that query artifact tables.
Deploy the provenance-reporting worker before the worker Edge Function starts
requiring its digest fields. Then deploy the generation Edge Function and UI.
Do not spend credits on a production smoke generation without a valid
authorization envelope. Report the amount charged, credits consumed, artifact
and review lineage, publication identifiers, verification evidence, remaining
budget, and the reason the loop stopped.
