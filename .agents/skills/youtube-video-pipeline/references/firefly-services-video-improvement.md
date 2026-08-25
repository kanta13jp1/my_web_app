# Optional Adobe Firefly Services Video Improvement

Use Adobe Firefly Services only when the user chooses it and one of its services has a measurable lesson purpose. It is an optional candidate, never a dependency of the deterministic video pipeline and never a reason to block publishing a verified baseline.

## Choose the service by outcome

- **Generate Video API:** create a short lesson-specific explanatory insert when new visual content would clarify the narration. The API supports 16:9 outputs including 1920×1080; verify the currently available model, duration, controls, and account entitlement immediately before use.
- **Dynamic Graphics Render API:** render repeatable branded video variations from an approved After Effects Motion Graphics Template (MOGRT). Prefer this for reusable course title cards, diagrams, localized labels, and commercializable series templates.
- **Reframe API v2:** produce mobile, square, or other derivative aspect ratios while preserving the original master. Reframing alone is not evidence that the 16:9 lesson improved.
- **Text to Avatar API:** add a short approved presenter segment from a stock avatar and selected text or user-owned audio. Facial movement alone is not a material learning improvement.
- **Text to Speech or Translate and Lip Sync APIs:** use only when the user explicitly requests synthetic speech, translation, dubbing, or lip sync. Preserve the user's original narration and meaning unless the approved operation intentionally replaces them.

Keep the verified 1920×1080 MP4 immutable as the authoritative baseline. Select the least expansive service and send only the minimum asset interval required for the chosen improvement.

Official references:

- [Firefly API usage notes](https://developer.adobe.com/firefly-services/docs/firefly-api/getting-started/usage-notes/)
- [Audio/Video API overview](https://developer.adobe.com/audio-video-firefly-services/)
- [Firefly Services credential setup](https://developer.adobe.com/firefly-services/docs/guides/get-started)

## Authentication, entitlement, and secrets

Use an Adobe Developer Console project with the required Firefly Services product assignment and OAuth Server-to-Server credentials. Store the Client ID and Client Secret outside the repository, for example as `FIREFLY_SERVICES_CLIENT_ID` and `FIREFLY_SERVICES_CLIENT_SECRET`. Keep access tokens ephemeral.

Never print, paste into chat, commit, archive, or include secrets and bearer tokens in command output. Check only whether required values exist. Do not infer API entitlement, available credits, or pricing from a Creative Cloud subscription, Firefly web access, or a visible Generate button. Verify the organization, product assignment, quota, billing source, and current contract or account price before a paid call.

## Consent and asset boundary

- Use only text, images, video, audio, voices, avatars, templates, and identities that the user owns, licensed, or is authorized to process.
- Never imitate an unrelated identifiable person or send their biometric or voice material without authorization.
- Before uploading, show the exact local asset, hash, start/end interval, purpose, destination service, and whether a pre-signed URL will expose it temporarily.
- Prefer expiring pre-signed URLs on a provider-supported storage domain and the shortest practical expiry. Do not upload the full raw recording when a short excerpt is sufficient.
- Treat a MOGRT and its fonts, images, video, and audio as separately licensed assets. Preserve template and asset provenance.

## Paid-operation gate

Immediately before each paid generation, render, reframe, avatar, speech, translation, lip-sync operation, or retry, show and require a fresh explicit confirmation containing:

- Exact Adobe service, endpoint family, model or preset when applicable, and account or organization.
- Exact prompt, MOGRT, source asset, narration text or audio interval, and intended insertion point.
- Output count, duration, resolution, aspect ratio, frame rate, and whether provider audio will be retained.
- Current official or account-specific unit price, estimated charge, billing source, remaining entitlement when available, and a hard maximum cost.
- Data sent to Adobe, storage destination, expiry, and expected retained artifacts.

One confirmation authorizes one described operation only. A retry that can consume quota or funds requires another confirmation. If current pricing or entitlement cannot be verified, record `status: blocked_unverified_billing`, invoke nothing, and continue with the deterministic baseline.

## Submit, monitor, and preserve

Treat provider jobs as asynchronous. A request or job ID proves submission, not completion. Poll within the documented rate limit, honor `retry-after`, stop at a bounded timeout, and do not submit duplicate jobs while one is pending or running.

Preserve each attempt under `$jobDir\provider-assets\firefly\<attempt-id>`:

- Sanitized request and response metadata without credentials or long-lived signed URLs.
- Service, endpoint version, model or preset, dimensions, duration, frame rate, seed and controls when returned.
- Provider job ID, timestamps, terminal status, source hashes, and output hashes.
- Original prompt, approved input excerpt, MOGRT and dependent-asset provenance when applicable.
- Downloaded provider output, preview or contact sheet, reported usage, estimated or actual cost, and billing evidence.
- Consent and rights notes, technical review, learning-value review, and rejection reason when not accepted.

Download successful outputs promptly because signed URLs may expire. Add material outputs and provenance records to the main asset catalog for later reuse or commercialization.

## Accept and integrate

Inspect the output for prompt fidelity, meaningful motion, temporal consistency, text artifacts, anatomy or identity defects, lip sync, pronunciation, gesture mismatch, branding, watermarks, frame cadence, compression, and audio continuity. Reject an output that changes the spoken meaning, introduces an operator instruction, weakens readability, or adds only decorative motion.

Integrate an accepted result into a new versioned candidate without overwriting the deterministic baseline. For a generated insert, normally discard provider audio and preserve the user's approved narration. Conform the result to the 1920×1080, 30 fps master, preserve subtitle safe areas, and avoid a visually unrelated full-screen cut when an in-layout content card communicates the concept more consistently.

Re-render and repeat codec, resolution, frame-rate, audio, subtitle, contact-sheet, thumbnail, and full-decode checks. Then rerun the mandatory predecessor-plus-all-history review. Report separately:

- Confirmed improvement supported by visual, technical, or learning evidence.
- Unchanged or unproven outcomes, especially retention and comprehension.
- Regressions and tradeoffs, including cost, latency, reproducibility, editability, privacy exposure, visual discontinuity, and dependence on expiring provider assets.
- The next measurable improvement carried into the following lesson.

If the Firefly result is rejected or the user asks to skip it, record `status: rejected` or `status: skipped`, preserve useful evidence, consume no further entitlement or funds, and continue with the verified baseline.
