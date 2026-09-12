# Serialized editor saves: implementation proposal

Parent: draft PR #5398, head 9c69dbd132a2e2a5a25210e7433d3b4da7332be8.
Branch: codex/evernote-save-serialization-20260912.
No production rollout or real-data operation is included.

## Outcome and acceptance

The editor's autosave, manual save, attachment-note creation, pre-restore
snapshot/application and exit flush must not write over each other out of order.
AutoSaveService provides one FIFO lane per editor instance. It invalidates stale
queued automatic requests, preserves a newer modified status when an older
request finishes, and retries only the current generation. Manual/exclusive
errors remain visible to callers without preventing a subsequent operation.

The editor enters this lane before backing up/restoring a native title/body.
It checks the captured draft/account before and after the backup. Dialogs stay
outside the lane. A final exit write captures its data before disposal, runs
after the active request and suppresses later queued UI callbacks. Failed final
writes leave the local recovery draft available.

Acceptance uses synthetic completions and virtual time, not fixed real sleeps:
- Debounce, stale queued work, manual ordering, retry generation and errors.
- Recovery exclusivity, newer-draft state and disposal notification safety.
- A final captured draft completes after a stalled earlier write.
- Restore waits for a stalled save, and aborts if a newer draft is entered.

## Validation and review boundary

The parent head passed [full CI 34674271414](https://github.com/kanta13jp1/my_web_app/actions/runs/34674271414):
3,422 VM tests, 2 Chrome import smoke tests, no analyzer findings, 1,691 Dart
files / 0 format changes, security/configuration checks and a release web build.
Those checks do not prove this new revision. Its scoped and broader cloud runs
must be recorded separately before approval. No local Flutter/Dart, dependency
installation, browser automation, ENEX/media processing, or child worker is
allowed while the resource gate is closed. No local user changes are altered.

This is one-editor sequencing, not transactional restoration. Full restoration
of title/body/tags/attachments, cross-device version checks, native attachment
snapshots, durable idempotency and source-lock enforcement still require the
database and authenticated application gates. Imported Evernote history remains
read-only. Required rendered Design/accessibility and human reviews are pending.

The latest user constraint takes precedence over older per-batch wording:
full migration verification and mandatory reviews must finish before production
rollout, source deletion or cancellation. Fresh identified-batch approval is
additionally required; no successful synthetic run opens that global gate.

## References

- [Dart Future.then](https://api.dart.dev/dart-async/Future/then.html)
- [ChangeNotifier.dispose](https://api.flutter.dev/flutter/foundation/ChangeNotifier/dispose.html)
