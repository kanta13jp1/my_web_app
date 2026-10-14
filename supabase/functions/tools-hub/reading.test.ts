import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  handleReading,
  ReadingError,
  validateCycles,
  validateWork,
} from "./reading.ts";
import { readingTestClient } from "./reading_test_client.ts";

const work = {
  id: "plato:republic",
  title: "国家",
  original_title: "Republic",
  author_info: {
    id: "plato",
    name: "プラトン",
    centuries: ["紀元前4世紀"],
    regions: ["古代ギリシア"],
  },
  centuries: ["紀元前4世紀"],
  genres: ["政治哲学"],
};
const entry = {
  id: "entry1",
  date: "2026-10-11",
  pages: 10,
  start_page: 1,
  end_page: 10,
  understanding: 3,
  impression: "第一印象",
  questions: "正義とは",
  concepts: "正義",
};
const cycle = {
  id: "cycle1",
  started_at: "2026-10-11",
  finished_at: null,
  status: "reading",
  edition: {
    total_pages: 100,
    publisher: "出版社",
    translator: "訳者",
    editor: "編者",
    book_url: "https://example.com/book",
    source_url: "https://example.com/source",
  },
  entries: [entry],
};

Deno.test("reading validates edition bounds, dates, understanding and duplicate identities", () => {
  const result = validateCycles([cycle]);
  assertEquals((result[0].entries as Record<string, unknown>[])[0].pages, 10);
  for (
    const patch of [
      { pages: -1 },
      { pages: 0.5 },
      { end_page: 101, pages: 101 },
      { start_page: null },
      { understanding: 0 },
      { understanding: 6 },
      { date: "2026-02-30" },
    ]
  ) {
    assertThrows(
      () => validateCycles([{ ...cycle, entries: [{ ...entry, ...patch }] }]),
      ReadingError,
    );
  }
  assertThrows(() => validateCycles([cycle, cycle]), ReadingError);
  assertThrows(
    () => validateCycles([{ ...cycle, entries: [entry, entry] }]),
    ReadingError,
  );
  assertThrows(
    () => validateCycles([{ ...cycle, status: "read" }]),
    ReadingError,
  );
  assertThrows(
    () => validateWork({ ...work, source: "javascript:alert(1)" }),
    ReadingError,
  );
  assertEquals(
    validateCycles([{ ...cycle, edition: { total_pages: null } }])[0].edition,
    {
      translator: "",
      editor: "",
      publisher: "",
      year: "",
      language: "",
      isbn: "",
      volume: "",
      book_url: "",
      source_url: "",
      total_pages: null,
    },
  );
});

Deno.test("edition URLs reject unsafe or malformed input and editor text is bounded", () => {
  for (const key of ["book_url", "source_url"]) {
    for (
      const url of [
        "javascript:alert(1)",
        "http://example.com",
        "https://",
        "https://user:secret@example.com",
      ]
    ) {
      assertThrows(
        () =>
          validateCycles([{
            ...cycle,
            edition: { ...cycle.edition, [key]: url },
          }]),
        ReadingError,
      );
    }
  }
  assertThrows(
    () => validateCycles([{ ...cycle, edition: { editor: "x".repeat(501) } }]),
    ReadingError,
  );
});

Deno.test("server preserves history and ignores forged history", () => {
  const first = validateCycles([cycle]);
  const edited = validateCycles([{
    ...cycle,
    entries: [{
      ...entry,
      impression: "再考",
      history: [{ impression: "偽造" }],
    }],
  }], first);
  const saved = (edited[0].entries as Record<string, unknown>[])[0];
  assertEquals(
    (saved.history as Record<string, unknown>[])[0].impression,
    "第一印象",
  );
  assertEquals((saved.history as unknown[]).length, 1);
  const unchanged = validateCycles(edited, edited);
  assertEquals(
    ((unchanged[0].entries as Record<string, unknown>[])[0]
      .history as unknown[]).length,
    1,
  );
});

