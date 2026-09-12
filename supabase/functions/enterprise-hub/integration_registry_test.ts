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
    const row: IntegrationRegistryRow = {
      id: `row-${this.nextId++}`,
      source,
      metadata: { ...metadata, user_id: userId },
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
