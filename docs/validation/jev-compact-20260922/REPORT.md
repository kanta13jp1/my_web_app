# Compact-input follow-up (2026-09-22)

Independent cloud CPU runs; no claim of stable success or Apple Silicon performance. The frozen simulation and trained student are unchanged. Input compaction preserves all 117 terrain cells and player/enemy fields, drops constant world/stage/unused previous-response metadata, and rewrites instructions/options. This changes the prompt as well as its length. Each condition has one episode.

Original comparison: run35679658653. Compact run: [35682765389](https://github.com/kanta13jp1/my_web_app/actions/runs/35682765389), source570141f9ec94bb61763d6df35205fec8cc1afe9a. Additional shield run: [35683169716](https://github.com/kanta13jp1/my_web_app/actions/runs/35683169716), source822ba6e6713ed0f768d33142960220db598f84d0.

The optional shield checks a copy of the current simulator state for death over30frames every6frames, and chooses a surviving alternative. It neither rewinds nor replaces the real game. Its synchronous CPU time is part of elapsed wall time; the next clock catch-up advances the simulation. It is privileged exact-physics assistance, not model inference. It is disabled for raw runs and production. Worker search and jump release remain separately disclosed.

## compact

| Lane | Mode | Clear | Final x | Frames | Accepted / search change / no response | Shield changes | Valid replies | HTTP median ms |
|---|---|---|---|---|---|---|---|---|
|cloud_jev|assisted|True|3168.07|1245|2 / 202 / 1|0|41/42|118.2|
|cloud_jev|raw|False|299.31|178|27 / 0 / 3|0|6/6|106.3|
|localjev|assisted|False|1512.57|627|4 / 49 / 36|0|2/3|5087.0|
|localjev|raw|False|32.00|3600|531 / 0 / 69|0|58/59|926.1|
|lightgbm|assisted|True|3169.42|1224|144 / 60 / 0|0|0/0|n/a|
|lightgbm|raw|False|295.33|190|32 / 0 / 0|0|0/0|n/a|
|laya|assisted|False|2468.13|1068|61 / 53 / 8|0|7/8|1838.0|
|laya|raw|False|314.10|214|20 / 0 / 16|0|2/3|1354.5|

Control ticks reuse responses; accepted counts are not inference counts. A cancelled in-flight request is not a provider failure. Counts are not evidence that a model was necessary for clear.

## shield

| Lane | Mode | Clear | Final x | Frames | Accepted / search change / no response | Shield changes | Valid replies | HTTP median ms |
|---|---|---|---|---|---|---|---|---|
|cloud_jev|assisted|False|1511.38|667|12 / 93 / 4|6|22/23|159.6|
|cloud_jev|raw|False|299.43|202|30 / 0 / 4|0|7/7|167.9|
|localjev|assisted|True|3168.33|1319|14 / 135 / 35|9|4/5|5298.7|
|localjev|raw|False|32.00|3600|545 / 0 / 55|0|58/59|941.6|
|lightgbm|assisted|True|3168.46|1262|149 / 61 / 0|8|0/0|n/a|
|lightgbm|raw|False|295.33|190|32 / 0 / 0|0|0/0|n/a|
|laya|assisted|True|3168.77|1238|68 / 104 / 8|3|22/23|849.2|
|laya|raw|False|314.10|178|20 / 0 / 10|0|4/5|633.0|

Control ticks reuse responses; accepted counts are not inference counts. A cancelled in-flight request is not a provider failure. Counts are not evidence that a model was necessary for clear.

## Interpretation

Compact Laya had zero state truncations across9 valid replies (214–335encodedtokens including122question/options tokens). Assisted median HTTP was1838ms versus3325ms previously, but states and runner contention differed. There is no matched-state estimate of compaction causality. The additional shield rescued one Laya and LocalJev episode, but cloudJev failed. Do not erase these failures or report a success rate from them.

## Publication

The user-requested initial videos remain the run35679658653 replay. New runs must not be substituted or described as the same recording. X publication was not attempted: browser tab attachment timed out then failed to initialize kernel assets.
