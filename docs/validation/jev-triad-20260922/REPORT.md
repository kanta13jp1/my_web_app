# Explicitly assisted controller experiments (2026-09-22)

## Scope and acceptance

User accepts assistance when its contribution is disclosed. This is the independent World 1-1 recreation, not a Nintendo ROM. Game/physics frozen at d224c892c1f16895f24978358717717f96bad657. Every episode starts at x32 with normal terrain, one life, no teleport, rewind, or difficulty reduction.

The assistant is online beam search over cloned exact simulator state (width 12, depth 8, 8 frames/branch), replanned every 6 frames. It has privileged full-map and physics access. Hypothetical clones never replace the real game. Grounded held-jump inputs are released for one frame. It is a strong model-based planner, not a tiny reflex rule or learned policy. Accepting a model proposal means a searched continuation scores within four points of the best; search still evaluates accepted proposals. The action is not proof of unique model contribution.

## Observed results

| Controller | Raw model | Assisted standard start | Model proposal accepted / control decisions | Overrides | Jump releases |
| --- | --- | --- | --- | --- | --- |
| Jev-distilled LightGBM | Prior pilot: death x295.33 | won x3170.20, frame1221 | 137/204 | 67 | 9 |
| Cloud Jev | death x300.63, frame151, 6/6 valid requests | won x3169.34, frame1257, 42/42 valid | 22/210 | 188 | 14 |
| LocalJev + Qwen 0.5B | no progress x32, stop frame300, 10/10 valid | won x3168.38, frame1259, 20/42 valid | 12/210 (includes fallback proposals) | 198 | 9 |
| Search only | not applicable | won x3170.36, frame1257 | not applicable | not applicable | 13 |

LightGBM and search-only each also cleared two enemy-position perturbations (+/-4px, seeds1/2). This tiny, selected diagnostic set is not a population clear-rate estimate. The same existing LightGBM student was used, with no retraining on this successful route; the training pipeline reconstructs its fixed166-label model.

**API simulation pauses while waiting for HTTP and search. These are step-locked diagnostics, NOT real-time clears.** API decisions every30 simulation frames, search every6; repeated applications of an API choice are not additional model calls. LightGBM/search also run as fast as the CPU allows, without rendering. Search median runtime ~69ms (student hybrid) or ~99ms (search only), so this is not a demonstrated 60fps browser controller. Model-only failures remain failures.

The LocalJev configuration uses githubnext/localjev 3f23e36e1a3bff46c7e83e8e3781d3512bc82021, llama.cpp b6000, official Qwen/Qwen2.5-0.5B-Instruct-GGUF Q4_K_M, CPU on GitHub Ubuntu. It is not original Jev weights, the default DiffusionGemma, or the user's Windows PC. Downloaded model SHA256 is stored separately. LocalJev generates JSON probabilities through a language model; calibration equivalence is not established.

LocalJev assisted requests: 22 HTTP502 errors, 19 noop choices and one right choice. 18 of20 valid distributions were uniform, whose tied maximum chooses the first option (noop). Invalid responses become explicit noop fallback before search. The aggregate12 accepted decisions includes such fallbacks; it must not be labelled12 successful model contributions. This lane does not establish useful LocalJev control despite the assisted finish.

An earlier LocalJev run exhausted a shared80-call budget in the stationary raw trial and never started its assisted trial. Follow-up gives each condition its own50-call limit and stops after300frames without >1px forward progress. That revision is a stopping-rule correction, not a model improvement. No retry of failed calls within a trial.

Cloud Jev assisted HTTP median117.8ms on the GitHub runner, raw140.6ms. These include network/readout and are not pure inference or Japan-to-service latency. They must not replace the user's ~1s browser measurements.

## Evidence and revisions

- Initial search/student measurement: code3836044364faea95e1ea9983bd7b40b4676cbd4e, run35676518221.
- Actual cloud API and first LocalJev: code03cacfe5dfb4e07c343d351e2759acb5c18c1bfc, run35676736670.
- LocalJev independent-budget follow-up: codef812b8c18f66599856e9dc948693bcbff71fc75a, run35676955343.
- PR5502 contains executable scripts, validation and this report. Later validation-only changes do not retroactively change the measured revision.
- Temporary encrypted repository API secret was deleted after cloud requests finished; keys are absent from source and artifacts.

Next: live-clock/non-paused control, better LocalJev model/input contract, browser playback and assistance cost, then production integration. This report does not claim the overall project is complete.
