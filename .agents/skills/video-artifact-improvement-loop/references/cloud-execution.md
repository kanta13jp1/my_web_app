# Cloud-first execution

Use this reference for every manual or scheduled video improvement run. The
local Codex task is the control plane; Supabase and GCP hold the data and
perform durable or resource-intensive work.

## Placement of work

| Work | Preferred location | Local handling |
| --- | --- | --- |
| Queue selection, authorization, leases, lineage | Supabase Postgres/RPC | Small JSON rows only |
| Original and product media | Private Supabase Storage | Never download or copy locally |
| Generation, model cache, probing, digest, transcode | GCP worker/container | Never run local inference or FFmpeg |
| Reviews and commerce state | Authenticated Edge Function/service-role RPC | Submit bounded structured fields |
| Visual inspection | Cloud evidence first; otherwise one signed stream | One artifact at a time; no saved media |
| Product delivery | Existing private cloud delivery | Verify metadata and access controls remotely |

Do not introduce another provider or upload originals to a third party merely
to avoid local work. Existing GCP and Supabase remain the approved data plane.

## Bounded scheduled run

1. Query each of the review, regeneration, and publication queues in the
   database. Select only the oldest or highest-priority eligible row per queue,
   and request only the columns needed for the decision.
2. Atomically lease the exact artifact/review before a paid or mutating step.
   Keep IDs and idempotency state in the database rather than a local file.
3. Reuse cloud-stored prompt snapshots, settings, checksums, thumbnails, and
   review evidence. Do not enumerate or hydrate an entire Storage bucket.
4. Invoke existing authenticated Edge Functions and the GCP worker for allowed
   mutations. Poll with bounded metadata requests until a terminal state; do
   not keep a local worker, Docker daemon, or browser tab alive while waiting.
5. Append the review and audit state remotely. Return a compact report with IDs,
   scores, spend, credits, result, remaining authorization, and stop reason.

Process at most one lineage mutation at a time unless the authorization
envelope and remote lease design explicitly allow more. Concurrency must be
enforced in cloud state, not by local lock files.

## Media inspection and evidence

- Prefer cloud-produced metadata and bounded review evidence already attached
  to the artifact. Evidence may include duration, dimensions, frame rate,
  checksum, safety flags, and a small private contact sheet or keyframes.
- A contact sheet or keyframes must be derived in the cloud and stored in a
  private bucket with lineage. Do not extract them on the local PC.
- When visual inspection still requires the original, create a short-lived
  signed URL and stream one artifact. Do not download or cache the video.
- Never place signed URLs, service-role keys, worker tokens, or payment data in
  prompts, hook output, logs, screenshots, or local run-state files.

If cloud evidence is insufficient for a trustworthy four-score review, release
or expire the lease and report that a remote evidence endpoint is required. Do
not invent a score from metadata alone.

## Local resource guardrails

- Do not start Docker Desktop, a local Supabase stack, an emulator, Flutter web
  build, or full test suite during a normal scheduled run.
- Do not create persistent media or run-state files under the repository,
  Downloads, Temp, or the Codex task directory.
- Use server-side filtering, aggregation, pagination, and limits. Avoid broad
  Storage listings and unbounded database result sets.

Code implementation and release work is a separate mode. When source changes
are explicitly requested, use a scoped worktree and layer-specific tests;
preserve all unrelated user files.
