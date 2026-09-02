# Foundation priorities and measures

Use this reference only when several improvements compete or the success signal
is unclear.

## Choose in this order

1. Safety and essential access: prevent harm, lockout, data loss, or blocked
   critical user actions.
2. Daily continuity: make the core path complete reliably on ordinary devices,
   connections, and assistive technology.
3. Recovery and clarity: expose failure, preserve user input, provide a safe
   retry or escape, and explain the next action without blame.
4. Efficiency: remove the smallest repeated delay or manual burden on the core
   path.
5. Nonessential expansion: new surfaces, integrations, automation, and polish
   only after higher priorities meet their minimum threshold.

Prefer the candidate with the strongest direct evidence, smallest reversible
change, and clearest user-visible result. Treat severity before frequency when
an infrequent failure can cause material harm.

## Measure proportionally

Pick one primary signal and an explicit baseline. Useful signals include a
focused regression test, core-path completion rate, error rate, recovery rate,
latency at a named percentile, accessibility result, or repeated manual steps
removed. Pair it with a guardrail signal when the improvement could shift harm
elsewhere.

For local-only work, deterministic tests and static checks can be the observed
signal. Do not invent production outcomes. If production observation was not
authorized or available, say so and define what would be measured later.
