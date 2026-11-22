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

`GET /health` checks only that the controller process responds. It does not
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
check `/health` (200 JSON), unauthenticated `/target-status` (401), and an authenticated
read-only request with secret-safe tooling; confirm the response without
calling `/wake`. Record the deployed revision and retain the prior revision
for rollback. A missing VM remains unavailable until its intended lifecycle
and restoration budget have been confirmed.


## Cloud Run health checks and release procedure

Use public `GET /health` for process liveness: 200 `{ "status": "ok" }`,
`Cache-Control: no-store`, with no metadata/Compute/provider request and no VM
start. It remains healthy when the configured GPU VM is missing. Use the
separately authenticated `/target-status` to diagnose that target; it does not
establish inference readiness.

`/healthz` remains a compatibility alias for existing local clients. Do not use
it for external Cloud Run checks: Cloud Run reserves some paths ending in `z`,
which can return a Google HTML 404 before reaching this application. See
[Cloud Run known issues](https://docs.cloud.google.com/run/docs/known-issues).
An HTML 404 on that path alone is not evidence of a whole-service outage.
The current TCP startup probe need not change for this additive HTTP alias.

1. Run syntax and unit/HTTP contracts in the dedicated cloud CI, then merge the
   reviewed exact head after required PR checks succeed.
2. Build the merged server from the currently deployed image digest, replacing
   only `/app/server.js`. Check its hash, syntax and HTTP contracts in that
   container; retain the previous image and revision for rollback.
3. Create a no-traffic revision, preserving environment/secret references,
   service identity, IAM, ingress, scaling, resources and startup probe.
4. At a temporary tagged URL, verify GET `/health` gives 200 JSON/no-store;
   `/target-status` without/with invalid authentication gives 401; and an
   authenticated GET gives the observed target status (503 is expected for a
   missing VM). Keep credentials in memory, out of URLs and logs. Never POST
   `/wake`, reserve jobs or start/create the GPU as part of this smoke check.
5. Promote that exact revision to 100%, remove the temporary tag and repeat
   the checks at both existing service URLs. Correlate a missing target with
   sanitized `compute_get_404` logs and a separate read-only Compute lookup.
   Record image/revision, config preservation and GPU-operation audit results.
6. If application contracts fail, restore traffic to the prior revision and
   remove the temporary tag. First distinguish an application JSON error from
   a platform HTML error and inspect another application path before declaring
   the entire route unavailable. Do not weaken IAM or restore a VM to make a
   process-liveness test pass.
