export const MEMO_REACTION_EMOJIS = [
  "\u{1F44D}",
  "\u2764\uFE0F",
  "\u{1F525}",
  "\u{1F4A1}",
  "\u{1F389}",
] as const;

type MemoReactionEmoji = typeof MEMO_REACTION_EMOJIS[number];

export type MemoReactionAction = "memo.react.list" | "memo.react.toggle";

export interface MemoReactionBody {
  memo_id?: unknown;
  reaction?: unknown;
}

export interface MemoReactionRow {
  id?: string | number;
  memo_id?: number;
  ip_hash: string;
  reaction: string;
}

export interface MemoReactionStore {
  findExisting(input: {
    memoId: number;
    ipHash: string;
    reaction: MemoReactionEmoji;
  }): Promise<{ id: string | number } | null>;
  deleteById(id: string | number): Promise<void>;
  insert(input: {
    memoId: number;
    ipHash: string;
    reaction: MemoReactionEmoji;
  }): Promise<{ error?: string | null }>;
  listByMemoId(memoId: number): Promise<MemoReactionRow[]>;
}

export interface MemoReactionResult {
  payload: Record<string, unknown>;
  status: number;
}

type DbError = { message: string };
type QueryResult<T> = { data: T | null; error?: DbError | null };
type MutationResult = { error?: DbError | null };
type MemoReactionIdRow = { id: string | number };
type MemoReactionInsert = {
  memo_id: number;
  ip_hash: string;
  reaction: MemoReactionEmoji;
};

interface MemoReactionSelectBuilder<T> extends PromiseLike<QueryResult<T[]>> {
  eq(column: string, value: unknown): MemoReactionSelectBuilder<T>;
  maybeSingle(): PromiseLike<QueryResult<T | null>>;
}

interface MemoReactionDeleteBuilder extends PromiseLike<MutationResult> {
  eq(column: string, value: unknown): MemoReactionDeleteBuilder;
}

interface MemoReactionTable {
  select<T>(columns: string): MemoReactionSelectBuilder<T>;
  delete(): MemoReactionDeleteBuilder;
  insert(row: MemoReactionInsert): PromiseLike<MutationResult>;
}

interface MemoReactionClient {
  from(table: "memo_reactions"): MemoReactionTable;
}

function memoReactionTable(client: unknown): MemoReactionTable {
  return (client as MemoReactionClient).from("memo_reactions");
}

export function createSupabaseMemoReactionStore(
  client: unknown,
): MemoReactionStore {
  return {
    async findExisting({ memoId, ipHash, reaction }) {
      const { data } = await memoReactionTable(client)
        .select<MemoReactionIdRow>("id")
        .eq("memo_id", memoId)
        .eq("ip_hash", ipHash)
        .eq("reaction", reaction)
        .maybeSingle();
      return data ? { id: data.id } : null;
    },
    async deleteById(id) {
      await memoReactionTable(client).delete().eq("id", id);
    },
    async insert({ memoId, ipHash, reaction }) {
      const { error } = await memoReactionTable(client)
        .insert({ memo_id: memoId, ip_hash: ipHash, reaction });
      return { error: error?.message ?? null };
    },
    async listByMemoId(memoId) {
      const { data } = await memoReactionTable(client)
        .select<MemoReactionRow>("reaction, ip_hash")
        .eq("memo_id", memoId);
      return data ?? [];
    },
  };
}

export async function hashMemoReactionIp(rawIp: string): Promise<string> {
  const ipHashBytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(rawIp),
  );
  return Array.from(new Uint8Array(ipHashBytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function memoReactionIpFromHeaders(headers: Headers): string {
  const ipHeader = headers.get("x-forwarded-for") ??
    headers.get("cf-connecting-ip") ??
    "";
  return ipHeader.split(",")[0]?.trim() || "anon";
}

function isMemoReactionEmoji(value: string): value is MemoReactionEmoji {
  return MEMO_REACTION_EMOJIS.includes(value as MemoReactionEmoji);
}

function emptyReactionCounts(): Record<string, number> {
  const reactions: Record<string, number> = {};
  for (const reaction of MEMO_REACTION_EMOJIS) reactions[reaction] = 0;
  return reactions;
}

export async function handleMemoReactionAction(input: {
  action: MemoReactionAction;
  body: MemoReactionBody;
  headers: Headers;
  store: MemoReactionStore;
}): Promise<MemoReactionResult> {
  const memoId = Number(input.body.memo_id);
  if (!Number.isFinite(memoId) || memoId <= 0) {
    return {
      payload: { error: "memo_id (positive integer) is required" },
      status: 400,
    };
  }

  const ipHash = await hashMemoReactionIp(
    memoReactionIpFromHeaders(input.headers),
  );
  let added: boolean | undefined;

  if (input.action === "memo.react.toggle") {
    const reaction = String(input.body.reaction ?? "");
    if (!isMemoReactionEmoji(reaction)) {
      return {
        payload: {
          error: `reaction must be one of: ${MEMO_REACTION_EMOJIS.join(" ")}`,
        },
        status: 400,
      };
    }

    const existing = await input.store.findExisting({
      memoId,
      ipHash,
      reaction,
    });
    if (existing) {
      await input.store.deleteById(existing.id);
      added = false;
    } else {
      const result = await input.store.insert({ memoId, ipHash, reaction });
      if (result.error) {
        return { payload: { error: result.error }, status: 500 };
      }
      added = true;
    }
  }

  const rows = await input.store.listByMemoId(memoId);
  const reactions = emptyReactionCounts();
  const userReactions: string[] = [];

  for (const row of rows) {
    if (!isMemoReactionEmoji(row.reaction)) continue;
    reactions[row.reaction] = (reactions[row.reaction] ?? 0) + 1;
    if (row.ip_hash === ipHash && !userReactions.includes(row.reaction)) {
      userReactions.push(row.reaction);
    }
  }

  const payload: Record<string, unknown> = {
    reactions,
    counts: reactions,
    userReactions,
  };
  if (added !== undefined) payload.added = added;
  return { payload, status: 200 };
}
