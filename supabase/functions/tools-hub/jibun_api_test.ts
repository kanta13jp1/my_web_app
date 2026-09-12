// jibun_api.ts unit tests — 自分API v1 (2026-07-12 WEB版)
// FakeJibunApiStore による store 注入方式 (core-hub/_smoke_test.ts と同型) で
// ライブ DB なしに認証・スコープ・rate limit・SSRF ガード・Worker 呼び出しを検証する。

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  API_RATE_LIMIT_PER_MINUTE,
  type ApiKeyRow,
  type AuditLogRow,
  generateApiKey,
  generateSigningSecret,
  handleJibunApiAction,
  hmacSha256Hex,
  isPrivateHost,
  JIBUN_API_KEY_PREFIX,
  JIBUN_API_SCOPES,
  type JibunApiStore,
  MAX_KEYS_PER_USER,
  MAX_WEBHOOKS_PER_USER,
  normalizeIntegrationRegistryKey,
  normalizeScopes,
  normalizeWorkerSlug,
  type NoteRow,
  parseInetOrNull,
  resolveHostToPrivateError,
  sanitizeSearchQuery,
  sha256Hex,
  slugFromName,
  validateWorkerEndpoint,
  type WebhookRow,
  WORKER_INVOKE_LIMIT_PER_MINUTE,
  type WorkerRow,
} from "./jibun_api.ts";

// ── 純関数 ───────────────────────────────────────────────────────────────────

Deno.test("normalizeScopes accepts valid scopes and dedupes", () => {
  const scopes = normalizeScopes(["notes.read", "notes.read", "tasks.read"]);
  assertEquals(scopes, ["notes.read", "tasks.read"]);
});

Deno.test("normalizeScopes rejects unknown scope / empty / non-array", () => {
  assertEquals(normalizeScopes(["all"]), null);
  assertEquals(normalizeScopes(["notes.read", "admin"]), null);
  assertEquals(normalizeScopes([]), null);
  assertEquals(normalizeScopes("notes.read"), null);
  assertEquals(normalizeScopes([42]), null);
});

Deno.test("normalizeIntegrationRegistryKey matches registry write keys", () => {
  assertEquals(
    normalizeIntegrationRegistryKey(" Core Billing / v2 "),
    "core-billing-v2",
  );
  assertEquals(normalizeIntegrationRegistryKey("___"), "___");
  assertEquals(normalizeIntegrationRegistryKey(null), "");
});

Deno.test("generateApiKey format and uniqueness", () => {
  const a = generateApiKey();
  const b = generateApiKey();
  assert(a.key.startsWith(JIBUN_API_KEY_PREFIX));
  assert(a.key.length > JIBUN_API_KEY_PREFIX.length + 40);
  assertEquals(a.prefix, a.key.slice(0, JIBUN_API_KEY_PREFIX.length + 8));
  assert(a.key !== b.key);
});

Deno.test("generateSigningSecret format", () => {
  const secret = generateSigningSecret();
  assert(secret.startsWith("jibun_whsec_"));
  assert(secret.length > 40);
});

