# Runway Video Improvement

Use this reference only when the user explicitly requests Runway. Runway is an optional improvement stage; it is not a prerequisite for rendering, uploading, publishing, or registering an AI大学 lesson.

## Appropriate use

- Prefer a 2–10 second semantic insert, transition, or animated explanation over regenerating an entire narrated lesson.
- Choose a moment where motion explains a concept better than the verified deterministic scene.
- Start from a representative frame or another rights-cleared input. Do not upload private audio, personal data, or third-party media unless the user explicitly authorizes it and has the necessary rights.
- Preserve the verified baseline video. A generated clip may replace it only after acceptance checks pass.

## Choose the route

Use the Developer API when the funded API account and `RUNWAYML_API_SECRET` are available. Never print, log, commit, or place the secret in a request artifact. Use the logged-in Runway Web interface only when the user explicitly asks for browser-based generation or the API route is unavailable.

Runway Web plan credits and Developer API credits are separate balances. Verify the selected route has access to the requested model before requesting approval. Never upgrade a plan, buy credits, create a key, or silently switch the model or duration.

Official references:

- API overview: <https://docs.dev.runwayml.com/api/>
- Current API pricing: <https://docs.dev.runwayml.com/guides/pricing/>
- Output retrieval and expiry: <https://docs.dev.runwayml.com/assets/outputs/>
- Web credits: <https://help.runwayml.com/hc/en-us/articles/15124877443219-How-do-credits-work>
- Commercial-use guidance: <https://help.runwayml.com/hc/en-us/articles/21668707517587-Can-I-use-the-content-I-made-in-Runway-for-commercial-purposes>

## Paid-generation confirmation gate

Immediately before every generation that can consume credits, show the user:

- Route: Developer API or Runway Web.
- Model and endpoint or mode.
- Exact input asset and a concise prompt summary.
- Duration and aspect ratio.
- Current unit rate from Runway's official pricing page.
- Maximum credits and monetary cost for this call.
- Local destination where all artifacts will be retained.

Require a fresh, explicit approval for those exact settings. A prior approval for a different provider, model, duration, or attempt does not apply. A general instruction to improve a video does not authorize a paid call.

## Preserve the request

Create `$jobDir\assets\runway-test-<NNN>\` and retain:

- The exact input frame or source asset.
- The full prompt and negative constraints.
- Route, model, duration, ratio, and seed when exposed.
- Expected credits and cost shown at approval time.
- API task ID or Web session URL without credentials.
- The downloaded output, actual credits when shown, hashes, and provenance notes.
- Technical verification, contact sheet, acceptance decision, and integration notes.

Add every artifact to the job asset manifest. Runway's generated output URLs are temporary; download an accepted or reviewable result immediately instead of treating the remote URL as the archive.

## Generate safely

For the API route, submit supported HTTPS, data-URI, or Runway-upload inputs and wait or poll for the task result using the official SDK behavior. A client timeout does not prove the server task was cancelled; inspect the task before retrying to avoid duplicate credit consumption. Report failed, cancelled, and timed-out states exactly.

For the Web route, configure the approved model, duration, ratio, input, and prompt. If the action changes to `Upgrade`, `Add credits`, or another entitlement gate, stop. Do not purchase, change plans, or fall back to a different model without a new confirmation. An entitlement-blocked attempt is not a generated clip and must be reported with zero credits consumed when no generation began.

## Prompt for educational motion

- Lock the camera and preserve the existing composition when animating a designed infographic.
- Preserve typography, spelling, colors, and card placement; request no text changes or added elements.
- Animate only semantic elements such as checks, arrows, highlights, signal flow, subtle parallax, blinking, or restrained mouth movement.
- Keep motion smooth and brief. Avoid decorative movement that competes with narration.
- Treat preservation wording as a request, not a guarantee; generated text and layouts still require visual inspection.

## Verify and accept

Before integration:

1. Download the result locally and record its hash.
2. Inspect codec, resolution, frame rate, and duration with `ffprobe`.
3. Decode the full clip without errors.
4. Review beginning, middle, and ending frames in a contact sheet.
5. Reject warped text, invented claims, black frames, unsafe crops, excessive flicker, identity or style drift, or motion that weakens the explanation.
6. Compare the clip with the baseline using a stated learning or production objective. Do not accept it solely because it looks more cinematic.

## Integrate without losing the baseline

- Keep the original verified MP4 and produce a new versioned output.
- Normalize the accepted insert to 1920×1080, 30 fps, and the project's H.264 render contract before compositing.
- Keep the original narration and subtitle timing unless the user explicitly approves generated audio or a timing change.
- Re-render the whole lesson, then repeat the final codec, full-decode, audio-level, duration, subtitle, and contact-sheet checks.
- Never upload the new version without the normal YouTube metadata and explicit upload confirmation gate.

## Report the improvement loop

For every Runway attempt, report:

- What improved relative to the prior baseline and the evidence used.
- What did not improve, regressed, or introduced a tradeoff.
- Model, duration, actual credits or cost, and artifact directory.
- Whether the clip was accepted, rejected, blocked, or skipped.
- The next measurable improvement candidate.

Carry every non-improvement, regression, and tradeoff into the next iteration's improvement targets. If Runway is skipped, record `status: skipped`, the reason, and that the verified baseline remains authoritative, then continue the pipeline.

Runway may permit commercial use between the user and Runway, but this does not establish rights to uploaded inputs, people, brands, source footage, music, or other third-party material. Preserve provenance and perform a separate rights review before reuse or sale.
