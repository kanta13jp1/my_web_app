# First-party video inference worker

This worker makes the site itself the video-generation provider. It does not
call fal, Replicate, Runway, or another inference API. It runs the pinned
Apache-2.0 Wan2.2 TI2V-5B weights on an operator-controlled NVIDIA GPU and uses
Supabase only for the owned job queue and private output storage.

## Fixed runtime contract

- Model weights: `Wan-AI/Wan2.2-TI2V-5B`
- Weight revision: `921dbaf3f1674a56f47e83fb80a34bac8a8f203e`
- Official inference source: `Wan-Video/Wan2.2`
- Source revision: `42bf4cfaa384bc21833865abc2f9e6c0e67233dc`
- Output: 5 seconds, 720p, 24 fps, MP4, no audio
- Minimum target: NVIDIA GPU with 24 GB VRAM

The container starts with `HF_HUB_OFFLINE=1` and
`TRANSFORMERS_OFFLINE=1`. Download and inspect the model once during
provisioning, then mount it read-only. Runtime generation has no model-network
fallback.

## Provision

```bash
huggingface-cli download Wan-AI/Wan2.2-TI2V-5B \
  --revision 921dbaf3f1674a56f47e83fb80a34bac8a8f203e \
  --local-dir /srv/models/Wan2.2-TI2V-5B

docker build -t omocha-video-worker:wan2.2 .
```

Create a random worker token of at least 32 bytes and register the same value
as the Supabase Function secret `VIDEO_WORKER_TOKEN`. Do not reuse a Supabase
service-role key; the GPU host receives only this scoped worker token.

```bash
docker run --rm --gpus all \
  --env-file /srv/secrets/video-worker.env \
  --mount type=bind,src=/srv/models/Wan2.2-TI2V-5B,dst=/models/Wan2.2-TI2V-5B,readonly \
  omocha-video-worker:wan2.2
```

Required environment variables:

- `VIDEO_WORKER_URL`: deployed `/functions/v1/video-worker-hub` HTTPS URL
- `VIDEO_WORKER_TOKEN_FILE`: preferred path to a mode-0400 file containing the
  dedicated 32-256 character random secret
- `VIDEO_WORKER_TOKEN`: local-development fallback when no token file is set
- `VIDEO_WORKER_ID`: stable identifier such as `gpu-tokyo-01`
- `VIDEO_IDLE_EXIT_SECONDS`: cleanly exit after an empty queue (300-1800;
  default 600), allowing the GCP host wrapper to power off the VM

## Security and operations

- The worker never receives a Supabase service-role key.
- Production mounts the worker token as a read-only file, so its value does not
  appear in the systemd or Docker command line or the container environment.
- Customer prompts are written to a mode-0600 temporary file and are not put in
  the OS process command line.
- Each job has a 30-minute renewable lease. The worker renews it every minute,
  allows up to 60 minutes for one L4 inference, and does not retry a timeout.
- Before VAE decode, the worker releases the DiT and decodes six overlapping
  spatial tiles on the GPU. It blends those tiles in CPU memory so the fixed
  720p contract remains within a single 24 GB L4's VRAM budget.
- An empty queue shuts the worker down after 10 minutes; a clean worker exit
  powers off the GPU host, while the fixed startup auto-stop remains a backstop.
- Output dimensions, duration, frame rate, codec, and size are checked with
  `ffprobe`; files are capped at 50 MB and uploaded only through a job-specific
  signed URL.
- Logs contain job IDs and fixed error codes, not prompts, tokens, or model
  output URLs.

Review the upstream Apache-2.0 license and model card before deployment. The
repository records exact revisions for reproducibility; upgrading either
revision requires a new model key, quality test, and legal review.