Deno.test("sha256Hex known vector", async () => {
  assertEquals(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("hmacSha256Hex known vector", async () => {
  // RFC 4231 Test Case 2: key="Jefe", data="what do ya want for nothing?"
  assertEquals(
    await hmacSha256Hex("Jefe", "what do ya want for nothing?"),
    "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
  );
});

Deno.test("isPrivateHost blocks private / loopback / metadata ranges", () => {
  for (
    const host of [
      "localhost",
      "sub.localhost",
      "app.local",
      "api.internal",
      "metadata.google.internal",
      "127.0.0.1",
      "10.0.0.5",
      "172.16.0.1",
      "172.31.255.255",
      "192.168.1.1",
      "169.254.169.254",
      "100.64.0.1",
      "0.0.0.0",
      "224.0.0.1",
      "::1",
      "::",
      "fc00::1",
      "fd12::1",
      "fe80::1",
      "::ffff:192.168.0.1",
      // IPv4-mapped hex form (WHATWG canonical) — 127.0.0.1 / 10.0.0.1
      "::ffff:7f00:1",
      "::ffff:a00:1",
    ]
  ) {
    assert(isPrivateHost(host), `expected private: ${host}`);
  }
});

Deno.test("isPrivateHost allows public hosts", () => {
  for (
    const host of [
      "example.com",
      "hooks.zapier.com",
      "8.8.8.8",
      "172.15.0.1",
      "172.32.0.1",
      "2001:db8::1",
    ]
  ) {
    assertEquals(isPrivateHost(host), false, `expected public: ${host}`);
  }
});

Deno.test("validateWorkerEndpoint enforces https + public host", () => {
  assertEquals(validateWorkerEndpoint("https://example.com/hook"), null);
  assertStringIncludes(
    validateWorkerEndpoint("http://example.com/hook") ?? "",
    "https",
  );
  assertStringIncludes(
    validateWorkerEndpoint("https://localhost/hook") ?? "",
    "private",
  );
  assertStringIncludes(
    validateWorkerEndpoint("https://169.254.169.254/latest") ?? "",
    "private",
  );
  assertStringIncludes(
    validateWorkerEndpoint("https://user:pass@example.com/") ?? "",
    "credentials",
  );
  assertStringIncludes(validateWorkerEndpoint("") ?? "", "required");
  assertStringIncludes(validateWorkerEndpoint("not a url") ?? "", "valid");
});

Deno.test("normalizeWorkerSlug + slugFromName", () => {
  assertEquals(normalizeWorkerSlug("My-Worker"), "my-worker");
  assertEquals(normalizeWorkerSlug("a"), null); // 2文字未満
  assertEquals(normalizeWorkerSlug("-bad"), null);
  assertEquals(normalizeWorkerSlug("日本語"), null);
  assertEquals(slugFromName("My Cool Worker!"), "my-cool-worker");
});

Deno.test("sanitizeSearchQuery strips PostgREST filter metacharacters", () => {
  // カンマ・括弧・引用符・ワイルドカードを除去し .or() 注入を防ぐ
  assertEquals(
    sanitizeSearchQuery("foo,id.gt.0(bar)"),
    "foo id.gt.0 bar",
  );
  assertEquals(sanitizeSearchQuery("a\"b'c\\d"), "a b c d");
  assertEquals(sanitizeSearchQuery("100%_off*"), "100 off");
  assertEquals(sanitizeSearchQuery(42), "");
  assertEquals(sanitizeSearchQuery("  hello  "), "hello");
  assertEquals(sanitizeSearchQuery("x".repeat(200)).length, 100);
});

Deno.test("parseInetOrNull accepts valid IPs and rejects garbage", () => {
  assertEquals(parseInetOrNull("203.0.113.5"), "203.0.113.5");
  assertEquals(parseInetOrNull("2001:db8::1"), "2001:db8::1");
  assertEquals(parseInetOrNull(""), null);
  assertEquals(parseInetOrNull("unknown"), null);
  assertEquals(parseInetOrNull("203.0.113.5:8080"), null);
  assertEquals(parseInetOrNull("999.1.1.1"), null);
});

Deno.test("resolveHostToPrivateError flags hosts resolving to private IPs", async () => {
  // A レコードが内部 IP を指すホスト名を検出する (DNS rebinding 対策)
  const rebind = await resolveHostToPrivateError(
    "evil.example.com",
    (_host, type) => Promise.resolve(type === "A" ? ["169.254.169.254"] : []),
  );
  assert(rebind !== null);
  assertStringIncludes(rebind ?? "", "169.254.169.254");

  const publicHost = await resolveHostToPrivateError(
    "good.example.com",
    (_host, type) => Promise.resolve(type === "A" ? ["93.184.216.34"] : []),
  );
  assertEquals(publicHost, null);

  // resolver がレコードなしで throw しても握りつぶして null に退避する
  const throwing = await resolveHostToPrivateError(
    "nx.example.com",
    () => Promise.reject(new Error("NXDOMAIN")),
  );
  assertEquals(throwing, null);
});

// ── FakeStore ────────────────────────────────────────────────────────────────

class FakeJibunApiStore implements JibunApiStore {
  keys: ApiKeyRow[] = [];
  workers: WorkerRow[] = [];
  auditLog: AuditLogRow[] = [];
  notes: NoteRow[] = [];
  webhooks: WebhookRow[] = [];
  integrationRows: Record<string, unknown>[] = [];
  rateLimitCounts: Record<string, number> = {};
  nextId = 1;

  countKeys(userId: string): Promise<number> {
    return Promise.resolve(
      this.keys.filter((k) => k.user_id === userId && !k.revoked).length,
    );
  }
  insertKey(
    row: Omit<ApiKeyRow, "id" | "created_at" | "last_used_at" | "revoked">,
  ): Promise<ApiKeyRow> {
    const full: ApiKeyRow = {
      ...row,
      id: `key-${this.nextId++}`,
      revoked: false,
      last_used_at: null,
      created_at: new Date().toISOString(),
    };
    this.keys.push(full);
    return Promise.resolve(full);
  }
  listKeys(userId: string): Promise<ApiKeyRow[]> {
    return Promise.resolve(this.keys.filter((k) => k.user_id === userId));
  }
  findKeyByHash(keyHash: string): Promise<ApiKeyRow | null> {
    return Promise.resolve(
      this.keys.find((k) => k.key_hash === keyHash) ?? null,
    );
  }
  revokeKey(userId: string, keyId: string): Promise<boolean> {
    const key = this.keys.find(
      (k) => k.id === keyId && k.user_id === userId && !k.revoked,
    );
    if (!key) return Promise.resolve(false);
    key.revoked = true;
    return Promise.resolve(true);
  }
  touchKeyLastUsed(keyId: string): Promise<void> {
    const key = this.keys.find((k) => k.id === keyId);
    if (key) key.last_used_at = new Date().toISOString();
    return Promise.resolve();
  }
  countWorkers(userId: string): Promise<number> {
    return Promise.resolve(
      this.workers.filter((w) => w.user_id === userId).length,
    );
  }
  insertWorker(
    row: Omit<
      WorkerRow,
      "id" | "created_at" | "invocation_count" | "last_invoked_at"
    >,
  ): Promise<WorkerRow> {
    const full: WorkerRow = {
      ...row,
      id: `worker-${this.nextId++}`,
      invocation_count: 0,
      last_invoked_at: null,
      created_at: new Date().toISOString(),
    };
    this.workers.push(full);
    return Promise.resolve(full);
  }
  listWorkers(userId: string): Promise<WorkerRow[]> {
    return Promise.resolve(this.workers.filter((w) => w.user_id === userId));
  }
  findWorkerBySlug(userId: string, slug: string): Promise<WorkerRow | null> {
    return Promise.resolve(
      this.workers.find((w) => w.user_id === userId && w.slug === slug) ??
        null,
    );
  }
  updateWorker(
    userId: string,
    workerId: string,
    patch: Partial<
      Pick<
        WorkerRow,
        "name" | "description" | "endpoint_url" | "enabled" | "timeout_ms"
      >
    >,
  ): Promise<boolean> {
    const worker = this.workers.find(
      (w) => w.id === workerId && w.user_id === userId,
    );
    if (!worker) return Promise.resolve(false);
    Object.assign(worker, patch);
    return Promise.resolve(true);
  }
  deleteWorker(userId: string, workerId: string): Promise<boolean> {
    const before = this.workers.length;
    this.workers = this.workers.filter(
      (w) => !(w.id === workerId && w.user_id === userId),
    );
    return Promise.resolve(this.workers.length < before);
  }
  recordWorkerInvocation(workerId: string): Promise<void> {
    const worker = this.workers.find((w) => w.id === workerId);
    if (worker) {
      worker.invocation_count += 1;
      worker.last_invoked_at = new Date().toISOString();
    }
    return Promise.resolve();
  }
  insertAuditLog(row: AuditLogRow): Promise<void> {
    this.auditLog.push(row);
    return Promise.resolve();
  }
  countAuditSince(
    apiKeyId: string,
    _sinceIso: string,
    actionPrefix?: string,
  ): Promise<number> {
    const override = this.rateLimitCounts[actionPrefix ?? "*"];
    if (override !== undefined) return Promise.resolve(override);
    return Promise.resolve(
      this.auditLog.filter(
        (row) =>
          row.api_key_id === apiKeyId &&
          (!actionPrefix || row.action.startsWith(actionPrefix)),
      ).length,
    );
  }
  listAuditForUser(
    userId: string,
    limit: number,
  ): Promise<Record<string, unknown>[]> {
    return Promise.resolve(
      this.auditLog
        .filter((row) => row.user_id === userId)
        .slice(0, limit) as unknown as Record<string, unknown>[],
    );
  }
  listNotes(
    userId: string,
    options: { limit: number; query: string },
  ): Promise<NoteRow[]> {
    void userId;
    const filtered = options.query === "" ? this.notes : this.notes.filter(
      (n) =>
        n.title.includes(options.query) || n.content.includes(options.query),
    );
    return Promise.resolve(filtered.slice(0, options.limit));
  }
  createNote(
    _userId: string,
    note: { title: string; content: string },
  ): Promise<NoteRow> {
    const row: NoteRow = {
      id: this.nextId++,
      title: note.title,
      content: note.content,
      created_at: new Date().toISOString(),
      updated_at: null,
    };
    this.notes.push(row);
    return Promise.resolve(row);
  }
  updateNote(
    userId: string,
    noteId: number,
    patch: { title?: string; content?: string },
  ): Promise<NoteRow | null> {
    const note = this.notes.find((n) => n.id === noteId);
    if (!note) return Promise.resolve(null);
    void userId;
    if (patch.title !== undefined) note.title = patch.title;
    if (patch.content !== undefined) note.content = patch.content;
    note.updated_at = new Date().toISOString();
    return Promise.resolve({ ...note });
  }
  deleteNote(userId: string, noteId: number): Promise<boolean> {
    void userId;
    const before = this.notes.length;
    this.notes = this.notes.filter((n) => n.id !== noteId);
    return Promise.resolve(this.notes.length < before);
  }
  countWebhooks(userId: string): Promise<number> {
    return Promise.resolve(
      this.webhooks.filter((w) => w.user_id === userId).length,
    );
  }
  insertWebhook(
    row: Omit<
      WebhookRow,
      "id" | "created_at" | "delivery_count" | "last_delivered_at"
    >,
  ): Promise<WebhookRow> {
    const full: WebhookRow = {
      ...row,
      id: `wh-${this.nextId++}`,
      delivery_count: 0,
      last_delivered_at: null,
      created_at: new Date().toISOString(),
    };
    this.webhooks.push(full);
    return Promise.resolve(full);
  }
  listWebhooks(userId: string): Promise<WebhookRow[]> {
    return Promise.resolve(this.webhooks.filter((w) => w.user_id === userId));
  }
  findWebhookById(
    userId: string,
    webhookId: string,
  ): Promise<WebhookRow | null> {
    return Promise.resolve(
      this.webhooks.find((w) => w.id === webhookId && w.user_id === userId) ??
        null,
    );
  }
  deleteWebhook(userId: string, webhookId: string): Promise<boolean> {
    const before = this.webhooks.length;
    this.webhooks = this.webhooks.filter(
      (w) => !(w.id === webhookId && w.user_id === userId),
    );
    return Promise.resolve(this.webhooks.length < before);
  }
  listActiveWebhooks(userId: string, event: string): Promise<WebhookRow[]> {
    return Promise.resolve(
      this.webhooks.filter(
        (w) => w.user_id === userId && w.enabled && w.events.includes(event),
      ),
    );
  }
  touchWebhookDelivery(webhookId: string): Promise<void> {
    const wh = this.webhooks.find((w) => w.id === webhookId);
    if (wh) {
      wh.delivery_count += 1;
      wh.last_delivered_at = new Date().toISOString();
    }
    return Promise.resolve();
  }
  listUserTasks(limit: number): Promise<Record<string, unknown>[]> {
    return Promise.resolve(
      [{ id: "task-1", title: "task", status: "pending" }].slice(0, limit),
    );
  }
  listAchievements(limit: number): Promise<Record<string, unknown>[]> {
    return Promise.resolve(
      [{ title: "達成", description: "テスト", completed_at: "2026-07-12" }]
        .slice(0, limit),
    );
  }
  listIntegrationRegistry(
    userId: string,
  ): Promise<Record<string, unknown>[]> {
    return Promise.resolve(
      this.integrationRows.filter((row) => {
        const metadata = row.metadata as Record<string, unknown> | undefined;
        return metadata?.user_id === userId;
      }),
    );
  }
}

function makeRequest(
  options: { bearer?: string } = {},
): Request {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };
  if (options.bearer) headers["authorization"] = `Bearer ${options.bearer}`;
  return new Request("https://example.com/functions/v1/tools-hub", {
    method: "POST",
    headers,
  });
}

async function issueKey(
  store: FakeJibunApiStore,
  userId: string,
  scopes: string[],
): Promise<string> {
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.create",
    body: { name: "test key", scopes },
    store,
    getUserId: () => Promise.resolve(userId),
  });
  const data = await response!.json();
  return data.api_key as string;
}

