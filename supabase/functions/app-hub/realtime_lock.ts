export const REALTIME_LOCK_SOURCE = "realtime_locked_doc";

const MAX_TITLE_LEN = 120;
const MAX_CONTENT_LEN = 40_000;
const MAX_ACTOR_LEN = 64;

export class RealtimeLockError extends Error {
  status: number;
  payload: Record<string, unknown>;

  constructor(
    message: string,
    status = 400,
    payload: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "RealtimeLockError";
    this.status = status;
    this.payload = payload;
  }
}

export interface HubDataRow {
  id: string;
  metadata: Record<string, unknown> | null;
  created_at?: string;
}

type DbError = {
  code?: string;
  message?: string;
};

type DbResult<T> = {
  data: T | null;
  error?: DbError | null;
};

export type HubQuery<T = unknown> = PromiseLike<DbResult<T>> & {
  select(columns: string): HubQuery<T>;
  insert(values: Record<string, unknown>): HubQuery<T>;
  update(values: Record<string, unknown>): HubQuery<T>;
  eq(column: string, value: unknown): HubQuery<T>;
  filter(column: string, operator: string, value: unknown): HubQuery<T>;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): HubQuery<T>;
  limit(count: number): HubQuery<T>;
  single(): PromiseLike<DbResult<T>>;
  maybeSingle(): PromiseLike<DbResult<T | null>>;
};

export interface RealtimeLockDb {
  from(table: string): unknown;
}

export type RealtimeBroadcastNotifier = (
  recordId: string,
  payload: Record<string, unknown>,
) => Promise<void>;

function asHubTable(admin: RealtimeLockDb): HubQuery<unknown> {
  return admin.from("hub_data") as HubQuery<unknown>;
}

function parseRevision(raw: unknown): number {
  const num = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isInteger(num) || num < 1) {
    throw new RealtimeLockError(
      "expected_revision must be a positive integer",
      400,
    );
  }
  return num;
}

function sanitizeText(raw: unknown, maxLen: number): string {
  return String(raw ?? "").slice(0, maxLen);
}

function formatRecord(row: HubDataRow): Record<string, unknown> {
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  const revRaw = Number(meta.revision ?? 1);
  return {
    id: row.id,
    title: String(meta.title ?? ""),
    content: String(meta.content ?? ""),
    revision: Number.isInteger(revRaw) && revRaw >= 1 ? revRaw : 1,
    updated_by: String(meta.updated_by ?? "user"),
    updated_at: String(meta.updated_at ?? row.created_at ?? ""),
    source_actor: String(meta.source_actor ?? "user"),
    created_at: row.created_at ?? "",
  };
}

