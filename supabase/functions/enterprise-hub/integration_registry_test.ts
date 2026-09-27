import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildIntegrationImpactReport,
  buildIntegrationRegistrySnapshot,
  handleIntegrationRegistryAction,
  INTEGRATION_REGISTRY_SOURCES,
  type IntegrationRegistryRow,
  type IntegrationRegistrySource,
  type IntegrationRegistryStore,
  normalizeRegistryKey,
} from "./integration_registry.ts";

class FakeIntegrationRegistryStore implements IntegrationRegistryStore {
  rows: IntegrationRegistryRow[];
  nextId = 1;

  constructor(rows: IntegrationRegistryRow[] = []) {
    this.rows = [...rows];
  }

  list(userId: string): Promise<IntegrationRegistryRow[]> {
    return Promise.resolve(
      this.rows.filter((row) => row.metadata.user_id === userId),
    );
  }

  insert(
    source: IntegrationRegistrySource,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<IntegrationRegistryRow> {
    const keyField = source === INTEGRATION_REGISTRY_SOURCES.system
      ? "system_key"
      : source === INTEGRATION_REGISTRY_SOURCES.interface
      ? "interface_key"
      : "mapping_key";
    const version = this.rows.filter((item) =>
      item.source === source && item.metadata.user_id === userId &&
      item.metadata[keyField] === metadata[keyField]
    ).reduce((max, item) => Math.max(max, Number(item.metadata.version)), 0) + 1;
    const row: IntegrationRegistryRow = {
      id: `row-${this.nextId++}`,
      source,
      metadata: { ...metadata, user_id: userId, version },
      created_at: `2026-07-23T00:00:0${this.nextId}Z`,
    };
    this.rows.push(row);
    return Promise.resolve(row);
  }
}

function row(
  id: string,
  source: IntegrationRegistrySource,
  metadata: Record<string, unknown>,
): IntegrationRegistryRow {
  return {
    id,
    source,
    metadata: { ...metadata, user_id: "user-1" },
    created_at: "2026-07-23T00:00:00Z",
  };
}

Deno.test("normalizeRegistryKey produces stable API-safe keys", () => {
  assertEquals(normalizeRegistryKey(" Core Billing / v2 "), "core-billing-v2");
  assertEquals(normalizeRegistryKey("___"), "___");
  assertEquals(normalizeRegistryKey(""), "");
});

Deno.test("snapshot keeps full history and selects the latest version", () => {
  const snapshot = buildIntegrationRegistrySnapshot([
    row("system-1", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "billing",
      name: "Billing old",
      version: 1,
    }),
    row("system-2", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "billing",
      name: "Billing",
      version: 2,
    }),
    row("interface-1", INTEGRATION_REGISTRY_SOURCES.interface, {
      interface_key: "billing-to-ledger",
      source_system_key: "billing",
      target_system_key: "ledger",
      version: 1,
    }),
  ]);

  assertEquals(snapshot.system_versions.length, 2);
  assertEquals(snapshot.systems.length, 1);
  assertEquals(snapshot.systems[0].name, "Billing");
  assertEquals(snapshot.interfaces.length, 1);
});

Deno.test("publish interface validates systems and increments version", async () => {
  const store = new FakeIntegrationRegistryStore([
    row("system-1", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "billing",
      name: "Billing",
      version: 1,
    }),
    row("system-2", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "ledger",
      name: "Ledger",
      version: 1,
    }),
    row("interface-1", INTEGRATION_REGISTRY_SOURCES.interface, {
      interface_key: "billing-ledger",
      name: "Journal export",
      source_system_key: "billing",
      target_system_key: "ledger",
      fields: [],
      version: 1,
    }),
  ]);

  const response = await handleIntegrationRegistryAction({
    action: "integration.registry.interface.publish",
    userId: "user-1",
    store,
    body: {
      interface_key: "billing-ledger",
      name: "Journal export",
      source_system_key: "billing",
      target_system_key: "ledger",
      protocol: "SFTP",
      format: "CSV",
      fields: [
        { name: "journal_code", data_type: "string", required: true },
      ],
    },
  });

  assertEquals(response?.status, 201);
  const data = await response!.json();
  assertEquals(data.interface.version, 2);
  assertEquals(data.interface.fields[0].name, "journal_code");

  const missing = await handleIntegrationRegistryAction({
    action: "integration.registry.interface.publish",
    userId: "user-1",
    store,
    body: {
      name: "Unknown target",
      source_system_key: "billing",
      target_system_key: "missing",
    },
  });
  assertEquals(missing?.status, 409);
});

Deno.test("publish interface rejects field lists above the limit", async () => {
  const store = new FakeIntegrationRegistryStore([
    row("system-1", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "billing",
      name: "Billing",
      version: 1,
    }),
    row("system-2", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "ledger",
      name: "Ledger",
      version: 1,
    }),
  ]);

  const response = await handleIntegrationRegistryAction({
    action: "integration.registry.interface.publish",
    userId: "user-1",
    store,
    body: {
      interface_key: "billing-ledger",
      name: "Journal export",
      source_system_key: "billing",
      target_system_key: "ledger",
      fields: Array.from({ length: 101 }, (_, index) => ({
        name: `field-${index}`,
      })),
    },
  });

  assertEquals(response?.status, 400);
  assertEquals((await response!.json()).received, 101);
});

