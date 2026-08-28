# Optional Topaz Video AI Improvement

Use Topaz Video AI only when the user selects it and a finishing or restoration pass has a measurable quality objective. Topaz is an optional post-production candidate, not a content-generation service and never a dependency of the deterministic pipeline.

## Appropriate use

- Use enhancement or upscaling for low-resolution, compressed, noisy, soft, or AI-generated raster footage when a short preview demonstrates a real gain.
- Use motion deblur, stabilization, or rolling-shutter correction only when the source contains the corresponding defect.
- Use frame interpolation only when a frame-rate conversion or retiming objective justifies synthesized frames. It does not create reliable motion across abrupt scene changes.
- Use SDR-to-HDR only for a separately approved HDR deliverable with compatible review and publishing targets.
- Do not expect Topaz to add lesson-specific scenes, repair weak storytelling, improve narration alignment, or create correct UI and text.
- For editable Remotion, Figma, Canva, vector, or typography-heavy material, prefer a native render at the target resolution. AI upscaling can introduce halos, altered glyph edges, oversharpening, temporal shimmer, or invented detail.

Keep the verified baseline immutable. Start with a representative 5–15 second interval containing fine text, edges, gradients, and motion. Process the full lesson only when the short comparison proves improvement without a critical regression.

## Choose the route

Prefer the locally installed Topaz Video desktop application or its bundled command-line workflow when the machine meets the current requirements and the user's license is authenticated. Launch the GUI and sign in before relying on the CLI; do not infer installation, model availability, authentication, or hardware compatibility.

Use cloud rendering only when the user explicitly selects it after seeing the current credit or monetary cost and the exact media that will be uploaded. A desktop license does not prove cloud entitlement or balance. Treat an enterprise API as a separate contracted route; do not infer API access from a consumer desktop or cloud subscription.

Official references:

- Quick start and capabilities: <https://docs.topazlabs.com/topaz-video/quick-start>
- Current system requirements: <https://docs.topazlabs.com/topaz-video/system-requirements>
- Command-line workflow: <https://docs.topazlabs.com/video-ai/advanced-functions-in-topaz-video-ai/command-line-interface>
- 1080p-to-4K guidance: <https://docs.topazlabs.com/video-ai/how-to-guide/upscale-1080-to-4k>
- Enhancement controls: <https://docs.topazlabs.com/video-ai/filters/enhancement>
- Frame interpolation behavior: <https://docs.topazlabs.com/topaz-video/filters/frame-interpolation>
- Stabilization tradeoffs: <https://docs.topazlabs.com/video-ai/filters/stabilization>

Treat model recommendations, system requirements, cloud availability, prices, credits, and licensing as cached guidance only. Refresh the official pages immediately before installation, paid processing, or a production-quality decision.

## Preflight and approval boundaries

Before any processing:

1. Confirm the exact baseline version, input interval, intended defect, target resolution and frame rate, and acceptance metric.
2. Verify the application path, version, authentication, required model files, available disk space, RAM, GPU, and VRAM against the current official requirements.
3. Record whether the route is local desktop/CLI, Topaz cloud rendering, or an explicitly contracted enterprise API.
4. Preserve the input hash and never overwrite the verified master.

Local licensed processing does not require a cloud-credit confirmation when it adds no external charge or upload, but report the expected compute time and output size. Immediately before cloud rendering or another paid route, require fresh explicit confirmation of:

- Exact input interval and whether it contains voice, identity, private data, or third-party material.
- Selected enhancement model and settings, output resolution, frame rate, codec, and output count.
- Current official charge, billing source, expected credits or monetary cost, and a hard maximum for that attempt.
- Local artifact directory and retention plan.

One confirmation authorizes one described paid operation only. A retry, longer interval, different model, resolution, frame rate, cloud route, or additional output requires another confirmation. If entitlement, price, balance, input rights, or exact settings cannot be verified, record `status: blocked_unverified` and retain the deterministic baseline.

## Protect narration and private media

- For cloud processing, remove the audio track unless audio must be present and the user explicitly authorizes that upload. Reattach the validated narration locally after video enhancement.
- Upload only the approved interval and only material the user owns or is authorized to process.
- Never log, commit, archive, or expose authentication files, tokens, license data, or account details.
- An enhanced output does not establish rights to the input footage, people, brands, music, source documents, or generated-provider assets.

## Conservative model selection

For a 1080p raster source being tested at 4K, begin with the current official high-quality recommendation, then try a conservative fine-tune model only when the preview shows a specific unresolved defect. Do not stack multiple filters merely because they are available.

For already clean 1080p motion graphics:

1. Render the editable source natively at 4K first when possible.
2. Compare that native render with the original 1080p master and one short Topaz candidate.
3. Keep the original frame rate unless interpolation has a named purpose.
4. Avoid stabilization and aggressive denoise or sharpening when the source has no camera shake, noise, or blur.
5. Preserve exact titles, diagrams, captions, brand colors, gradients, and safe areas.

Frame interpolation may not preserve audio. Treat the enhanced video stream and approved narration as separate assets, then remux and revalidate them locally.

## Preserve each attempt

Store every attempt under `$jobDir\provider-assets\topaz\<attempt-id>`:

- Baseline version, exact input interval, hashes, and reason for the test.
- Application version, route, model, filters, parameters, device selection, CLI or export settings, and model-file versions when available.
- Approval record for a cloud or paid attempt, submitted media description, estimated and actual cost, and terminal status.
- Output file, hash, preview or contact sheet, processing duration, technical inspection, comparison result, and acceptance or rejection reason.
- Audio-remux command or edit record when the narration was reattached.

Add material inputs, outputs, settings, provenance, and review artifacts to the creative-asset catalog. A cloud URL is not durable storage; download reviewable outputs promptly.

## Verify and accept

Before integration:

1. Inspect codec, resolution, frame rate, duration, color space, and audio with `ffprobe`; fully decode the output.
2. Compare matched frames at 100% and playback speed, including fine Japanese text, thin lines, gradients, scene cuts, moving cards, and subtitle edges.
3. Reject halos, ringing, waxy smoothing, invented detail, altered glyphs, temporal shimmer, ghosting, warped cuts, color shifts, black frames, unsafe crops, or unwanted frame-rate changes.
4. Confirm the output resolves the named defect. A larger resolution, file size, or higher frame rate alone is not a material improvement.
5. If Topaz removed or changed audio, remux the validated narration and repeat loudness, synchronization, and full-decode checks.

Integrate an accepted result into a new versioned candidate without overwriting the deterministic master or rejected attempts. Re-render or remux the complete lesson, then repeat thumbnail, subtitle, contact-sheet, codec, audio-level, duration, and full-decode checks. Run the mandatory direct-predecessor and all-history review before upload metadata.

Report separately:

- Confirmed improvement and the defect or metric it resolved.
- Unchanged or unproven outcomes, including comprehension, retention, and click-through rate.
- Regressions and tradeoffs: artifacts, text fidelity, motion consistency, color, file size, render time, hardware load, reproducibility, privacy, cost, and dependency on proprietary models.
- Accepted, rejected, skipped, or blocked status and the next measurable improvement target.

If the result is rejected or Topaz is skipped, preserve useful evidence, consume no further credits, and continue with the verified deterministic baseline.
