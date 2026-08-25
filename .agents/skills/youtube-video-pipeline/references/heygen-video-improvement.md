# Optional HeyGen Presenter Improvement

Use HeyGen only when the user chooses it and a short speaking-presenter segment has a clear lesson purpose. It is a candidate, never a mandatory provider and never a reason to block the deterministic pipeline.

## Appropriate use

Prefer a 5–8 second presenter insert at an opening, transition, example, or recap. Keep the existing narration, captions, and lesson-specific diagrams as the primary teaching structure. Do not replace an entire lesson with an avatar unless the user explicitly requests that tradeoff and the all-history review supports it.

Use the deterministic verified MP4 as an immutable baseline. A HeyGen insert must explain or emphasize a lesson point; facial movement alone is not a material improvement.

## Consent and data boundary

- Use only an avatar supplied by HeyGen or an image, video, identity, and voice that the user owns or is authorized to use.
- Never clone or imitate an unrelated identifiable person.
- Tell the user exactly which image, avatar, and audio interval will be sent before upload.
- Do not upload a raw full-length recording when only a short excerpt is required.
- Keep API keys in a secret store or environment variable such as `HEYGEN_API_KEY`; never write them to the repository, job manifest, request archive, logs, or chat.

## Paid-generation gate

Immediately before every paid creation or retry, show and require explicit confirmation of:

- Avatar type and ID or approved source image.
- Engine, normally Avatar IV or Avatar V when supported.
- Exact narration text or audio file and start/end interval.
- Resolution, aspect ratio, expected duration, current official unit price, estimated charge, and a hard maximum cost.
- Whether the API-key wallet or an OAuth-linked web subscription will be charged.
- The intended placement in the baseline video.

Refresh pricing from [HeyGen's official self-service pricing](https://developers.heygen.com/docs/pricing). Do not infer API funds from a web subscription. One approval authorizes one described generation only; retries that can consume funds require another confirmation.

## Generate and preserve

Prefer the explicit `POST /v3/videos` workflow from [HeyGen's Create Video API](https://developers.heygen.com/reference/create-video) over an autonomous prompt-to-video agent. For the existing user narration, upload only the approved excerpt and pass its `audio_asset_id`, or use an expiring controlled `audio_url`. Request 1080p and 16:9 unless the delivery format requires otherwise.

Use MP4 with a controlled background for ordinary inserts. Use transparent WebM only when the selected avatar supports matting and the integration has been tested. Poll `GET /v3/videos/{video_id}` until the API reports completion or failure; a queued request is not a finished asset.

Preserve under `$jobDir\provider-assets\heygen\<attempt-id>`:

- A sanitized request without credentials or long-lived signed URLs.
- Provider job and video IDs, timestamps, engine, avatar type, resolution, duration, and reported status.
- The original approved input excerpt and its hash.
- The downloaded provider MP4 or WebM and thumbnail.
- Actual or best-supported estimated cost and billing source.
- Consent, rights, and provenance notes.
- A technical and visual review plus rejection reason when not accepted.

Add material outputs and provenance records to the main asset catalog. Download provider results promptly because returned URLs may expire.

## Accept and integrate

Inspect facial stability, lip sync, pronunciation, body motion, hand artifacts, background edges, frame cadence, resolution, and audio continuity. Reject an insert that changes the spoken meaning, introduces an operator instruction, looks distracting, or does not survive a full decode.

Integrate the accepted clip into a new versioned candidate without overwriting the deterministic baseline. Preserve the user's original audio unless the confirmed operation intentionally replaces it. Re-render the complete 1920×1080 lesson and repeat codec, audio, subtitle, contact-sheet, full-decode, and all-history validation.

Report separately:

- Confirmed improvement: presenter usefulness, attention, comprehension, or lesson-specific motion supported by evidence.
- Unchanged or unproven items: especially learning outcomes and viewer analytics.
- Regressions and tradeoffs: cost, latency, identity consistency, editability, reproducibility, privacy, visual discontinuity, or pronunciation.
- The next measurable improvement carried into the following video.

If the HeyGen result is rejected or the user asks to skip it, record `status: rejected` or `status: skipped`, preserve useful evidence, consume no further funds, and continue with the verified baseline.
