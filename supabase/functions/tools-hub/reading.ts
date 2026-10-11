import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;
export class ReadingError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ReadingError(400, "Invalid reading object");
  }
  return value as Json;
}

function string(value: unknown, max = 500, optional = false): string {
  if (optional && (value === undefined || value === null)) return "";
  if (
    typeof value !== "string" || value.length > max ||
    (!optional && !value.trim())
  ) {
    throw new ReadingError(400, "Invalid reading text");
  }
  return value.trim();
}

function integer(value: unknown, min = 0, max = 1000000): number {
  if (
    typeof value !== "number" || !Number.isSafeInteger(value) || value < min ||
    value > max
  ) {
    throw new ReadingError(400, "Invalid page count or revision");
  }
  return value;
}

function optionalInteger(
  value: unknown,
  min: number,
  max = 1000000,
): number | null {
  return value === null || value === undefined
    ? null
    : integer(value, min, max);
}

function array(value: unknown, max: number): unknown[] {
  if (!Array.isArray(value) || value.length > max) {
    throw new ReadingError(400, "Reading limit exceeded");
  }
  return value;
}

function strings(value: unknown): string[] {
  return array(value ?? [], 20).map((v) => string(v, 100));
}

function day(value: unknown): string {
  const text = string(value, 10);
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(text) ||
    Number.isNaN(Date.parse(text)) ||
    new Date(text).toISOString().slice(0, 10) !== text
  ) {
    throw new ReadingError(400, "Invalid reading date");
  }
  return text;
}

function uuid(value: unknown): string {
  const id = string(value, 36);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
  ) {
    throw new ReadingError(400, "Invalid reading id");
  }
  return id;
}

function link(value: unknown): string {
  const text = string(value, 2000, true);
  if (text && !/^https:\/\//.test(text)) {
    throw new ReadingError(400, "Source must use HTTPS");
  }
  return text;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    const map = value as Json;
    return `{${
      Object.keys(map).sort().map((key) =>
        `${JSON.stringify(key)}:${canonical(map[key])}`
      ).join(",")
    }}`;
  }
  return JSON.stringify(value);
}

export function validateAuthor(value: unknown): Json {
  const author = object(value);
  return {
    id: string(author.id, 150),
    name: string(author.name),
    aliases: strings(author.aliases),
    centuries: strings(author.centuries),
    regions: strings(author.regions),
    traditions: strings(author.traditions),
    source: link(author.source),
    note: string(author.note, 2000, true),
  };
}

export function validateWork(value: unknown): Json {
  const work = object(value);
  return {
    id: string(work.id, 150),
    title: string(work.title),
    author_info: validateAuthor(work.author_info),
    original_title: string(work.original_title, 500, true),
    centuries: strings(work.centuries),
    genres: strings(work.genres),
    source: link(work.source),
    note: string(work.note, 2000, true),
  };
}

// Do not accept client-provided edit history or user ownership.
export function validateCycles(value: unknown, previous: unknown = []): Json[] {
  const oldCycles = Array.isArray(previous) ? previous as Json[] : [];
  const cycleIds = new Set<string>();
  const entryIds = new Set<string>();
  return array(value, 100).map((raw) => {
    const cycle = object(raw);
    const id = string(cycle.id, 150);
    if (cycleIds.has(id)) {
      throw new ReadingError(400, "Duplicate reading cycle");
    }
    cycleIds.add(id);
    const old = oldCycles.find((c) => c.id === id);
    const edition = object(cycle.edition);
    const total = optionalInteger(edition.total_pages, 1);
    const status = string(cycle.status, 20);
    if (!["unread", "reading", "read", "paused"].includes(status)) {
      throw new ReadingError(400, "Invalid status");
    }
    const entries = array(cycle.entries, 1000).map((rawEntry) => {
      const entry = object(rawEntry);
      const entryId = string(entry.id, 150);
      if (entryIds.has(entryId)) {
        throw new ReadingError(400, "Duplicate reading entry");
      }
      entryIds.add(entryId);
      const pages = integer(entry.pages);
      const start = optionalInteger(entry.start_page, 1);
      const end = optionalInteger(entry.end_page, 1);
      if (
        (start === null) !== (end === null) ||
        (start !== null && end !== null &&
          (end < start || pages !== end - start + 1)) ||
        (total !== null && (pages > total || (end !== null && end > total)))
      ) {
        throw new ReadingError(400, "Pages are outside this edition");
      }
      const normalized: Json = {
        id: entryId,
        date: day(entry.date),
        pages,
        start_page: start,
        end_page: end,
        understanding: optionalInteger(entry.understanding, 1, 5),
        impression: string(entry.impression, 10000, true),
        questions: string(entry.questions, 10000, true),
        concepts: string(entry.concepts, 2000, true),
      };
      const oldEntry =
        (Array.isArray(old?.entries) ? old.entries as Json[] : [])
          .find((e) => e.id === entryId);
      const history = Array.isArray(oldEntry?.history)
        ? [...oldEntry.history]
        : [];
      if (
        oldEntry &&
        Object.keys(normalized).some((key) => normalized[key] !== oldEntry[key])
      ) {
        if (history.length >= 100) {
          throw new ReadingError(409, "Edit history limit reached");
        }
        const { history: _history, ...snapshot } = oldEntry;
        history.push({ ...snapshot, edited_at: new Date().toISOString() });
      }
      return { ...normalized, history };
    });
    const started = day(cycle.started_at);
    const finished = cycle.finished_at == null ? null : day(cycle.finished_at);
    if (
      (status === "read") !== (finished !== null) ||
      (finished !== null && finished < started)
    ) {
      throw new ReadingError(400, "Invalid completion date");
    }
    return {
      id,
      started_at: started,
      finished_at: finished,
      status,
      entries,
      edition: {
        translator: string(edition.translator, 500, true),
        publisher: string(edition.publisher, 500, true),
        year: string(edition.year, 50, true),
        language: string(edition.language, 100, true),
        isbn: string(edition.isbn, 50, true),
        volume: string(edition.volume, 200, true),
        total_pages: total,
      },
    };
  });
}