// ── 管理系 action ────────────────────────────────────────────────────────────

Deno.test("key.create returns plaintext once and stores only hash", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.create",
    body: { name: "my key", scopes: ["notes.read"] },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 201);
  const data = await response!.json();
  assert(String(data.api_key).startsWith(JIBUN_API_KEY_PREFIX));
  assertEquals(data.key.name, "my key");
  assertEquals(data.key.scopes, ["notes.read"]);
  // ストアには平文が存在しない
  assertEquals(store.keys.length, 1);
  assert(store.keys[0].key_hash !== data.api_key);
  assertEquals(store.keys[0].key_hash, await sha256Hex(data.api_key));
  // list には hash も平文も含まれない
  const listResponse = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.list",
    body: {},
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  const listData = await listResponse!.json();
  assertEquals(listData.keys.length, 1);
  assertEquals(listData.keys[0].key_hash, undefined);
  assertEquals(listData.keys[0].api_key, undefined);
});

Deno.test("key.create rejects invalid scopes and enforces per-user limit", async () => {
  const store = new FakeJibunApiStore();
  const badScopes = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.create",
    body: { name: "k", scopes: ["superuser"] },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(badScopes!.status, 400);

  for (let i = 0; i < MAX_KEYS_PER_USER; i++) {
    await issueKey(store, "user-1", ["notes.read"]);
  }
  const overLimit = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.create",
    body: { name: "k11", scopes: ["notes.read"] },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(overLimit!.status, 409);
});

