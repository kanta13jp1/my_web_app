# caption-transcoder

On-screen **caption burn-in** service for the X-share presenter video
(`supabase/functions/viral-video-ad-generator`, hypothesis H3).

X autoplays video **muted**, so viewers who can't hear the narration scroll past.
Burning captions into the video raises watch-through / dwell time — the dominant
2026 X reach signal. The edge function already builds the SRT + style and calls a
transcoder; a Deno edge function can't run ffmpeg in-process, so this tiny stateless
Cloud Run service does the burn-in.

The burn code in the edge function is **already merged but dormant** behind
`VVAG_BURN_CAPTIONS`. Deploying this service + setting 3 secrets activates it.
Everything fails safe: any transcoder error → the un-captioned mp4 is posted, so
posting is never blocked.

## How it fits together

```
viral-video-ad-generator (Deno EF)
  → POST /burn { videoUrl, srt, forceStyle, resolution, style }   (this service)
  → ffmpeg burns SRT with force_style, returns { url }
  → EF fetches that url ONCE and re-persists it to Supabase Storage
```
Because the EF immediately re-persists the result to Supabase Storage, the URL this
service returns only needs to live for a few seconds — **no GCS / object store
needed**; the file is self-served from `/tmp` and auto-deleted after a short TTL.

## Prerequisites
- `gcloud` CLI authenticated on the Google Cloud project that backs this app.
- Supabase CLI authenticated (project ref `smmkxxavexumewbfaqpy`).

## 1. Deploy to Cloud Run

From this directory (`services/caption-transcoder/`):

```bash
# Pick any strong random string as the shared key:
API_KEY="$(openssl rand -hex 24)"
echo "API_KEY=$API_KEY"   # save this — you set it as a Supabase secret in step 2

gcloud run deploy caption-transcoder \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --max-instances 1 \
  --memory 1Gi \
  --cpu 1 \
  --timeout 300 \
  --set-env-vars "API_KEY=$API_KEY"
```

Notes:
- `--max-instances 1` guarantees the `GET /file/<id>.mp4` fetch hits the same
  instance that produced the file (it holds the burned mp4 in `/tmp`). Low volume
  (a few videos/day) never needs more than one instance.
- `--allow-unauthenticated` exposes the HTTP endpoint publicly; the `API_KEY`
  header check (Bearer or `x-api-key`) is what actually gates `/burn`. If you prefer
  IAM auth instead, drop `--allow-unauthenticated` and give the Supabase function's
  identity `roles/run.invoker` — but the header key is simpler here.
- Scales to zero when idle → ~free at this volume.

Grab the service URL it prints (e.g. `https://caption-transcoder-xxxx.a.run.app`).
`PUBLIC_BASE_URL` is optional — the service auto-derives the self URL from the
request `Host` header, which on Cloud Run is the correct `*.run.app` host.

Smoke-test it:
```bash
curl https://caption-transcoder-xxxx.a.run.app/healthz   # -> ok
```

## 2. Point the edge function at it (Supabase secrets)

```bash
supabase secrets set \
  VVAG_BURN_CAPTIONS=1 \
  VVAG_CAPTION_TRANSCODER_URL="https://caption-transcoder-xxxx.a.run.app/burn" \
  VVAG_CAPTION_TRANSCODER_KEY="$API_KEY" \
  --project-ref smmkxxavexumewbfaqpy
```

`deploy-prod.yml` redeploys the edge functions on the next `main` merge, or run
`supabase functions deploy viral-video-ad-generator --project-ref smmkxxavexumewbfaqpy`
to pick up the new secrets immediately.

Optional tuning secrets (all have safe defaults):
`VVAG_CAPTION_FONT_NAME` (default `Noto Sans CJK JP`), `VVAG_CAPTION_FONT_SIZE`
(22), `VVAG_CAPTION_JA_CPS` (6.5), `VVAG_CAPTION_EN_CPS` (15),
`VVAG_CAPTION_TIMEOUT_MS`.

## 3. Verify

Generate one presenter video from the app (the one-button X share), then check the
edge logs (Supabase → Logs → viral-video-ad-generator):
- `[vvag-caption] burned OK lang=ja url=...` → burn succeeded.
- The stored video filename ends in `-captioned.mp4`.
- If you see `[vvag-caption] burn failed; using un-captioned mp4: ...`, the reason
  is in the log; the post still went out with the plain video.

If Japanese captions render as boxes (tofu), the container is missing the CJK font —
confirm `fonts-noto-cjk` installed in the image and `VVAG_CAPTION_FONT_NAME` is
`Noto Sans CJK JP`.

## Kill switch

```bash
supabase secrets unset VVAG_BURN_CAPTIONS --project-ref smmkxxavexumewbfaqpy
```
(or set it to `0`) → the edge function immediately reverts to plain, un-captioned
video. No redeploy of this service needed.

## Local test (pure helpers, no ffmpeg/network)
```bash
node test.js
```