Deno.test("mapping import removes invalid and duplicate entries", async () => {
  const store = new FakeIntegrationRegistryStore([
    row("system-1", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "legacy",
      name: "Legacy",
      version: 1,
    }),
    row("system-2", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "next",
      name: "Next",
      version: 1,
    }),
  ]);

  const response = await handleIntegrationRegistryAction({
    action: "integration.registry.mapping.import",
    userId: "user-1",
    store,
    body: {
      mapping_key: "account-codes",
      name: "Account codes",
      source_system_key: "legacy",
      target_system_key: "next",
      entries: [
        { old_code: "100", new_code: "A100" },
        { old_code: "100", new_code: "A100" },
        { old_code: "", new_code: "A200" },
      ],
    },
  });

  assertEquals(response?.status, 201);
  const data = await response!.json();
  assertEquals(data.mapping.entry_count, 1);
  assertEquals(data.mapping.entries[0].new_code, "A100");
});

Deno.test("mapping import rejects entry lists above the limit", async () => {
  const store = new FakeIntegrationRegistryStore([
    row("system-1", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "legacy",
      name: "Legacy",
      version: 1,
    }),
    row("system-2", INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: "next",
      name: "Next",
      version: 1,
    }),
  ]);

  const response = await handleIntegrationRegistryAction({
    action: "integration.registry.mapping.import",
    userId: "user-1",
    store,
    body: {
      mapping_key: "account-codes",
      name: "Account codes",
      source_system_key: "legacy",
      target_system_key: "next",
      entries: Array.from({ length: 2_001 }, (_, index) => ({
        old_code: String(index),
        new_code: `A${index}`,
      })),
    },
  });

  assertEquals(response?.status, 400);
  assertEquals((await response!.json()).received, 2_001);
});

Deno.test("impact report follows transitive system dependencies", () => {
  const systems = ["a", "b", "c", "isolated"].map((key, index) =>
    row(`system-${index}`, INTEGRATION_REGISTRY_SOURCES.system, {
      system_key: key,
      name: key.toUpperCase(),
      version: 1,
    })
  );
  const snapshot = buildIntegrationRegistrySnapshot([
    ...systems,
    row("interface-ab", INTEGRATION_REGISTRY_SOURCES.interface, {
      interface_key: "a-b",
      source_system_key: "a",
      target_system_key: "b",
      version: 1,
    }),
    row("mapping-bc", INTEGRATION_REGISTRY_SOURCES.mapping, {
      mapping_key: "b-c",
      source_system_key: "b",
      target_system_key: "c",
      version: 1,
      entries: [],
    }),
    row("interface-a-isolated", INTEGRATION_REGISTRY_SOURCES.interface, {
      interface_key: "a-isolated",
      source_system_key: "a",
      target_system_key: "isolated",
      status: "deprecated",
      version: 1,
    }),
  ]);

  const impact = buildIntegrationImpactReport(snapshot, "a");
  const affected = impact.systems as Record<string, unknown>[];
  assertEquals(
    affected.map((item) => item.system_key),
    ["a", "b", "c"],
  );
  assertEquals(affected.map((item) => item.distance), [0, 1, 2]);
  assertEquals(
    (impact.interfaces as Record<string, unknown>[]).map((item) =>
      item.interface_key
    ),
    ["a-b"],
  );
  assertExists(impact.counts);
});

Deno.test("registry store retains history beyond 5000 rows and short pages", async () => {
  const { createSupabaseIntegrationRegistryStore } = await import("./integration_registry.ts");
  const history = Array.from({ length: 5002 }, (_, index) => ({
    id: String(index).padStart(8, "0"),
    source: "integration_registry_system",
    metadata: { user_id: "owner", system_key: `key-${index}`, version: 1 },
    created_at: "2026-01-01T00:00:00Z",
  }));
  let pages = 0;
  const admin = {
    from(table: string) {
      assertEquals(table, "hub_data");
      let cursor = "";
      const query = {
        select(_columns: string) { return query; },
        in(_column: string, _sources: string[]) { return query; },
        filter(column: string, op: string, user: string) {
          assertEquals([column, op, user], ["metadata->>user_id", "eq", "owner"]);
          return query;
        },
        order(column: string, options: { ascending: boolean }) {
          assertEquals([column, options.ascending], ["id", true]);
          return query;
        },
        gt(column: string, value: string) {
          assertEquals(column, "id"); cursor = value; return query;
        },
        limit(_size: number) {
          pages++;
          return Promise.resolve({ data: history.filter((r) => r.id > cursor).slice(0, 137), error: null });
        },
      };
      return query;
    },
  } as unknown as Parameters<typeof createSupabaseIntegrationRegistryStore>[0];
  const result = await createSupabaseIntegrationRegistryStore(admin).list("owner");
  assertEquals(result.length, 5002);
  assertEquals(result[0].id, "00000000");
  assertEquals(result[5001].id, "00005001");
  assertEquals(pages, 38);
});

Deno.test("registry store uses only the atomic RPC and preserves server errors", async () => {
  const { createSupabaseIntegrationRegistryStore } = await import("./integration_registry.ts");
  const calls: unknown[] = [];
  const admin = {
    rpc(name: string, args: unknown) {
      calls.push([name, args]);
      return { single: () => Promise.resolve({ data: null, error: { message: "migration required" } }) };
    },
    from() { throw new Error("Unsafe direct-table fallback"); },
  } as unknown as Parameters<typeof createSupabaseIntegrationRegistryStore>[0];
  let message = "";
  try {
    await createSupabaseIntegrationRegistryStore(admin).insert(
      INTEGRATION_REGISTRY_SOURCES.system, "verified-owner", { system_key: "billing" },
    );
  } catch (error) { message = (error as Error).message; }
  assertEquals(message, "migration required");
  assertEquals(calls, [["insert_integration_registry_version", {
    p_source: INTEGRATION_REGISTRY_SOURCES.system,
    p_user_id: "verified-owner", p_metadata: { system_key: "billing" },
  }]]);
});