Deno.test("management actions require Supabase JWT", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.list",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 401);
});

Deno.test("key.revoke makes the key unusable", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read"]);
  const keyId = store.keys[0].id;
  const revokeResponse = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.key.revoke",
    body: { id: keyId },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(revokeResponse!.status, 200);
  const apiResponse = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(apiResponse!.status, 401);
});

Deno.test("worker.register validates endpoint and returns secret once", async () => {
  const store = new FakeJibunApiStore();
  const badEndpoint = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "w", endpoint_url: "http://example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(badEndpoint!.status, 400);

  const ssrf = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "w", endpoint_url: "https://192.168.1.10/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(ssrf!.status, 400);

  const ok = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: {
      name: "Summary Worker",
      endpoint_url: "https://example.com/hook",
      description: "test",
    },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(ok!.status, 201);
  const data = await ok!.json();
  assert(String(data.signing_secret).startsWith("jibun_whsec_"));
  assertEquals(data.worker.slug, "summary-worker");
  assertEquals(data.worker.signing_secret, undefined);

  // 同一 slug は 409
  const dup = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Summary Worker", endpoint_url: "https://example.com/h2" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(dup!.status, 409);
});

// ── 外部 API (api.*) ─────────────────────────────────────────────────────────

Deno.test("api.* rejects missing / malformed / unknown / expired keys", async () => {
  const store = new FakeJibunApiStore();
  const noAuth = await handleJibunApiAction({
    req: makeRequest(),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(noAuth!.status, 401);

  const wrongPrefix = await handleJibunApiAction({
    req: makeRequest({ bearer: "sk-something-else" }),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(wrongPrefix!.status, 401);

  const unknown = await handleJibunApiAction({
    req: makeRequest({ bearer: `${JIBUN_API_KEY_PREFIX}deadbeef` }),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(unknown!.status, 401);

  // 期限切れキー
  const key = await issueKey(store, "user-1", ["notes.read"]);
  store.keys[0].expires_at = new Date(Date.now() - 1000).toISOString();
  const expired = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(expired!.status, 401);
});

Deno.test("api.me returns key metadata without hash", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.me",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 200);
  const data = await response!.json();
  assertEquals(data.user_id, "user-1");
  assertEquals(data.key.key_hash, undefined);
  assert(typeof data.trace_id === "string");
});

Deno.test("scope enforcement: notes.read key cannot create notes", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read"]);
  const denied = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.create",
    body: { title: "t", content: "c" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(denied!.status, 403);
  const deniedData = await denied!.json();
  assertStringIncludes(String(deniedData.error), "notes.write");
});

Deno.test("api.notes.list / api.notes.create happy path + audit log", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read", "notes.write"]);
  const created = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.create",
    body: { title: "API経由メモ", content: "本文" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(created!.status, 201);
  const listed = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.list",
    body: { limit: 10 },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(listed!.status, 200);
  const data = await listed!.json();
  assertEquals(data.count, 1);
  assertEquals(data.notes[0].title, "API経由メモ");
  // audit log に両方の呼び出しが記録されている (key.create 分も含む)
  const apiCalls = store.auditLog.filter((row) =>
    row.action.startsWith("api.")
  );
  assertEquals(apiCalls.length, 2);
  assert(apiCalls.every((row) => row.api_key_id === store.keys[0].id));
});

Deno.test("api.notes.create input caps", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const noTitle = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.create",
    body: { title: "", content: "c" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(noTitle!.status, 400);
  const tooLong = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.create",
    body: { title: "t", content: "x".repeat(100_001) },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(tooLong!.status, 400);
});

Deno.test("rate limit returns 429 at per-minute threshold", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read"]);
  store.rateLimitCounts["*"] = API_RATE_LIMIT_PER_MINUTE;
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.list",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 429);
});

Deno.test("worker invoke: HMAC signed call + response passthrough", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["workers.invoke"]);
  await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Echo Worker", endpoint_url: "https://example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  const secret = store.workers[0].signing_secret;

  let capturedInit: RequestInit | null = null;
  let capturedUrl = "";
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "echo-worker", payload: { hello: "world" } },
    store,
    getUserId: () => Promise.resolve(null),
    resolveDns: (_host, type) =>
      Promise.resolve(type === "A" ? ["93.184.216.34"] : []),
    workerFetch: (input, init) => {
      capturedUrl = String(input);
      capturedInit = init;
      return Promise.resolve(
        new Response(JSON.stringify({ echoed: true }), { status: 200 }),
      );
    },
  });
  assertEquals(response!.status, 200);
  const data = await response!.json();
  assertEquals(data.success, true);
  assertEquals(data.worker_status, 200);
  assertEquals(data.result.echoed, true);
  assertEquals(capturedUrl, "https://example.com/hook");

  // HMAC 署名が送信ボディと一致する
  const init = capturedInit! as RequestInit;
  const headers = init.headers as Record<string, string>;
  const expected = await hmacSha256Hex(secret, String(init.body));
  assertEquals(headers["X-Jibun-Signature"], `sha256=${expected}`);
  assertEquals(headers["X-Jibun-Worker"], "echo-worker");
  const sentBody = JSON.parse(String(init.body));
  assertEquals(sentBody.payload.hello, "world");

  // invocation カウントが更新される
  assertEquals(store.workers[0].invocation_count, 1);
});

