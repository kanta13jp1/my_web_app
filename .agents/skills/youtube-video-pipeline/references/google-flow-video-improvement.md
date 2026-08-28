# Optional Google Flow Video Improvement

Use Google Flow only when the user selects it and a short generated or edited shot has a measurable teaching or storytelling objective. Google Flow is an optional creative stage, not a dependency of the deterministic render, YouTube release, or AI大学 registration workflow.

## Appropriate use

- Prefer a short lesson-specific insert that makes an abstract concept visible: a process in motion, a before/after transformation, a character demonstrating an action, or a coherent transition between two ideas.
- Use text-to-video, frames-to-video, ingredients or references, or video-to-video editing only when the selected model currently supports the required input and duration.
- Use Scenebuilder to arrange, trim, preview, and download a small sequence when this materially improves pacing. Keep final narration, captions, mix, and delivery rendering in the local pipeline.
- Do not regenerate a complete narrated lesson merely to add decorative movement. Keep the verified deterministic MP4 immutable and replace only an accepted interval in a new versioned candidate.

## Keep Google Flow and the Veo API separate

Use the signed-in Google Flow Web experience by default. A Google AI plan or Google Flow credit balance does not prove access to the separately billed Veo Developer API, and an API key or Cloud billing account does not prove Google Flow Web plan benefits. If the user asks for API generation, treat it as a separate Veo API route with its own current model, project, pricing, quota, and approval evidence; do not describe that call as Google Flow.

The user must complete account sign-in and any age, region, or terms prompts. Do not ask for or expose passwords, cookies, session tokens, payment details, or API keys. Never upgrade a plan, buy credits, enable automatic generation, or change the billing account without a separate explicit request and confirmation.

Official references:

- Product and current plan overview: <https://labs.google/fx/tools/flow>
- Video creation: <https://support.google.com/flow/answer/16353334>
- Video editing and Scenebuilder: <https://support.google.com/flow/answer/16935718>
- Models and supported features: <https://support.google.com/flow/answer/16352836>
- Current Google Flow credit costs: <https://support.google.com/flow/answer/16526234>
- Getting started, watermarking, safety, and commercial-use pointer: <https://support.google.com/flow/answer/16353333>

Models, durations, output counts, credit rates, free or promotional allocations, regional availability, and plan benefits can change. Refresh the official pages and inspect the signed-in generation settings immediately before every attempt. Treat a social-media screenshot or temporary in-product promotion as discovery evidence only; record its terms and expiry from the signed-in account before relying on it.

## Preflight and paid-generation confirmation

### Non-negotiable Flow Web credit-loss gate

Google Flow Web currently uses a Slate rich-text editor. The text visible in the browser DOM is not proof of the prompt stored in Slate's internal state. A paid request is therefore **manual-entry and manual-submit only**:

- Codex must not use browser automation, Playwright, JavaScript injection, DOM assignment, synthetic keyboard events, `fill`, automated typing, automated paste, clipboard injection, or any equivalent mechanism to enter or replace the paid prompt.
- Codex must not click Generate, press Enter to submit, or otherwise trigger a paid Flow Web request. The user performs the final paste/type and the final click directly.
- Visual inspection of the prompt field, a visible character count, an enabled button, or text read back from the DOM does not satisfy this gate.
- A generic reply such as 「はい」「承認」「再開」「再生成」 does not authorize a retry unless Codex has first presented a new one-attempt packet with the exact prompt hash, settings, maximum credit loss, previous actual loss, and the fact that manual entry and manual submission are required.
- The first submission attempt consumes and invalidates its approval regardless of outcome: success, failure, pending, timeout, unrelated output, wrong prompt, or unknown status. No second click is permitted under the same approval.
- If the user cannot perform the manual entry and click, record `status: blocked_manual_flow_submission_required` and continue with the deterministic baseline. Do not fall back to Flow Web automation.

Before the user submits, save the approved prompt as UTF-8 and record:

- SHA-256, byte count, Unicode character count, line count, and the first and last 32 characters.
- Exact model, mode, duration, ratio, resolution, audio setting, output count, unit cost, maximum total credits, and balance before the attempt.
- A one-attempt approval identifier and `attempt_submitted: false`.

After the user clicks Generate, immediately change the local record to `attempt_submitted: true` and `approval_reusable: false`. Do this before waiting for an output. Never interpret a UI timeout, browser disconnect, blank tile, or missing result as permission to click again.

After completion, compare the prompt shown in Flow project history with the approved prompt file. Record an exact match, a mismatch, or `not verifiable`; do not claim an exact match from the editor's pre-submit DOM. A mismatch or unrelated result is rejected, preserved, and sets `flow_web_automation_locked: true`. A new attempt requires a new approval and remains manual-only.

### 2026-08-29 incident retained as a permanent regression case

In the Claude Code 101 job, automated entry interacted incorrectly with Flow's Slate editor:

1. The first synthetic input stored only the prefix `Da` in Slate's internal state.
2. A later automated paste made the full prompt appear on screen, but did not replace the internal value.
3. The pre-submit check inspected the visible DOM and enabled button, so it falsely passed.
4. Flow submitted `Da` and generated unrelated content.
5. A second automated retry was attempted before the editor failure mode was eliminated, producing another unrelated result.

The two rejected attempts consumed 20 credits. The failure was caused by treating visible editor text as authoritative and by permitting a second paid attempt without a proven fix. This exact regression is prevented by the manual-only gate above. Preserve this incident in future revisions; do not weaken the gate merely because a later automated paste appears to work.

Before a credit-consuming action:

1. Identify the exact baseline version and interval to improve, the learning objective, and the acceptance metric.
2. Confirm the signed-in Google account, region availability, plan, remaining credits, refresh or promotion expiry, selected model, supported mode, duration, aspect ratio, resolution, audio option, and output count.
3. Check the current per-generation credit cost. A request can create multiple generations, so calculate the maximum as `cost per generation × output count`.
4. Confirm the exact uploaded or referenced assets and whether they contain a face, voice, personal data, confidential information, third-party media, trademarks, or copyrighted source material.
5. Set the local artifact directory and preserve the deterministic baseline hash.

Immediately before the user manually selects Generate, show the route, model, mode, full prompt-file hash and boundary text, exact input assets, duration, aspect ratio, output count, current unit cost, maximum total credits or money, balance before the attempt, watermark setting, artifact destination, and previous failed-attempt loss for the job. Require fresh explicit approval for those exact settings. One approval authorizes one described generation request and one manual click only; a retry, changed prompt, model, duration, output count, edit, extension, or additional generation requires another confirmation.

If the current interface shows a different cost, unsupported feature, upgrade requirement, insufficient credits, or an unavailable regional feature, stop and report `status: blocked_unverified`. Do not silently choose another model or purchase credits. In regions where Google does not currently permit AI-credit top-ups, do not present a top-up as an available recovery path.

## Generate and preserve safely

- Keep confirmation-before-generating enabled when Google Flow exposes that control.
- The user manually submits only the approved prompt and assets. Codex must not operate the Slate prompt editor or paid Generate control. Do not upload the complete lesson when a short rights-cleared interval or reference frame is sufficient.
- If a generation fails, becomes pending, produces unrelated content, or the browser loses connection, inspect the project history and credit activity, invalidate the approval, and stop. A client-side timeout does not prove that no generation occurred. Any retry requires a new exact one-attempt confirmation and remains manual-only.
- Download every reviewable output promptly. Do not treat the Google Flow project, asset URL, or browser session as the durable archive.

Store each attempt under `$jobDir\provider-assets\google-flow\<attempt-id>` and retain:

- Input assets, hashes, rights or consent note, baseline interval, and stated objective.
- Full prompt, negative constraints, model, mode, duration, ratio, resolution, audio and watermark settings, output count, and seed when exposed.
- Approval record, plan or promotion evidence, estimated maximum, actual credits shown in activity, and terminal status.
- Google Flow project or asset identifier without credentials, downloaded outputs, hashes, screenshots, contact sheet, and provenance notes.
- Technical verification, comparison result, acceptance decision, and local integration record.

All Google Flow outputs include invisible SynthID according to Google's current help. Record whether a visible watermark was enabled or applied automatically. Neither a missing visible watermark nor Google's statement that it does not claim ownership proves rights to uploaded people, brands, music, documents, footage, or other third-party inputs; perform a separate rights review before reuse or sale.

## Verify, integrate, and report

Before integration:

1. Inspect codec, resolution, frame rate, duration, audio, and color properties with `ffprobe`, then fully decode the clip.
2. Review matched beginning, middle, and ending frames and watch the clip at normal speed with narration context.
3. Reject warped or invented text, wrong UI, unsupported claims, identity drift, unsafe crops, flicker, broken physics, bad lip sync, distracting generated audio, black frames, or motion that weakens the explanation.
4. Compare against the deterministic baseline using the named learning objective. Cinematic appearance alone is not a material improvement.
5. Normalize an accepted insert to the project's 1920×1080, 30 fps delivery contract. Preserve the validated narration unless the user separately approved generated audio.
6. Produce a new versioned full lesson, then repeat codec, full-decode, loudness, synchronization, subtitle, thumbnail, and contact-sheet checks and the mandatory all-history review.

Report the confirmed improvement, unchanged or unproven outcomes, regressions and tradeoffs, model and actual credit use, artifact directory, and accepted, rejected, skipped, or blocked status. Carry every regression or unresolved tradeoff into the next measurable improvement target. If Google Flow is skipped or rejected, retain useful evidence, consume no further credits, and continue with the verified deterministic baseline.
