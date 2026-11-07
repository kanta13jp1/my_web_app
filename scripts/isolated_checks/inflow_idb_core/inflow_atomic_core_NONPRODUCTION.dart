import 'dart:convert';

// NONPRODUCTION. Pure model. No browser, Auth, network, or actual data.
// Namespaces are not security boundaries. Session guard is only advisory.
const maxSafeInteger = 9007199254740991;
const fields = <String>{
  'entries', 'rules', 'tombstones', 'gc', 'salaryPrompt',
};

enum DecisionKind { write, conflict, unknown }
enum CompletionKind { committed, conflict, unknown }

class Meta {
  const Meta(this.owner, this.revision, this.fence);
  final String owner;
  final int revision;
  final int fence;
}

class Decision {
  const Decision(this.kind, {this.meta, this.changes = const {}});
  final DecisionKind kind;
  final Meta? meta;
  final Map<String, String> changes;
}

typedef ValidateField = bool Function(String name, String raw);

String metaKey(String owner) => jsonEncode([owner, '@meta']);
String fieldKey(String owner, String field) => jsonEncode([owner, field]);

Meta? decodeMeta(String raw) {
  try {
    final obj = jsonDecode(raw);
    if (obj is! Map || obj['schema'] != 1 || obj['owner'] is! String ||
        obj['owner'].isEmpty || obj['revision'] is! int || obj['fence'] is! int) {
      return null;
    }
    final rev = obj['revision'] as int;
    final fence = obj['fence'] as int;
    if (rev < 0 || rev > maxSafeInteger || fence < 0 || fence > maxSafeInteger) {
      return null;
    }
    final parsed = Meta(obj['owner'] as String, rev, fence);
    // Conservative: reject noncanonical, duplicate, extra or unknown fields.
    // Nothing is overwritten when schema/version cannot be understood.
    if (encodeMeta(parsed) != raw) return null;
    return parsed;
  } catch (_) {
    return null;
  }
}

String encodeMeta(Meta m) => jsonEncode({
  'schema': 1, 'owner': m.owner, 'revision': m.revision, 'fence': m.fence,
});

// Run synchronously inside the same readwrite transaction after meta read.
// legacyAuthorised must not be inferred from absence, current login or owner IDs.
// This prototype accepts only the already-confirmed synthetic state.
Decision decide({
  required String owner,
  required int expectedRevision,
  required int expectedFence,
  required Meta? actual,
  required Map<String, String> changes,
  required bool current,
  required bool isolatedSupported,
  required bool legacyAuthorised,
  required ValidateField validate,
}) {
  if (!isolatedSupported || !legacyAuthorised || !current || owner.isEmpty ||
      owner.trim() != owner || changes.isEmpty || actual == null ||
      expectedRevision < 0 || expectedRevision >= maxSafeInteger ||
      expectedFence < 0 || expectedFence > maxSafeInteger ||
      actual.owner != owner || actual.revision < 0 || actual.revision >= maxSafeInteger ||
      actual.fence > maxSafeInteger || actual.fence < 0) {
    return const Decision(DecisionKind.unknown);
  }
  if (actual.revision != expectedRevision || actual.fence != expectedFence) {
    return const Decision(DecisionKind.conflict);
  }
  for (final change in changes.entries) {
    if (!fields.contains(change.key)) return const Decision(DecisionKind.unknown);
    try {
      if (!validate(change.key, change.value)) {
        return const Decision(DecisionKind.unknown);
      }
    } catch (_) {
      return const Decision(DecisionKind.unknown);
    }
  }
  return Decision(DecisionKind.write,
      meta: Meta(owner, actual.revision + 1, actual.fence),
      changes: Map.unmodifiable(changes));
}

// Do not return success on individual get/put. Only transaction completion can
// decide success, and a session switch after dispatch yields unknown.
CompletionKind onTransactionComplete(DecisionKind decision, bool current) {
  if (!current || decision == DecisionKind.unknown) return CompletionKind.unknown;
  if (decision == DecisionKind.conflict) return CompletionKind.conflict;
  return CompletionKind.committed;
}