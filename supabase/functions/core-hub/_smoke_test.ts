import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleMemoReactionAction,
  hashMemoReactionIp,
  MEMO_REACTION_EMOJIS,
  type MemoReactionRow,
  type MemoReactionStore,
} from "./memo_reactions.ts";

class FakeMemoReactionStore implements MemoReactionStore {
  rows: MemoReactionRow[];
  private nextId: number;

  constructor(rows: MemoReactionRow[] = []) {
    this.rows = [...rows];
    this.nextId = rows.reduce((maxId, row) => {
      const id = typeof row.id === "number" ? row.id : Number(row.id ?? 0);
      return Number.isFinite(id) ? Math.max(maxId, id) : maxId;
    }, 0) + 1;
  }

  findExisting({
    memoId,
    ipHash,
    reaction,
  }: Parameters<MemoReactionStore["findExisting"]>[0]) {
    const row = this.rows.find((candidate) =>
      candidate.memo_id === memoId &&
      candidate.ip_hash === ipHash &&
      candidate.reaction === reaction
    );
    return Promise.resolve(row?.id == null ? null : { id: row.id });
  }

  deleteById(id: string | number) {
    this.rows = this.rows.filter((row) => row.id !== id);
    return Promise.resolve();
  }

  insert({
    memoId,
    ipHash,
    reaction,
  }: Parameters<MemoReactionStore["insert"]>[0]) {
    this.rows.push({
      id: this.nextId++,
      memo_id: memoId,
      ip_hash: ipHash,
      reaction,
    });
    return Promise.resolve({ error: null });
  }

  listByMemoId(memoId: number) {
    return Promise.resolve(this.rows.filter((row) => row.memo_id === memoId));
  }
}

const [likeReaction] = MEMO_REACTION_EMOJIS;

function forwardedHeaders(ip = "203.0.113.10") {
  return new Headers({ "x-forwarded-for": `${ip}, 10.0.0.1` });
}

function emptyCounts() {
  return Object.fromEntries(
    MEMO_REACTION_EMOJIS.map((reaction) => [reaction, 0]),
  );
}

Deno.test("memo.react.list returns zero counts when no rows exist", async () => {
  const result = await handleMemoReactionAction({
    action: "memo.react.list",
    body: { memo_id: 1 },
    headers: forwardedHeaders(),
    store: new FakeMemoReactionStore(),
  });

  assertEquals(result.status, 200);
  assertEquals(result.payload.reactions, emptyCounts());
  assertEquals(result.payload.counts, result.payload.reactions);
  assertEquals(result.payload.userReactions, []);
});

Deno.test("memo.react.toggle adds a new reaction", async () => {
  const store = new FakeMemoReactionStore();
  const result = await handleMemoReactionAction({
    action: "memo.react.toggle",
    body: { memo_id: 1, reaction: likeReaction },
    headers: forwardedHeaders(),
    store,
  });

  const ipHash = await hashMemoReactionIp("203.0.113.10");
  assertEquals(result.status, 200);
  assertEquals(result.payload.added, true);
  assertEquals(store.rows, [{
    id: 1,
    memo_id: 1,
    ip_hash: ipHash,
    reaction: likeReaction,
  }]);
  assertEquals(result.payload.reactions, {
    ...emptyCounts(),
    [likeReaction]: 1,
  });
  assertEquals(result.payload.counts, result.payload.reactions);
  assertEquals(result.payload.userReactions, [likeReaction]);
});

Deno.test("memo.react.toggle removes an existing reaction", async () => {
  const ipHash = await hashMemoReactionIp("203.0.113.10");
  const store = new FakeMemoReactionStore([{
    id: 7,
    memo_id: 1,
    ip_hash: ipHash,
    reaction: likeReaction,
  }]);

  const result = await handleMemoReactionAction({
    action: "memo.react.toggle",
    body: { memo_id: 1, reaction: likeReaction },
    headers: forwardedHeaders(),
    store,
  });

  assertEquals(result.status, 200);
  assertEquals(result.payload.added, false);
  assertEquals(store.rows, []);
  assertEquals(result.payload.reactions, emptyCounts());
  assertEquals(result.payload.userReactions, []);
});

Deno.test("memo.react.toggle rejects invalid reactions", async () => {
  const store = new FakeMemoReactionStore();
  const result = await handleMemoReactionAction({
    action: "memo.react.toggle",
    body: { memo_id: 1, reaction: "invalid" },
    headers: forwardedHeaders(),
    store,
  });

  assertEquals(result.status, 400);
  assertEquals(result.payload, {
    error: `reaction must be one of: ${MEMO_REACTION_EMOJIS.join(" ")}`,
  });
  assertEquals(store.rows, []);
});

Deno.test("memo.react.list ignores non-allowlisted reactions", async () => {
  const ipHash = await hashMemoReactionIp("203.0.113.10");
  const store = new FakeMemoReactionStore([{
    id: 1,
    memo_id: 1,
    ip_hash: ipHash,
    reaction: "not-allowlisted",
  }]);

  const result = await handleMemoReactionAction({
    action: "memo.react.list",
    body: { memo_id: 1 },
    headers: forwardedHeaders(),
    store,
  });

  assertEquals(result.status, 200);
  assertEquals(result.payload.reactions, emptyCounts());
  assertEquals(result.payload.counts, result.payload.reactions);
  assertEquals(result.payload.userReactions, []);
});
