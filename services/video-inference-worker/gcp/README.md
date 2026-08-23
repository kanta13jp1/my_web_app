# GCP GPU host

`startup.sh` provisions a private, operator-controlled Compute Engine host for
the first-party Wan2.2 worker. It expects:

- a G2 machine with one NVIDIA L4 GPU;
- a persistent disk attached as `video-model-cache`;
- the worker service account with Artifact Registry read and Secret Manager
  access to `video-worker-token`;
- instance metadata for the immutable container image, fixed model revision,
  worker URL, worker ID, and the `video-worker-enabled` switch.

`video-worker-idle-exit-seconds` defaults to 600. When the owned queue remains
empty for that period, the worker exits cleanly and the host wrapper powers off
the VM. Failed workers restart under systemd instead of silently powering off.

`video-auto-stop-minutes` is mandatory and must be between 15 and 1440. The
guest schedules a power-off during startup so a failed test cannot leave the
GPU running indefinitely. Production automation should still start instances
only when work exists and stop them after the queue drains.

The model is downloaded from the fixed Hugging Face revision once and kept on
the dedicated persistent disk. Runtime inference is offline with respect to
model providers. The worker receives only its scoped queue token, never a
Supabase service-role key.

For a new host, keep `video-worker-enabled=false` until the database migration
and `video-worker-hub` Edge Function are deployed and validated. Stop the GPU
VM whenever it is not serving or benchmarking jobs; the budget notification is
an alert, not an automatic shutdown control.
