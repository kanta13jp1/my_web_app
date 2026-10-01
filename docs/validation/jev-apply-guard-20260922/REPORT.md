# Validate asynchronous search results at application time

Run [35684249345](https://github.com/kanta13jp1/my_web_app/actions/runs/35684249345), checked experiment source61f5ea5d28b0c3ace48a93f1404289d5937a415d. Four independent CPU jobs, one assisted then one raw episode per lane. Frozen game d224c892c1f16895f24978358717717f96bad657; same compact-v1 input and trained student.

Additional privileged assistance checks30frames of exact-simulator survival both every6frames and when a worker result arrives. The real game is never rewound or replaced. Synchronous safety-check time counts toward wall time and subsequent simulation catch-up. Raw mode does not apply either shield. This is not learned inference and is not enabled in production.

|Lane|Mode|Clear|Final x|Frames|Model accepted|Model not accepted|No response|Shield total (at application)|
|---|---|---|---|---|---|---|---|---|
|cloud_jev|assisted|True|3168.49|1317|16|197|3|6 (6)|
|cloud_jev|raw|False|299.43|196|30|0|3|0 (0)|
|localjev|assisted|True|3168.45|1285|9|85|67|6 (3)|
|localjev|raw|False|32.00|3600|559|0|41|0 (0)|
|lightgbm|assisted|True|3170.30|1253|128|76|0|6 (5)|
|lightgbm|raw|False|295.33|190|32|0|0|0 (0)|
|laya|assisted|True|3169.06|1361|70|61|7|11 (8)|
|laya|raw|False|314.10|244|20|0|21|0 (0)|

Accepted/not-accepted counts are control decisions, not unique model replies. Not-accepted includes worker search changes and application-time safety changes. Shield totals also include periodic changes between worker results, and therefore are not another additive partition of control decisions.

The four assisted episodes clear, but this is one episode each, not a success-rate estimate. Previous compact and periodic-shield failures remain in docs/validation/jev-compact-20260922. Raw runs reuse the server after assisted runs; an aborted final request can still occupy the local backend and delay the next raw request. Hardware/CPU contention and states differ between runs; do not infer a causal speed gain from timing differences.

All videos are action-log replays aligned to elapsed simulation frames, not simultaneous live captures. The user-selected initial video remains a separate artifact.