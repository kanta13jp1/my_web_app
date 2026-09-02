---
name: life-foundations-improvement-loop
description: Incrementally improve an existing service by stabilizing its smallest safety, reliability, accessibility, or daily-use foundation before adding nonessential expansion.
---

# Life Foundations Improvement Loop

Use the ordering **stabilize -> sustain today -> advance one step**. Preserve the
user's objective, but defer optional ambition, surface-area growth, and polish
when a more basic gap prevents safe, reliable daily use.

## Loop

1. Inspect current behavior, repository guidance, tests, production evidence
   already in scope, and uncommitted changes. Do not assume a gap from copy or
   plans alone.
2. Read [references/foundation-priorities.md](references/foundation-priorities.md)
   when choosing among multiple gaps or defining a measurement.
3. Choose one smallest foundation gap whose repair produces an observable user
   benefit. State the evidence, baseline, intended signal, and allowed scope.
4. Implement the narrowest reversible change. Preserve unrelated work and
   existing safety paths.
5. Verify with the closest deterministic checks, then observe the chosen signal
   using only data and systems already authorized for the task.
6. Record the result and remaining risk. Repeat only if the first change is
   verified and another in-scope foundation gap is clearly supported.

## Boundaries and stop conditions

- Never block or degrade essential access, safety, medical help, authentication
  recovery, data recovery, payments already owed, or necessary communication.
- Do not infer permission to deploy, contact users, alter production data,
  purchase services, change schemas, or broaden product scope. Ask immediately
  before an action needs authority not already granted.
- Stop when the intended signal improves and acceptance criteria pass; when the
  next step is optional expansion; when a deterministic check fails for an
  unclear reason; or when evidence is insufficient, risk increases, or the
  smallest fix crosses an authorization boundary.
- Never call an interrupted, skipped, or observationally ambiguous check a
  pass. Report the exact result and a safe recovery step.
