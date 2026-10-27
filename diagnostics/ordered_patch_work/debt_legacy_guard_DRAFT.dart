// NON-SHIPPING: no UI/auth/persistent storage implementation. A token is a
// snapshot shown to the user, not permission to transmit legacy information.
import 'debt_workspace_controller_DRAFT.dart';

class LegacyConfirmationDraft {
  const LegacyConfirmationDraft({required this.destination,
    required this.fence, required this.legacyDigest,
    required this.destinationVersion, required this.operationId});
  final DebtWorkspace destination;
  final int fence;
  final String legacyDigest;
  final int destinationVersion;
  final String operationId;
}

enum LegacyCopyOutcomeDraft { copied, changed, unavailable, unknown, duplicate }

abstract class LegacyCopyBackendDraft {
  // MUST in ONE durable transaction check active auth owner/fence, immutable
  // original digest + destination revision and unused operationId; then copy
  // and durably record operationId. No server send and no legacy deletion.
  // The current SharedPreferences/IndexedDB split cannot implement this safely
  // without a separately verified migration protocol. Contract is not proof.
  Future<LegacyCopyOutcomeDraft> applyIfCurrent(LegacyConfirmationDraft token);
}

class LegacyGuardDraft {
  LegacyGuardDraft(this.backend);
  final LegacyCopyBackendDraft backend;
  final _seen = <String>{};
  Future<LegacyCopyOutcomeDraft> confirm(LegacyConfirmationDraft token) async {
    if (token.destination.kind != WorkspaceKind.account ||
        token.operationId.isEmpty || token.legacyDigest.isEmpty) {
      return LegacyCopyOutcomeDraft.unavailable;
    }
    // In-process guard only. Restart requires persistent dedup in backend.
    if (!_seen.add(token.operationId)) return LegacyCopyOutcomeDraft.duplicate;
    try {
      return await backend.applyIfCurrent(token);
    } catch (_) {
      // Do not retry automatically: backend may have committed before failure.
      return LegacyCopyOutcomeDraft.unknown;
    }
  }
}