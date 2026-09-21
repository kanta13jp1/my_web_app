# Jev → LightGBM: frozen-game pilot (2026-09-22)

## Outcome

Local inference is fast, but this pilot does **not** demonstrate a clear. A LightGBM student trained on Jev probabilities agrees with held-out teacher argmax labels on 24/33 states (72.7%). It dies at the first enemy in the canonical recreation. A separately measured jump-button release adapter increases canonical reach from x295.33 to x1494.73, without clearing. No production controller is changed by this experiment.

## Reproducible conditions

- Frozen game: `d224c892c1f16895f24978358717717f96bad657`, independent `feedback-1` recreation, not original NES ROM. No rendering, audio or network in the simulation loop.
- Code/evidence: [run 35640244333](https://github.com/kanta13jp1/my_web_app/actions/runs/35640244333), code head `18e826e0e8021f65d8ddbe1e8a69162429ca9725`.
- 24 synthetic checkpoints × 2 exploration episodes; up to five observations per episode, truncated on death. 214 candidates; 48 exact-feature duplicates removed, prioritizing test then validation. 166 unique states: 106 training / 27 validation / 33 test. Split by checkpoint group, not adjacent frame or episode. This small, synthetic set is not a representative gameplay distribution.
- Exactly 166 live Jev calls, all valid `jev-1.13.0` responses. Full numeric state, prompt, probabilities and split assignments are in `scripts/jev_distillation/teacher.json`. No API key is stored in Git or Actions. API calls are not repeated by CI.
- Teacher prompt explicitly asks for the next 6 frames/100ms with zero network delay, including releasing jump on landing. This differs from the earlier 12-call experiment. Different states and prompt prevent attributing its jump choices to one change alone.
- 145 numeric features: relative enemies/velocity, player motion and input state, power/height, current hazards and a local solid-tile window. Absolute horizontal position is excluded. Student features are derived from the simulator and are not exactly the production telemetry schema.
- Two separate students: seven LightGBM regression ensembles fit Jev probabilities; another seven fit one-hot synthetic rule labels on the same rows. No rule labels are mixed into the Jev student. Rule teacher here is a stateless experimental baseline, not the production ReactionAssist controller.
- LightGBM 4.6.0, NumPy 2.2.6, SciPy 1.15.3. CPU, 2 threads, deterministic seed20260922, 7 leaves, minimum5 rows/leaf, learning rate0.05, at most150 rounds, validation early stopping15. Test rows are not used for fitting or early stopping. No hyperparameter search after inspecting test outcomes.

## Imitation is not gameplay correctness

| Student | Held-out teacher-distribution argmax agreement | Majority-label baseline | Probability MAE |
| --- | ---: | ---: | ---: |
| Jev probabilities | 24/33 = 72.7% | 9/33 = 27.3% | 0.02115 |
| Separate rule labels | 30/33 = 90.9% | 22/33 = 66.7% | 0.04493 |

These models have different teachers; the agreement percentages are not comparable task correctness scores. Jev-student held-out recall: right_jump5/8, right_run_jump7/10, vertical jump1/3, walk2/2, run9/9, noop0/1. No held-out left example exists. Teacher argmax and provider-returned choice can differ on ties; both metrics are saved in training.json. Probability MAE does not establish calibration or safety.

## Closed-loop gameplay

60Hz simulation, choose controls every6 frames, at most7200 frames (120 simulated seconds), one life, no API calls. One canonical start and20 seeds perturbing original enemy positions by ±4px. Perturbation trials are a narrow robustness check, not20 independent canonical courses. Clearing means the engine's `phase === 'won'`.

| Controller | Canonical result / farthest x | Perturbed clears |
| --- | --- | ---: |
| Always right | death / 299.43 | 0/20 |
| Experimental local rule | death / 683.10 | 0/20 |
| Jev student only | death / 295.33 | 0/20 |
| Rule student only | 120s cutoff, blocked at first pipe / 436.00 | 0/20 |
| Jev student + jump-edge release | death / 1494.73 | 0/20 |

The jump-edge variant was added **after inspecting failure traces**. It is a diagnostic ablation on previously seen conditions, not a fresh held-out validation or pure model output. When grounded with jump already held and the model again requests jump, it releases jump for one simulation frame; no enemy/gap rules are added. The model remains frozen. Canonical run used16 releases.

The raw Jev student landed by frame126 with jump still held and continued right_jump through frame186; a new jump edge never occurred. Updating that same model every frame still died at x297.56. The rule student kept right_run with vx0 at the first pipe. Every-frame local rules reached x1944.10 but also died. These observations identify input semantics and coverage problems; they do not prove the teacher policy would clear if perfectly imitated.

## Speed and parity

Python predictions and exported JavaScript tree evaluation matched exactly on all166 stored vectors, both in Node and Chromium. This parity check is numerical implementation validation, not a second accuracy test.

Cloud headless Chromium140.0.7339.16 on x86_64,200 warmup calls,1000 individually timed calls, plus100 batches of100 calls. Jev tree inference averaged **0.025ms per call at the median batch**, p95 of batch averages0.029ms. Rule model:0.005ms /0.008ms. Individual-call medians were0 because of browser timer quantization; this is not zero-cost inference. No feature extraction, rendering, model load or network is included in the browser numbers. They are not a benchmark of the user's PC or directly comparable with reported0.77ms/native LightGBM measurements. `gameplay.json` separately records Node feature+inference timing.

## Re-run

Run the `Jev LightGBM experiment` workflow on this branch/merged source. It materializes the fixed game from Git, checks candidate provenance against teacher.json, fits the two students, validates Python/JS parity, evaluates full-course simulation, and runs the browser microbenchmark. Artifacts contain models, traces and metrics (14-day retention). Numeric summaries and model SHA256 hashes are preserved beside this report; full models are also archived in the user's local experiment record.

## Next bounded experiment

Freeze this pilot as a baseline. Add training-only examples for landing→jump release→next jump, pipe approaches and later-course failure states; obtain fresh Jev labels separately from any human/planner corrections. Keep a newly held-out set of whole rollouts for the next comparison. Preserve raw-model and input-adapter results separately. Do not tune on the current33 test rows and continue calling them unseen, or declare a clear from agreement/latency alone.