async function fetchOwnedRow(
  admin: RealtimeLockDb,
  recordId: string,
  userId: string,
): Promise<HubDataRow | null> {
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("id", recordId)
    .eq("source", REALTIME_LOCK_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (error) {
    throw new RealtimeLockError(
      error.message ?? "Failed to read target record",
      500,
    );
  }
  return data as HubDataRow | null;
}

async function emitBroadcastNotice(
  notifier: RealtimeBroadcastNotifier | undefined,
  record: Record<string, unknown>,
): Promise<void> {
  if (!notifier) return;
  try {
    await notifier(String(record.id ?? ""), {
      record_id: record.id,
      new_revision: record.revision,
      updated_by: record.updated_by,
      updated_at: record.updated_at,
      source_actor: record.source_actor,
      record,
    });
  } catch {
    // Non-blocking notice: DB optimistic lock state remains authoritative.
  }
}

export async function handleRealtimeLockAction({
  action,
  admin,
  body,
  userId,
  notifier,
}: {
  action: string;
  admin: RealtimeLockDb;
  body: Record<string, unknown>;
  userId: string;
  notifier?: RealtimeBroadcastNotifier;
}): Promise<Record<string, unknown>> {
  switch (action) {
    case "realtime_lock.list": {
      const { data, error } = await asHubTable(admin)
        .select("id, metadata, created_at")
        .eq("source", REALTIME_LOCK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) {
        throw new RealtimeLockError(
          error.message ?? "Failed to load realtime_locked_doc",
          500,
        );
      }
      const rows = (data ?? []) as HubDataRow[];
      return { records: rows.map(formatRecord) };
    }

    case "realtime_lock.create": {
      const title = sanitizeText(body.title, MAX_TITLE_LEN).trim();
      if (!title) {
        throw new RealtimeLockError("title is required", 400);
      }
      const content = sanitizeText(body.content ?? "", MAX_CONTENT_LEN);
      const actor = sanitizeText(
        body.updated_by ?? "editor",
        MAX_ACTOR_LEN,
      ).trim() || "editor";
      const nowIso = new Date().toISOString();
      const { data, error } = await asHubTable(admin)
        .insert({
          source: REALTIME_LOCK_SOURCE,
          metadata: {
            user_id: userId,
            title,
            content,
            revision: 1,
            updated_by: actor,
            updated_at: nowIso,
            source_actor: "user",
          },
        })
        .select("id, metadata, created_at")
        .single();
      if (error) {
        throw new RealtimeLockError(
          error.message ?? "Failed to create record",
          500,
        );
      }
      return { record: formatRecord(data as HubDataRow) };
    }

    case "realtime_lock.save":
    case "realtime_lock.simulate_batch_update": {
      const isBatch = action === "realtime_lock.simulate_batch_update";
      const recordId = String(body.record_id ?? "").trim();
      if (!recordId) {
        throw new RealtimeLockError("record_id is required", 400);
      }

      const currentRow = await fetchOwnedRow(admin, recordId, userId);
      if (!currentRow) {
        throw new RealtimeLockError("Target record not found", 404);
      }
      const currentFormatted = formatRecord(currentRow);
      const currentMeta = (currentRow.metadata ?? {}) as Record<
        string,
        unknown
      >;

      const expectedRevision = isBatch && body.expected_revision === undefined
        ? Number(currentFormatted.revision)
        : parseRevision(body.expected_revision);
      const expectedUpdatedAt = String(
        body.expected_updated_at ?? "",
      ).trim();

      const nextTitle = isBatch
        ? String(currentFormatted.title)
        : sanitizeText(
            body.title ?? currentFormatted.title,
            MAX_TITLE_LEN,
          ).trim() || String(currentFormatted.title);
      const nextContent = isBatch
        ? `${String(currentFormatted.content)}\n[batch-sync ${
            new Date().toISOString()
          }]`.slice(0, MAX_CONTENT_LEN)
        : sanitizeText(
            body.content ?? currentFormatted.content,
            MAX_CONTENT_LEN,
          );
      const nextActor = isBatch
        ? sanitizeText(body.actor ?? "batch-job", MAX_ACTOR_LEN).trim() ||
          "batch-job"
        : sanitizeText(body.updated_by ?? "editor", MAX_ACTOR_LEN).trim() ||
          "editor";
      const nextRevision = expectedRevision + 1;
      const nowIso = new Date().toISOString();

      let query = asHubTable(admin)
        .update({
          metadata: {
            ...currentMeta,
            user_id: userId,
            title: nextTitle,
            content: nextContent,
            revision: nextRevision,
            updated_by: nextActor,
            updated_at: nowIso,
            source_actor: isBatch ? "batch" : "user",
          },
        })
        .eq("id", recordId)
        .eq("source", REALTIME_LOCK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .filter("metadata->>revision", "eq", String(expectedRevision));

      if (expectedUpdatedAt) {
        query = query.filter("metadata->>updated_at", "eq", expectedUpdatedAt);
      }

      const { data: updatedRow, error: updateError } = await query
        .select("id, metadata, created_at")
        .maybeSingle();

      if (updateError) {
        throw new RealtimeLockError(
          updateError.message ?? "Optimistic update failed",
          500,
        );
      }

      if (!updatedRow) {
        const latestRow = await fetchOwnedRow(admin, recordId, userId);
        if (!latestRow) {
          throw new RealtimeLockError("Target record not found", 404);
        }
        const latest = formatRecord(latestRow);
        throw new RealtimeLockError(
          "optimistic_lock_conflict",
          409,
          {
            conflict: true,
            expected_revision: expectedRevision,
            current_revision: latest.revision,
            current_updated_at: latest.updated_at,
            server_record: latest,
          },
        );
      }

      const saved = formatRecord(updatedRow as HubDataRow);
      await emitBroadcastNotice(notifier, saved);
      return {
        conflict: false,
        record: saved,
      };
    }

    default:
      throw new RealtimeLockError(`Unsupported action: ${action}`, 400);
  }
}
