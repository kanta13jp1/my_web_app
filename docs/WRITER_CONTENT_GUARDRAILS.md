# Writer Content Guardrails

Issue [#1254](https://github.com/kanta13jp1/my_web_app/issues/1254) adds a
privacy-preserving guardrail to the existing Writer `provider.chat` path.

## Runtime behavior

1. The Edge Function scans Writer input before the external request. Detected
   PII, secrets, prompt injection, harmful instructions, or an oversized scan
   are blocked with safe retry guidance.
2. Writer output is scanned before the response is returned. Harmful output is
   blocked; detected PII and secrets are replaced with categorical markers and
   a warning is returned to the client.
3. Writer-native guardrail rejections are recognized and converted to the same
   safe response contract. Provider descriptions and matched text are not
   relayed.
4. Every decision must be written to `ai_guardrail_events`. An audit-write
   failure stops the Writer call or response instead of failing open.

The audit table stores only trace ID, provider/action, stage, decision,
category identifiers, counts, latency, scanned character count, policy
version, and timestamp. It never stores prompts, model output, matched values,
or other raw content. The admin endpoint also omits `user_id`.

## Why the app-level check remains required

Writer documents Guardrails as pre-call, during-call, and post-call checks. Its
current native API Guardrails documentation applies them to external-provider
models, while this app's Writer integration calls a Palmyra model through
Writer's chat endpoint. The app-level deterministic check therefore provides
the enforceable boundary for this lane and also recognizes a native Writer
rejection if tenant behavior changes.

Reference: [Writer Guardrails documentation](https://dev.writer.com/home/guardrails)

## Release checklist

- Apply `20260824024535_create_ai_guardrail_events.sql` through the normal
  migration pipeline; do not run ad-hoc production SQL.
- Keep `WRITER_CONTENT_GUARDRAILS_ENABLED=true` in the Edge Function secrets.
- In Writer AI Studio, have the authorized enterprise administrator review and
  enable the required pre/post Guardrails policy for the deployed model where
  the tenant supports it. Do not place Writer credentials in Flutter or web
  configuration.
- Confirm `ADMIN_EMAIL` or `AUTOMATION_ADMIN_EMAILS` contains only approved
  operators who may open the Guardrails Observability tab.
- Run an authenticated staging smoke test for benign input, an input block, an
  output redaction fixture, a Writer-native block fixture, and a denied
  non-admin Observability request.
- Confirm the audit rows contain metadata only and the UI reports that raw
  content and user IDs are not returned.

## Incident response and rollback

- Use `trace_id`, category, stage, and timestamp to correlate an incident. Do
  not request or paste a user's original prompt into an Issue or chat log.
- A spike in false positives should be handled by a reviewed policy/code change
  and focused regression fixtures.
- Setting `WRITER_CONTENT_GUARDRAILS_ENABLED=false` removes the application
  boundary and is an emergency-only rollback requiring an incident owner. The
  safer rollback is to disable Writer calls while keeping audit collection and
  other AI providers unchanged.