Deno.test("worker invoke: disabled worker / unknown slug / missing scope", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["workers.invoke"]);
  const noScope = await issueKey(store, "user-1", ["notes.read"]);
  await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Worker A", endpoint_url: "https://example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });

  const missing = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "nonexistent" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(missing!.status, 404);

  // スコープ不足は slug 検証より先に 403 を返す
  const scopeDenied = await handleJibunApiAction({
    req: makeRequest({ bearer: noScope }),
    action: "api.workers.invoke",
    body: { slug: "worker-a" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(scopeDenied!.status, 403);

  store.workers[0].enabled = false;
  const disabled = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "worker-a" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(disabled!.status, 403);
});

Deno.test("worker invoke: blocks endpoint resolving to private IP (DNS rebinding)", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["workers.invoke"]);
  await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Rebind", endpoint_url: "https://rebind.example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  let fetched = false;
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "rebind" },
    store,
    getUserId: () => Promise.resolve(null),
    // 公開ホスト名だが A レコードが内部 IP を指すケース
    resolveDns: (_host, type) =>
      Promise.resolve(type === "A" ? ["169.254.169.254"] : []),
    workerFetch: () => {
      fetched = true;
      return Promise.resolve(new Response("{}", { status: 200 }));
    },
  });
  assertEquals(response!.status, 400);
  assertEquals(fetched, false); // fetch は実行されない
});