export const readingActions = new Set([
  "reading.list",
  "reading.add",
  "reading.save",
  "reading.mark_read",
  "reading.authors",
  "reading.author.add",
]);

export async function handleReading(
  admin: SupabaseClient,
  userId: string | null,
  action: string,
  body: Json,
): Promise<Json> {
  if (!userId) throw new ReadingError(401, "Unauthorized");
  const source = action.startsWith("reading.author")
    ? "reading_author"
    : "reading";
  if (action === "reading.list" || action === "reading.authors") {
    // Explicit pagination avoids the legacy silent 50-record cutoff.
    const items: unknown[] = [];
    for (let start = 0;; start += 500) {
      const { data, error } = await admin.from("hub_data")
        .select("id, metadata, created_at").eq("source", source)
        .eq("metadata->>user_id", userId)
        .order("created_at", { ascending: false }).order("id")
        .range(start, start + 499);
      if (error) throw error;
      items.push(...(data ?? []));
      if (!data || data.length < 500) break;
    }
    return { success: true, items };
  }
  if (action === "reading.add" || action === "reading.author.add") {
    const id = body.id == null ? crypto.randomUUID() : uuid(body.id);
    const work = action === "reading.add" && body.work != null
      ? validateWork(body.work)
      : null;
    const metadata: Json = action === "reading.author.add"
      ? { author_info: validateAuthor(body.author_info), user_id: userId }
      : {
        title: work?.title ?? string(body.title),
        author: string(body.author, 500, true),
        url: string(body.url, 2000, true),
        status: "unread",
        reading_revision: 0,
        work,
        cycles: [],
        user_id: userId,
      };
    const { data, error } = await admin.from("hub_data")
      .insert({ id, source, metadata }).select("id, metadata, created_at")
      .single();
    if (error?.code === "23505") {
      const existing = await ownedItem(admin, userId, source, id);
      const old = object(existing.metadata);
      if (
        canonical(old.work ?? old.author_info ?? old.title) !==
          canonical(metadata.work ?? metadata.author_info ?? metadata.title)
      ) {
        throw new ReadingError(409, "Reading id already used");
      }
      return { success: true, item: existing };
    }
    if (error) throw error;
    return { success: true, item: data };
  }
  const id = uuid(body.id);
  const current = await ownedItem(admin, userId, source, id);
  const old = object(current.metadata);
  const revision = integer(
    old.reading_revision ?? 0,
    0,
    Number.MAX_SAFE_INTEGER - 1,
  );
  let patch: Json;
  if (action === "reading.mark_read") {
    patch = {
      status: "read",
      reading_legacy_read: true,
      read_at: new Date().toISOString(),
    };
  } else if (action === "reading.save") {
    if (integer(body.revision, 0, Number.MAX_SAFE_INTEGER) !== revision) {
      throw new ReadingError(
        409,
        "別の画面で更新されました。再読込してから保存してください",
      );
    }
    const work = validateWork(body.work);
    const cycles = validateCycles(body.cycles, old.cycles);
    // Historical completed cycles still count even when a reread is in progress.
    const legacyRead = old.reading_legacy_read === true ||
      (old.reading_legacy_read === undefined && old.status === "read" &&
        (!Array.isArray(old.cycles) || old.cycles.length === 0));
    patch = {
      work,
      cycles,
      title: work.title,
      author: object(work.author_info).name,
      reading_legacy_read: legacyRead,
      status: legacyRead || cycles.some((c) => c.status === "read")
        ? "read"
        : "unread",
    };
  } else {
    throw new ReadingError(400, "Unknown reading action");
  }
  const metadata = {
    ...old,
    ...patch,
    user_id: userId,
    reading_revision: revision + 1,
  };
  if (JSON.stringify(metadata).length > 1000000) {
    throw new ReadingError(400, "Reading record size limit reached");
  }
  let query = admin.from("hub_data").update({ metadata })
    .eq("id", id).eq("source", source).eq("metadata->>user_id", userId);
  // Compare-and-swap must cover all metadata, including legacy writers.
  query = query.eq("metadata", JSON.stringify(old));
  const { data, error } = await query.select("id, metadata, created_at")
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    throw new ReadingError(
      409,
      "別の画面で更新されました。再読込してから保存してください",
    );
  }
  return { success: true, item: data };
}

async function ownedItem(
  admin: SupabaseClient,
  userId: string,
  source: string,
  id: string,
): Promise<Json> {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at").eq("id", id).eq("source", source)
    .eq("metadata->>user_id", userId).maybeSingle();
  if (error) throw error;
  if (!data) throw new ReadingError(404, "Reading record not found");
  return data;
}
