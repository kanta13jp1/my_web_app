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
