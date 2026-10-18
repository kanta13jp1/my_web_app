# Video worker wake controller

This small Cloud Run service starts only the owned Compute Engine instance used
by the first-party video worker. The Supabase `video-generation-hub` calls it
after atomically reserving a job. It never generates video and does not forward
requests to a model provider.

Security contract:

- `POST /wake` requires the exact 32-256 character
  `VIDEO_WORKER_WAKE_TOKEN` bearer secret.
- The request accepts only a UUID job identifier; project, zone, and instance
  are fixed server environment variables.
- The Cloud Run service account needs only `compute.instances.get` and
  `compute.instances.start` on the configured project. Create a custom role
  instead of granting broad Compute Admin access.
- The GPU worker receives a different `VIDEO_WORKER_TOKEN`; never reuse either
  token or a Supabase service-role key.

Required environment:

- `GCP_PROJECT_ID=mighty-link-ai-connect`
- `GCP_VIDEO_WORKER_ZONE=asia-northeast1-c`
- `GCP_VIDEO_WORKER_INSTANCE=video-gpu-tokyo-01`
- `VIDEO_WORKER_WAKE_TOKEN` from Secret Manager

Build and deploy only after the database and Edge Functions are ready. Cloud
Run must allow the Supabase Edge Function to reach `/wake`; application-level
bearer authentication remains mandatory. Configure minimum instances as zero
and maximum instances as two. After deployment, set the same URL and token as
`VIDEO_WORKER_WAKE_URL` and `VIDEO_WORKER_WAKE_TOKEN` in Supabase Function
secrets.


## Read-only target diagnosis

`GET /healthz` checks only that the controller process responds. It does not
check the configured VM or the inference worker.

`GET /target-status` requires the same bearer secret as `/wake`. It performs
only a Compute instance GET (and, when needed, a metadata token GET); it never
starts a VM, reserves a job, or calls an inference provider. Send the token in
the Authorization header, never in the URL or recorded command output.

- 200 `{ "target": "present", "state": "TERMINATED" }` means the configured
  target exists but is stopped. RUNNING, STAGING and PROVISIONING are also
  returned as observed states.
- 401 means controller authentication failed, before any cloud request.
- 503 `{ "error": "worker_target_unavailable" }` covers a missing target,
  Compute permission/network failures, and unsupported/transitioning states.
  Provider details and target identifiers are not returned.
- Responses use `Cache-Control: no-store`.

A 200 response does not establish inference readiness, available GPU capacity,
start permission, worker-token agreement, or end-to-end job success. Diagnose
those separately under the appropriate operational authorization. Do not use
this endpoint as a platform startup/liveness probe: it would tie process health
to external VM state and perform unnecessary cloud reads.

The endpoint reuses existing `compute.instances.get` permission and requires
no additional IAM role or secret. Before a separately approved controller
rollout, run `node --test server.test.js http.test.js` in cloud CI. After rollout,
check `/healthz`, unauthenticated `/target-status` (401), and an authenticated
read-only request with secret-safe tooling; confirm the response without
calling `/wake`. Record the deployed revision and retain the prior revision
for rollback. A missing VM remains unavailable until its intended lifecycle
and restoration budget have been confirmed.