Deno.test("worker invoke: fetch failure returns 504", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["workers.invoke"]);
  await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Down Worker", endpoint_url: "https://example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "down-worker" },
    store,
    getUserId: () => Promise.resolve(null),
    resolveDns: (_host, type) =>
      Promise.resolve(type === "A" ? ["93.184.216.34"] : []),
    workerFetch: () => Promise.reject(new Error("connection refused")),
  });
  assertEquals(response!.status, 504);
});

Deno.test("worker invoke rate limit (10/min) returns 429", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["workers.invoke"]);
  await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.worker.register",
    body: { name: "Worker A", endpoint_url: "https://example.com/hook" },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  store.rateLimitCounts["api.workers.invoke"] = WORKER_INVOKE_LIMIT_PER_MINUTE;
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.workers.invoke",
    body: { slug: "worker-a" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 429);
});

Deno.test("api.integrations.snapshot returns latest user-owned definitions", async () => {
  const store = new FakeJibunApiStore();
  store.integrationRows = [
    {
      id: "system-1",
      source: "integration_registry_system",
      metadata: {
        user_id: "user-1",
        system_key: "billing",
        name: "Billing old",
        version: 1,
      },
      created_at: "2026-07-22T00:00:00Z",
    },
    {
      id: "system-2",
      source: "integration_registry_system",
      metadata: {
        user_id: "user-1",
        system_key: "billing",
        name: "Billing",
        version: 2,
      },
      created_at: "2026-07-23T00:00:00Z",
    },
    {
      id: "interface-1",
      source: "integration_registry_interface",
      metadata: {
        user_id: "user-1",
        interface_key: "billing-ledger",
        name: "Journal export",
        version: 1,
      },
      created_at: "2026-07-23T00:00:00Z",
    },
    {
      id: "mapping-1",
      source: "integration_registry_mapping",
      metadata: {
        user_id: "user-1",
        mapping_key: "account-codes",
        name: "Account codes",
        version: 1,
        entries: [{ old_code: "100", new_code: "A100" }],
      },
      created_at: "2026-07-23T00:00:00Z",
    },
    {
      id: "other-user",
      source: "integration_registry_system",
      metadata: {
        user_id: "user-2",
        system_key: "private",
        name: "Private",
        version: 1,
      },
      created_at: "2026-07-23T00:00:00Z",
    },
  ];

  const key = await issueKey(store, "user-1", ["integrations.read"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.integrations.snapshot",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 200);
  const data = await response!.json();
  assertEquals(data.systems.length, 1);
  assertEquals(data.systems[0].version, 2);
  assertEquals(data.systems[0].name, "Billing");
  assertEquals(data.systems[0].user_id, undefined);
  assertEquals(data.mappings.length, 1);
  assertEquals(data.counts.mappings, 1);

  const filtered = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.integrations.snapshot",
    body: {
      interface_key: "Billing Ledger",
      mapping_key: "Account Codes",
    },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(filtered!.status, 200);
  const filteredData = await filtered!.json();
  assertEquals(filteredData.counts.interfaces, 1);
  assertEquals(filteredData.counts.mappings, 1);

  const deniedKey = await issueKey(store, "user-1", ["notes.read"]);
  const denied = await handleJibunApiAction({
    req: makeRequest({ bearer: deniedKey }),
    action: "api.integrations.snapshot",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(denied!.status, 403);
});

Deno.test("unknown api.* endpoint returns 404 with catalog", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.read"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.does.not.exist",
    body: {},
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 404);
  const data = await response!.json();
  assert(Array.isArray(data.available_actions));
});

Deno.test("non-jibun actions return null (fall through to other handlers)", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "bookmark.list",
    body: {},
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response, null);
});

