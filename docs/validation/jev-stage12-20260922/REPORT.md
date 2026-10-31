# Underground stage 1-2 validation

Actual run https://github.com/kanta13jp1/my_web_app/actions/runs/35688566431, source cc39a8f34e5bc274d9c987aa51ead1bcd5af9b49. Four independent Ubuntu CPU jobs, one assisted then one raw episode per lane. This independently arranged underground stage is not the original game ROM; no moving platforms or warp zones. Game runs at 60 Hz wall time during API and search waits. Video is time-zero-aligned trace replay, not live simultaneous capture.

LightGBM was retrained from the same fixed 166 World 1-1 teacher labels using the frozen World 1-1 feature generator; the game was changed to the tested source only AFTER training. This is transfer to an unseen course, not training on World 1-2. Other model versions and compact-v1 input are unchanged. Cloud API requests <=60 per episode; local backend setup excluded from timing. One episode is not a reliability estimate.

|Lane|Mode|Clear|x|Simulation seconds|Model accepted|Not accepted|No response|Safety changes (application subset)|
|---|---|---|---|---|---|---|---|---|
|cloud_jev|assisted|True|3136.36|21.47|5|115|2|10 (5)|
|cloud_jev|raw|False|299.43|3.37|30|0|4|0 (0)|
|localjev|assisted|True|3138.42|21.73|2|54|36|16 (6)|
|localjev|raw|False|32.00|60.00|551|0|49|0 (0)|
|lightgbm|assisted|True|3137.12|20.60|109|35|0|8 (5)|
|lightgbm|raw|False|290.02|3.37|34|0|0|0 (0)|
|laya|assisted|True|3138.43|23.40|40|39|4|11 (5)|
|laya|raw|False|314.10|4.27|20|0|23|0 (0)|

Assisted mode uses privileged exact-state search, rising-edge jump release and 30-frame survival checks every six frames and when a worker result is applied. These are not learned inference. Model acceptance/control counts are not API-call counts; safety counts overlap other decisions and cannot be added as exclusive partitions. No-model/planner-only ablation was not run, so clears do not establish that the model was necessary.

Raw local runs start after assisted runs; canceled inference can continue in the server. Timing differences are not a controlled cross-hardware speed ranking. Browser production uses its existing controller, without this experimental survival check; its clear rate is unmeasured.
