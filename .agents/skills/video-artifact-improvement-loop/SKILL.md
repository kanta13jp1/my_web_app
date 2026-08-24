---
name: video-artifact-improvement-loop
description: Preserve successful first-party video generations as private, immutable, reusable and sale-candidate artifacts; collect owner review and rights/privacy clearance; and explicitly apply a reviewed prompt to a later paid generation with lineage. Use when changing, operating, testing, or explaining the site's video studio artifact, review, commercialization-readiness, or iterative-generation flow.
---

# Video Artifact Improvement Loop

Use this workflow for the site's own GPU video generations. Read
`references/schema.md` before changing tables, Edge Functions, worker
completion, or the Video Studio UI.

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
4. Never start a chargeable regeneration from review submission alone. Require
   the normal generation button, consent checks, credit quote, reservation,
   and idempotency path.
5. Link the new job to both the exact parent artifact and exact applied review
   before waking the GPU worker. If lineage cannot be linked, cancel the queued
   job and restore reserved credits.

## Commercialization gates

- Keep the original private and durable even when a review rejects it.
- A rights or privacy block sets both lifecycle and commerce state to blocked.
- Clearing rights and privacy may advance the artifact to productizing, but it
  must remain an inactive candidate until a separate product-preparation flow
  creates a draft.
- Do not create a Stripe product, public shop entry, marketing post, upload, or
  sale without fresh, explicit user approval for that external action.
- When a product draft is eventually linked, prefer the existing private
  digital-product delivery system and preserve the artifact ID in product
  metadata.

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
- An improvement job records both parent artifact and applied review.
- Failed generation still refunds and produces no sellable artifact.

For production rollout, apply schema before APIs that query artifact tables.
Deploy the provenance-reporting worker before the worker Edge Function starts
requiring its digest fields. Then deploy the generation Edge Function and UI.
Do not spend credits on a production smoke generation without explicit user
approval.
