# Four-lane comparison — 2026-09-22

Run: https://github.com/kanta13jp1/my_web_app/actions/runs/35679658653
Code: `39d04f3d587d8f34ad8a82061bdec2bef45eb569`
Game source: `d224c892c1f16895f24978358717717f96bad657`

Each lane runs on a separate GitHub-hosted Ubuntu CPU runner, concurrently within one workflow. Setup and actual start times differ. The video aligns elapsed simulation time to zero and replays measured controls; it is not a recording of simultaneous live screens. All games advance at 60Hz during inference/search; no rendering cost during measurement. One episode per condition, same initial world, no claim of a population clear rate.

| Lane | Assisted clear / seconds | Accepted / override / no-response search | Jump release | Raw outcome | Valid API / calls (assisted) | HTTP median ms |
|---|---|---|---|---|---|---|
| cloud_jev | True / 21.18 | 17 / 187 / 6 | 17 | dead, x=306.01 | 42/42 | 187.5 |
| localjev | True / 21.42 | 8 / 104 / 99 | 10 | playing, x=32.00 | 3/6 | 5180.6 |
| lightgbm | True / 21.22 | 138 / 68 / 0 | 10 | dead, x=295.33 | 0/0 | n/a |
| laya | True / 21.22 | 72 / 47 / 20 | 9 | dead, x=314.10 | 5/6 | 3324.9 |

Assistance is privileged exact-simulator beam search (width12/depth8/8frames per branch, replan6frames), prediction of held input during previous solve delay (1..12frames), and one-frame jump release. Prior search-only trials also cleared. Acceptance of a proposal held across several ticks is not a count of unique inferences or proof that the model was necessary. Raw mode has no search or jump release. API lanes are single-inflight, minimum500ms start cadence, maximum60 calls per episode,60second game cap. A valid proposal remains until another response/error; no1500ms TTL.

Laya: official English421M CPU, source573e5b62696ba441230cd6be71d593331b5d23af, weights revision1c5edc17a7acd8701df6fc341c0d179f1c62c982. PyTorch2.6.0+CPU/transformers4.51.3/two threads; one warmup excluded. Five valid assisted responses all chose right_run; four had state truncation to the remaining316-token budget. Median HTTP3324.9ms includes localhost/protocol/token accounting; model-call time is recorded separately and still includes tokenization/output handling. It does not reproduce an Apple M5 Pro/MLX short-input benchmark.

LocalJev is pinned githubnext/localjev with Qwen2.5-0.5B Q4_K_M, not Jev weights. Its raw trial stayed at x32. Errors and uniform responses remain in JSON; assisted clear is largely search control. Cloud latency is from a cloud runner, not a Japanese browser/proxy. LightGBM is the frozen166-Jev-label student, not newly trained on successful search trajectories.

Video uses only the LightGBM lane audio to avoid four overlapping soundtracks. All four terminal states must match their real-run phase/x before the video artifact is accepted. No outcome is fabricated for a failed model.

Video rendering-only run: https://github.com/kanta13jp1/my_web_app/actions/runs/35680117830 . H.264/AAC and WebM artifacts; both assisted and raw videos passed all terminal parity assertions. SHA256 manifests are retained. Additional Jev editorial triage chose keep with confidence0.17; it is not a quality pass or fact verification. Manual comparison against JSON was performed.