Deno.test("scope catalog is stable (docs contract)", () => {
  assertEquals([...JIBUN_API_SCOPES], [
    "notes.read",
    "notes.write",
    "tasks.read",
    "achievements.read",
    "integrations.read",
    "workers.invoke",
  ]);
});

// ── Notes CRUD (api.notes.update / api.notes.delete) ─────────────────────────

Deno.test("api.notes.update patches title and content", async () => {
  const store = new FakeJibunApiStore();
  const note = await store.createNote("user-1", {
    title: "original",
    content: "body",
  });
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.update",
    body: { id: note.id, title: "updated" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 200);
  const data = await response!.json();
  assertEquals(data.note.title, "updated");
  assertEquals(data.note.content, "body");
  assert(data.note.updated_at !== null);
});

Deno.test("api.notes.update requires notes.write scope", async () => {
  const store = new FakeJibunApiStore();
  const note = await store.createNote("user-1", { title: "t", content: "" });
  const key = await issueKey(store, "user-1", ["notes.read"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.update",
    body: { id: note.id, title: "x" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 403);
});

Deno.test("api.notes.update returns 404 for missing note", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.update",
    body: { id: 9999, title: "x" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 404);
});

Deno.test("api.notes.update rejects missing id", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.update",
    body: { title: "x" },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 400);
});