Deno.test("older clients retain edition additions and explicit empty values clear them", () => {
  const previous = validateCycles([cycle]);
  const oldClient = { ...cycle, edition: { total_pages: 100 } };
  const retained = validateCycles([oldClient], previous)[0].edition as Record<
    string,
    unknown
  >;
  assertEquals(retained.editor, "編者");
  assertEquals(retained.book_url, "https://example.com/book");
  assertEquals(retained.source_url, "https://example.com/source");
  const cleared = validateCycles([{
    ...oldClient,
    edition: { total_pages: 100, editor: "", book_url: "", source_url: "" },
  }], previous)[0].edition as Record<string, unknown>;
  assertEquals(cleared.editor, "");
  assertEquals(cleared.book_url, "");
  assertEquals(cleared.source_url, "");
});

Deno.test("authentication required before any reading database call", async () => {
  const client = createClient("https://example.invalid", "fixture-key");
  for (
    const action of [
      "reading.list",
      "reading.add",
      "reading.save",
      "reading.mark_read",
      "reading.authors",
      "reading.author.add",
    ]
  ) {
    await assertRejects(
      () => handleReading(client, null, action, {}),
      ReadingError,
      "Unauthorized",
    );
  }
});

const databaseUrl = Deno.env.get("READING_TEST_DATABASE_URL");
Deno.test({
  name:
    "real PostgREST ownership, idempotency, CAS, history, legacy preservation and pagination",
  ignore: !databaseUrl,
  fn: async () => {
    const client = await readingTestClient();
    const a = "11111111-1111-4111-8111-111111111111";
    const b = "22222222-2222-4222-8222-222222222222";
    const id = crypto.randomUUID();
    const created = await handleReading(client, a, "reading.add", { id, work });
    assertEquals((created.item as Record<string, unknown>).id, id);
    const retry = await handleReading(client, a, "reading.add", { id, work });
    assertEquals((retry.item as Record<string, unknown>).id, id);
    const ownList = await handleReading(client, b, "reading.list", {});
    assertEquals(ownList.items, []);
    for (const action of ["reading.mark_read", "reading.save", "reading.add"]) {
      await assertRejects(
        () =>
          handleReading(client, b, action, {
            id,
            work,
            cycles: [],
            revision: 0,
          }),
        ReadingError,
        "not found",
      );
    }
    const save = { id, work, cycles: [cycle], revision: 0, user_id: b };
    await handleReading(client, a, "reading.save", save);
    await assertRejects(
      () => handleReading(client, a, "reading.save", save),
      ReadingError,
      "別の画面",
    );
    const latest = await handleReading(client, a, "reading.list", {});
    const stored = (latest.items as Record<string, unknown>[]).find((row) =>
      row.id === id
    )!;
    const meta = stored.metadata as Record<string, unknown>;
    assertEquals(meta.user_id, a);
    assertEquals(meta.reading_revision, 1);
    const storedEdition = (meta.cycles as Record<string, unknown>[])[0]
      .edition as Record<string, unknown>;
    assertEquals(storedEdition.editor, "編者");
    assertEquals(storedEdition.publisher, "出版社");
    assertEquals(storedEdition.translator, "訳者");
    assertEquals(storedEdition.book_url, "https://example.com/book");
    assertEquals(storedEdition.source_url, "https://example.com/source");
    const userB = await readingTestClient("authenticated", b);
    const blockedRead = await userB.from("hub_data").select("id").eq("id", id);
    assertEquals(blockedRead.data, []);
    const blockedUpdate = await userB.from("hub_data").update({
      metadata: { user_id: b },
    }).eq("id", id).select("id");
    assertEquals(blockedUpdate.data, []);
    const blockedDelete = await userB.from("hub_data").delete().eq("id", id)
      .select("id");
    assertEquals(blockedDelete.data, []);
    const blockedInsert = await userB.from("hub_data").insert({
      source: "reading",
      metadata: { user_id: a },
    });
    assertEquals(blockedInsert.error?.code, "42501");
    const userA = await readingTestClient("authenticated", a);
    const ownRead = await userA.from("hub_data").select("id").eq("id", id);
    assertEquals(ownRead.data?.length, 1);
    const reassignment = await userA.from("hub_data").update({
      metadata: { user_id: b },
    }).eq("id", id);
    assertEquals(reassignment.error?.code, "42501");
    const anonymous = await readingTestClient("anon");
    const anonymousRead = await anonymous.from("hub_data").select("id");
    assertEquals(anonymousRead.error?.code, "42501");
    const simultaneous = await Promise.allSettled([
      handleReading(client, a, "reading.save", { ...save, revision: 1 }),
      handleReading(client, a, "reading.save", { ...save, revision: 1 }),
    ]);
    assertEquals(
      simultaneous.filter((r) => r.status === "fulfilled").length,
      1,
    );
    const editedCycle = {
      ...cycle,
      edition: { total_pages: 100, publisher: "出版社", translator: "訳者" },
      entries: [{ ...entry, impression: "再考" }],
    };
    const edited = await handleReading(client, a, "reading.save", {
      ...save,
      revision: 2,
      cycles: [editedCycle],
    });
    const updated = (edited.item as Record<string, unknown>).metadata as Record<
      string,
      unknown
    >;
    const savedEntry =
      ((updated.cycles as Record<string, unknown>[])[0].entries as Record<
        string,
        unknown
      >[])[0];
    const preservedEdition = (updated.cycles as Record<string, unknown>[])[0]
      .edition as Record<string, unknown>;
    assertEquals(preservedEdition.editor, "編者");
    assertEquals(preservedEdition.book_url, "https://example.com/book");
    assertEquals(preservedEdition.source_url, "https://example.com/source");
    assertEquals(
      (savedEntry.history as Record<string, unknown>[])[0].impression,
      "第一印象",
    );
    const completedCycle = {
      ...editedCycle,
      status: "read",
      finished_at: "2026-10-11",
    };
    await handleReading(client, a, "reading.save", {
      ...save,
      revision: 3,
      cycles: [completedCycle],
    });
    const reopened = await handleReading(client, a, "reading.save", {
      ...save,
      revision: 4,
      cycles: [editedCycle],
    });
    assertEquals(
      ((reopened.item as Record<string, unknown>).metadata as Record<
        string,
        unknown
      >).status,
      "unread",
    );

    const legacyId = crypto.randomUUID();
    const { error } = await client.from("hub_data").insert({
      id: legacyId,
      source: "reading",
      metadata: {
        user_id: a,
        title: "旧タイトル",
        author: "旧著者",
        url: "https://example.com/book",
        custom: "keep",
      },
    });
    if (error) throw error;
    const legacy = await handleReading(client, a, "reading.mark_read", {
      id: legacyId,
    });
    const legacyMeta = (legacy.item as Record<string, unknown>)
      .metadata as Record<string, unknown>;
    assertEquals(legacyMeta.title, "旧タイトル");
    assertEquals(legacyMeta.author, "旧著者");
    assertEquals(legacyMeta.url, "https://example.com/book");
    assertEquals(legacyMeta.custom, "keep");
    const authorId = crypto.randomUUID();
    await handleReading(client, a, "reading.author.add", {
      id: authorId,
      author_info: { ...work.author_info, id: `private:${authorId}` },
    });
    assertEquals(
      (await handleReading(client, b, "reading.authors", {})).items,
      [],
    );
    await handleReading(client, a, "reading.author.add", {
      id: authorId,
      author_info: { ...work.author_info, id: `private:${authorId}` },
    });
    // Reading source cannot target a private-author row with the same owner.
    await assertRejects(
      () => handleReading(client, a, "reading.mark_read", { id: authorId }),
      ReadingError,
      "not found",
    );
    const many = Array.from(
      { length: 505 },
      () => ({
        source: "reading",
        metadata: { user_id: a, title: "pagination" },
      }),
    );
    const bulk = await client.from("hub_data").insert(many);
    if (bulk.error) throw bulk.error;
    const all = await handleReading(client, a, "reading.list", {});
    assertEquals((all.items as unknown[]).length, 507);
  },
});

Deno.test("work memo accepts long notes without truncation and rejects overflow", () => {
  const note = "本".repeat(100000);
  assertEquals(validateWork({ ...work, note }).note, note);
  assertThrows(() => validateWork({ ...work, note: note + "字" }), ReadingError);
});
