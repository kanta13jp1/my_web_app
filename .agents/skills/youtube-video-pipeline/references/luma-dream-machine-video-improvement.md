# Optional Luma Dream Machine Video Improvement

Use Luma Dream Machine only when the user chooses it and a short generated or transformed shot has a measurable lesson purpose. It is an optional candidate, never a dependency of the deterministic pipeline and never a reason to block publication of a verified baseline.

## Appropriate use

- Prefer a 5-second image-to-video insert made from an independently designed, rights-cleared lesson frame. This normally preserves series identity better than unconstrained text-to-video.
- Use text-to-video only when a new scene communicates the narration better than an existing designed frame.
- Use video-to-video when preserving source motion materially helps and its higher cost, privacy exposure, and style drift are justified.
- Use reframe for derivative aspect ratios; reframing alone does not prove that the 16:9 master improved.
- Avoid sending typography to the model. Generate motion and background imagery, then composite exact titles, diagrams, captions, and claims in Remotion or the deterministic editor.
- Keep the verified 1920×1080 MP4 immutable. A Luma result becomes a candidate insert only after acceptance checks pass.

For a narrated AI大学 lesson, a short opener, section transition, process visualization, or recap is usually more useful than regenerating the entire lesson. Cinematic motion is not a material improvement when it does not support the spoken concept.

## Current API route

Prefer the current Luma Agents API with Ray 3.2 when the account exposes it. Use the legacy Dream Machine API only when the user explicitly selects that funded route or the current API is unavailable and the user approves the fallback.

- API quickstart: <https://docs.agents.lumalabs.ai/>
- Generation reference: <https://docs.agents.lumalabs.ai/api/resources/generations>
- Current API capabilities and pricing: <https://lumalabs.ai/api>
- Dream Machine subscription and API separation: <https://lumalabs.ai/learning-hub/payments-subscriptions>
- Licensing summary: <https://lumalabs.ai/learning-hub/licensing>

Ray 3.2 currently supports text-to-video and image-to-video at 5 or 10 seconds and resolutions through 1080p. It also exposes video editing and reframing modes with different input, duration, availability, and price constraints. Treat these facts as cached guidance only: refresh the official pages immediately before approval because models, rollout state, prices, HDR multipliers, and limits can change.

## Authentication, billing, and secrets

Use a Luma Agents API key from the funded API project, stored outside the repository as `LUMA_AGENTS_API_KEY` or another user-approved secret name. Never print, paste into chat, commit, archive, or place the key in a request or provenance file. Check only whether the variable exists.

Dream Machine Web/iOS subscription credits and API billing are separate. Do not infer API balance, model access, rate limits, commercial rights, or privacy protections from a visible Dream Machine subscription. Verify the API account, current balance or billing route, requested model access, current official price, and applicable terms before every paid call. Never buy credits, upgrade a plan, or create a key without separate user authorization.

## Paid-generation confirmation gate

Immediately before every generation or retry that can consume funds, show and require fresh explicit confirmation of:

- Route: Luma Agents API or explicitly approved legacy/Web route.
- Model, operation type, endpoint family, SDR/HDR mode, and output count.
- Exact prompt and exact local input asset, hash, and intended insertion point.
- Duration, resolution, aspect ratio, and any start/end keyframes, edit strength, camera controls, or seed exposed by the route.
- Current official unit price, estimated charge, billing source, and a hard maximum cost for the call.
- Data sent to Luma, storage method, local artifact directory, and whether user voice, identity, private media, or third-party material is included.

One confirmation authorizes one described operation only. A retry, resolution change, mode change, duplicate output, or fallback that can consume additional funds requires another confirmation. If price, balance, entitlement, or exact input cannot be verified, record `status: blocked_unverified_billing`, invoke nothing, and continue with the deterministic baseline.

## Asset and privacy boundary

- Upload only user-owned, licensed, generated, or otherwise authorized images and video.
- Do not send the full raw narration, identity, personal data, source document, or third-party footage when a single designed frame is sufficient.
- For image-to-video, prefer the provider Files API or another approved controlled upload rather than a permanent public URL. Record the file ID but never credentials or long-lived signed URLs.
- For video-to-video, send only the approved interval. State whether facial, depth, normal, pose, or motion controls may derive biometric or structural information.
- Commercial use depends on the account and terms active for that generation plus rights to every input. A provider output never establishes rights to uploaded people, brands, music, source footage, or documents.

## Submit, monitor, and preserve

Treat Luma generation as asynchronous. A generation ID proves submission, not completion. Poll the same job within documented limits or use an approved callback. A timeout does not prove cancellation; inspect the existing job before retrying to avoid duplicate charges.

Preserve each attempt under `$jobDir\provider-assets\luma\<attempt-id>`:

- Sanitized request and response metadata without secrets or long-lived signed URLs.
- API route, model, operation, resolution, duration, aspect ratio, SDR/HDR setting, prompt, controls, and seed when returned.
- Input asset, hash, consent and rights note, intended insertion point, and baseline version.
- Generation ID, timestamps, terminal state, reported usage, estimated and actual cost, and billing evidence.
- Downloaded output, thumbnail or contact sheet, hashes, technical verification, learning-value review, and acceptance or rejection reason.

Download completed outputs promptly and add material inputs, outputs, prompts, provenance, and review records to the main creative-asset catalog. Do not treat a provider URL as durable storage.

## Verify, accept, and integrate

Before integration:

1. Inspect codec, resolution, frame rate, duration, and audio with `ffprobe`; fully decode the clip.
2. Review beginning, middle, and end frames plus playback for temporal coherence, flicker, unexpected cuts, malformed text, anatomy or identity drift, watermarks, black frames, and unsafe crops.
3. Check semantic fidelity. Reject invented UI, claims, labels, or motion that contradicts the narration.
4. Compare against the exact deterministic scene using a named learning or production objective. Reject decorative movement that does not improve explanation, attention, or continuity.

Integrate an accepted result into a new versioned candidate without overwriting the baseline or rejected attempts. Normally discard provider audio and retain the user's approved narration. Conform the insert to 1920×1080, 30 fps, the project's H.264/AAC contract, subtitle safe areas, color system, and original timing. Overlay exact text and diagrams deterministically.

Re-render the complete lesson and repeat codec, full-decode, audio-level, subtitle, thumbnail, and contact-sheet checks. Then run the mandatory direct-predecessor and all-history review. Report separately:

- Confirmed improvement and supporting evidence.
- Unchanged or unproven outcomes, especially comprehension, retention, and click-through rate.
- Regressions and tradeoffs, including cost, latency, reproducibility, editability, privacy, visual discontinuity, text instability, and provider dependence.
- The next measurable improvement carried into the following lesson.

If the output is rejected or Luma is skipped, record `status: rejected` or `status: skipped`, preserve useful evidence, consume no further funds, and continue with the verified deterministic baseline.
