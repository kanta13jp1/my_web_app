# Artifact KV Storage Specification (`#4136`)

## 1. Purpose

Provide hierarchical Key-Value persistence contracts and progressive-loading UI
components across:

- `lib/services/artifact_kv_storage_service.dart`
- `lib/widgets/artifact_kv_storage_card.dart`
- `supabase/functions/_shared/artifact_kv_storage.ts`

## 2. Key Grammar, Scopes, and LWW Conflict Resolution

1. **Scopes**:
   - `private`: User-isolated state.
   - `shared`: Workspace/shared state.
2. **Hierarchical Key Grammar**:
   - Enforces `namespace:id` matching `^[a-zA-Z0-9_-]{1,48}:[a-zA-Z0-9_.-]{1,79}$`
     (max 128 chars).
3. **Payload Size Limit**:
   - Default UTF-8 payload limit: `65536` bytes (64 KiB), configurable via
     `maxPayloadBytes`.
4. **Last-Write-Wins (LWW)**:
   - Concurrent writes compare UTC `updatedAt` timestamps; older writes do not
     overwrite newer records.
5. **Progressive Loading UI**:
   - `ArtifactKvStorageCard` uses a non-blocking `LinearProgressIndicator` and
     responsive `Wrap` controls (`minimumSize: Size(64, 48)`).

## 3. Migration & External Reference Notes

- This batch introduces `0` DB migrations and provides the application-layer
  service/UI and Edge Function shared validator ahead of any future table DDL.
- External claims from the originating NotebookLM notebook
  (`Claude Fable 5 System Prompt and Implementation Guide`, `#4136`) were not
  verified against external primary sources and remain `未確認`.
