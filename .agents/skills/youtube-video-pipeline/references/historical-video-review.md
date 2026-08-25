# Complete Historical Video Review

Run this review for every newly rendered candidate after technical verification and any optional provider insert, but before drafting final YouTube metadata or asking for upload approval. Its purpose is to prove that the improvement loop is cumulative rather than judging the latest video in isolation.

## Non-negotiable scope

Build the comparison population from the authenticated target channel and the pipeline release ledger. Include:

- Every earlier public video on the verified target channel.
- Every known pipeline-created unlisted, private, superseded, replaced, or duplicate release when evidence is still available.
- Deleted or unavailable historical entries as explicit rows when the release ledger or previous inventory proves they existed.

Identify videos by YouTube video ID, not title. Titles may be duplicated or edited. Private test uploads that never became a release may be placed in an operational appendix, but they must not be confused with the viewer-facing quality history.

The report must contain one row for every historical video in scope. Never claim an all-history comparison when an ID is missing, and do not proceed to the upload gate without completing this review.

## Refresh and preserve the inventory

1. Verify the authenticated target channel before collecting history.
2. Refresh the channel upload inventory and merge it with prior accepted inventories and release records.
3. Save `$jobDir\comparison\historical-video-inventory.json` with video ID, title, URL, published date, visibility or availability, duration, evidence sources, cache timestamp, and local-master path when known.
4. Check completeness: every ID in the previous accepted inventory must remain represented or have a documented deletion, privacy, or availability change.
5. Add the inventory and all comparison outputs to the job asset manifest so the next run can reuse them.

Refresh unstable public facts such as visibility, title, thumbnail, and channel ownership. Reuse cached metadata, thumbnails, storyboards, captions, local masters, and prior measurements to avoid downloading or decoding every full video again. Cache reuse improves efficiency; it does not reduce population coverage. Record the cache date and hash for every reused artifact.

## Evidence hierarchy

Use the public YouTube version as the primary viewer-facing evidence. For every historical video, collect at least its metadata, thumbnail, and a whole-video storyboard or contact sheet. Use captions when legitimately available. Use preserved local masters, cue files, render logs, provider outputs, and improvement reports for deeper technical measurements when available.

If an item cannot be measured, write `not measured` and state why. Do not infer audio quality, lip sync, motion, caption accuracy, retention, or accessibility from a thumbnail. If YouTube throttles access, retry only the missing lightweight evidence, use the most recent complete cache, disclose its freshness, and keep every video represented.

Do not republish full third-party transcripts or historical media as comparison artifacts. Store only the internal evidence needed for review and preserve its provenance.

## Apply one consistent rubric

Evaluate the candidate and history with the same definitions:

- Lesson accuracy, coverage, and alignment between narration and visuals.
- Lesson-specific explanatory visuals versus reusable or decorative backgrounds.
- Persistent learning structure: section labels, progress, recap, examples, and takeaways.
- Explanatory motion versus raw motion. A waveform, ambient particles, or camera drift does not count as semantic change unless it advances the explanation.
- Duration, pacing, major visual changes per minute, visual clusters per minute, and longest semantically static interval. When useful, measure a static-frame-pair ratio with a documented threshold.
- Caption readability, timing, granularity, forced or word-level alignment, mobile/TV safe areas, and selectable YouTube captions.
- Presenter usefulness, facial or object motion, phoneme lip sync, and whether HEDRA/FAL/Runway inserts explain rather than distract.
- Audio intelligibility, noise, clipping, integrated loudness, true peak, pauses, music or sound-design balance, and voice consistency. Equal LUFS does not prove equal intelligibility.
- Resolution, frame rate, codec, bitrate, full-decode success, aspect ratio, and thumbnail uniqueness.
- Accessibility, small-screen legibility, reproducibility, rights, provenance, editability, and retained source assets.
- Release hygiene: duplicates, superseded versions, broken links, and AI大学 mapping.
- Viewer outcomes such as click-through rate, retention, comments, and comprehension only when a comparable, sufficiently mature sample exists. Otherwise mark them `unproven`.

Provider use is a tradeoff, not an automatic improvement. HEDRA may improve a talking presenter, FAL or Runway may improve cinematic motion, and ElevenLabs may improve or normalize speech, while deterministic rendering can be more reproducible, editable, and rights-auditable. Record both the gain and the cost, latency, consistency, provenance, and editability impact. Follow the existing paid-call confirmation gates; this review never authorizes spending.

## Comparison protocol

1. Preserve the verified candidate as an immutable baseline.
2. Compare it numerically with the most relevant direct predecessor using only measurements available for both.
3. Compare it individually with every other historical video using the full rubric and available evidence.
4. Summarize series-level evolution by cohort or production generation without replacing the per-video rows.
5. Classify every finding as `improved`, `unchanged`, `unproven`, `regressed`, or `tradeoff` and cite the evidence path or measurement.
6. Select at least one measurable next improvement. Carry every unresolved regression, unchanged weakness, and accepted tradeoff into the next run's backlog.
7. If revision is required, create a new versioned candidate, rerun technical verification, and repeat the entire historical comparison against the unchanged population plus any newly discovered releases.

At minimum, the direct-predecessor table must compare duration, major visual changes per minute, visual clusters per minute, longest or representative static interval, caption approach, audio level and intelligibility evidence, video encoding, and any provider-assisted shots. Never turn missing evidence into a favorable score.

## Acceptance gate

The candidate passes only when:

- At least one material improvement is supported by evidence.
- No critical regression remains.
- Every historical video is represented or its missing evidence is explicitly documented.
- Unchanged items, unproven claims, regressions, and tradeoffs are reported rather than hidden.
- The next measurable improvement is recorded for the following production cycle.

Critical regressions include lesson inaccuracies, operator instructions left in narration, broken or unreadable captions, clipped or unusably quiet audio, failed decode or unsupported delivery format, provenance or rights violations, missing historical population coverage, and loss of the lesson's core learning objective. Revise and rerun when any exists.

A noncritical tradeoff may be accepted only when its benefit and cost are explicit and the item is carried forward. Lack of mature viewer analytics is `unproven`, not an automatic failure or success.

## Required outputs

Store these reusable artifacts under `$jobDir\comparison`:

- `historical-video-inventory.json`
- `historical-comparison-metrics.json`
- `historical-comparison-report.md`
- `comparison-provenance.md`
- `thumbnail-overview.jpg`
- `history-group-*.jpg`

The report must include scope and freshness, an executive verdict, direct-predecessor metrics, confirmed improvements, unchanged and unproven gaps, regressions and tradeoffs, one row per historical video, acceptance status, the next measurable targets, and paths or hashes for supporting evidence. Also update the main improvement report or job manifest with the verdict and backlog.

Show the user the verdict, population count, important improvements, unresolved items, regressions or tradeoffs, and exact artifact paths. Only after that disclosure may the workflow continue to YouTube metadata and the separate upload confirmation gate.