Deno.test("api.notes.delete removes note", async () => {
  const store = new FakeJibunApiStore();
  const note = await store.createNote("user-1", { title: "bye", content: "" });
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.delete",
    body: { id: note.id },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 200);
  assertEquals(store.notes.length, 0);
});

Deno.test("api.notes.delete returns 404 for missing note", async () => {
  const store = new FakeJibunApiStore();
  const key = await issueKey(store, "user-1", ["notes.write"]);
  const response = await handleJibunApiAction({
    req: makeRequest({ bearer: key }),
    action: "api.notes.delete",
    body: { id: 9999 },
    store,
    getUserId: () => Promise.resolve(null),
  });
  assertEquals(response!.status, 404);
});

// ── Webhook management (jibunapi.webhook.*) ──────────────────────────────────

Deno.test("webhook.create registers webhook and returns signing_secret once", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.create",
    body: {
      name: "my hook",
      endpoint_url: "https://hooks.example.com/jibun",
      events: ["note.created"],
    },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 201);
  const data = await response!.json();
  assert(typeof data.signing_secret === "string");
  assert(data.signing_secret.startsWith("jibun_whsec_"));
  assertEquals(data.webhook.name, "my hook");
  assertEquals(data.webhook.events, ["note.created"]);
  // signing_secret は webhook オブジェクト内には含まれない (once-only)
  assertEquals(data.webhook.signing_secret, undefined);
  assertEquals(store.webhooks.length, 1);
});

Deno.test("webhook.create rejects invalid event", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.create",
    body: {
      name: "bad",
      endpoint_url: "https://hooks.example.com/",
      events: ["unknown.event"],
    },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 400);
});

Deno.test("webhook.create rejects private endpoint (SSRF guard)", async () => {
  const store = new FakeJibunApiStore();
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.create",
    body: {
      name: "ssrf",
      endpoint_url: "https://192.168.1.1/hook",
      events: ["note.created"],
    },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 400);
});

Deno.test("webhook.create enforces MAX_WEBHOOKS_PER_USER", async () => {
  const store = new FakeJibunApiStore();
  for (let i = 0; i < MAX_WEBHOOKS_PER_USER; i++) {
    await store.insertWebhook({
      user_id: "user-1",
      name: `hook-${i}`,
      endpoint_url: "https://hooks.example.com/",
      signing_secret: "jibun_whsec_x",
      events: ["note.created"],
      enabled: true,
    });
  }
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.create",
    body: {
      name: "overflow",
      endpoint_url: "https://hooks.example.com/overflow",
      events: ["note.created"],
    },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 409);
});

Deno.test("webhook.list returns only user's webhooks (no secret)", async () => {
  const store = new FakeJibunApiStore();
  await store.insertWebhook({
    user_id: "user-1",
    name: "h1",
    endpoint_url: "https://a.example.com/",
    signing_secret: "jibun_whsec_secret",
    events: ["note.created"],
    enabled: true,
  });
  await store.insertWebhook({
    user_id: "user-2",
    name: "h2",
    endpoint_url: "https://b.example.com/",
    signing_secret: "jibun_whsec_other",
    events: ["note.deleted"],
    enabled: true,
  });
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.list",
    body: {},
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 200);
  const data = await response!.json();
  assertEquals(data.webhooks.length, 1);
  assertEquals(data.webhooks[0].name, "h1");
  assertEquals(data.webhooks[0].signing_secret, undefined);
});

Deno.test("webhook.delete removes own webhook", async () => {
  const store = new FakeJibunApiStore();
  const wh = await store.insertWebhook({
    user_id: "user-1",
    name: "gone",
    endpoint_url: "https://hooks.example.com/",
    signing_secret: "jibun_whsec_x",
    events: ["note.created"],
    enabled: true,
  });
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.delete",
    body: { id: wh.id },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 200);
  assertEquals(store.webhooks.length, 0);
});

Deno.test("webhook.delete returns 404 for missing / other-user webhook", async () => {
  const store = new FakeJibunApiStore();
  await store.insertWebhook({
    user_id: "user-2",
    name: "other",
    endpoint_url: "https://hooks.example.com/",
    signing_secret: "jibun_whsec_x",
    events: ["note.created"],
    enabled: true,
  });
  const response = await handleJibunApiAction({
    req: makeRequest(),
    action: "jibunapi.webhook.delete",
    body: { id: store.webhooks[0].id },
    store,
    getUserId: () => Promise.resolve("user-1"),
  });
  assertEquals(response!.status, 404);
});
