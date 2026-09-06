import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const INTEGRATION_REGISTRY_SOURCES = {
  system: "integration_registry_system",
  interface: "integration_registry_interface",
  mapping: "integration_registry_mapping",
} as const;

export type IntegrationRegistrySource = (typeof INTEGRATION_REGISTRY_SOURCES)[
  keyof typeof INTEGRATION_REGISTRY_SOURCES
];

export interface IntegrationRegistryRow {
  id: string;
  source: IntegrationRegistrySource;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface IntegrationRegistryStore {
  list(userId: string): Promise<IntegrationRegistryRow[]>;
  insert(
    source: IntegrationRegistrySource,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<IntegrationRegistryRow>;
}

export interface IntegrationRegistrySnapshot {
  systems: Record<string, unknown>[];
  system_versions: Record<string, unknown>[];
  interfaces: Record<string, unknown>[];
  interface_versions: Record<string, unknown>[];
  mappings: Record<string, unknown>[];
  mapping_versions: Record<string, unknown>[];
}

const JSON_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const MAX_FIELDS = 100;
const MAX_MAPPING_ENTRIES = 2_000;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: JSON_HEADERS,
  });
}

function text(value: unknown, fallback = ""): string {
  if (value === null || value === undefined) return fallback;
  return String(value).trim();
}

function boundedText(value: unknown, maxLength: number): string {
  return text(value).slice(0, maxLength);
}

function integer(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : fallback;
}

export function normalizeRegistryKey(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function rowItem(row: IntegrationRegistryRow): Record<string, unknown> {
  const metadata = { ...row.metadata };
  delete metadata.user_id;
  return {
    ...metadata,
    id: row.id,
    created_at: row.created_at,
  };
}

function rowsFor(
  rows: IntegrationRegistryRow[],
  source: IntegrationRegistrySource,
): Record<string, unknown>[] {
  return rows
    .filter((row) => row.source === source)
    .map(rowItem)
    .sort((a, b) => {
      const byKey = text(a.system_key ?? a.interface_key ?? a.mapping_key)
        .localeCompare(
          text(b.system_key ?? b.interface_key ?? b.mapping_key),
        );
      if (byKey !== 0) return byKey;
      return integer(b.version) - integer(a.version);
    });
}

function latestByKey(
  items: Record<string, unknown>[],
  keyField: string,
): Record<string, unknown>[] {
  const latest = new Map<string, Record<string, unknown>>();
  for (const item of items) {
    const key = text(item[keyField]);
    if (key === "") continue;
    const current = latest.get(key);
    if (!current || integer(item.version) > integer(current.version)) {
      latest.set(key, item);
    }
  }
  return [...latest.values()].sort((a, b) =>
    text(a[keyField]).localeCompare(text(b[keyField]))
  );
}

export function buildIntegrationRegistrySnapshot(
  rows: IntegrationRegistryRow[],
): IntegrationRegistrySnapshot {
  const systemVersions = rowsFor(
    rows,
    INTEGRATION_REGISTRY_SOURCES.system,
  );
  const interfaceVersions = rowsFor(
    rows,
    INTEGRATION_REGISTRY_SOURCES.interface,
  );
  const mappingVersions = rowsFor(
    rows,
    INTEGRATION_REGISTRY_SOURCES.mapping,
  );
  return {
    systems: latestByKey(systemVersions, "system_key"),
    system_versions: systemVersions,
    interfaces: latestByKey(interfaceVersions, "interface_key"),
    interface_versions: interfaceVersions,
    mappings: latestByKey(mappingVersions, "mapping_key"),
    mapping_versions: mappingVersions,
  };
}

function nextVersion(
  items: Record<string, unknown>[],
  keyField: string,
  key: string,
): number {
  return items
    .filter((item) => text(item[keyField]) === key)
    .reduce((max, item) => Math.max(max, integer(item.version)), 0) + 1;
}

function sanitizeFields(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const field = raw && typeof raw === "object"
      ? raw as Record<string, unknown>
      : {};
    return {
      name: boundedText(field.name, 100),
      data_type: boundedText(field.data_type, 60) || "string",
      required: field.required === true,
      description: boundedText(field.description, 300),
    };
  }).filter((field) => field.name !== "");
}

function sanitizeMappingEntries(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const entries: Record<string, unknown>[] = [];
  for (const raw of value) {
    const item = raw && typeof raw === "object"
      ? raw as Record<string, unknown>
      : {};
    const oldCode = boundedText(
      item.old_code ?? item.source_code,
      200,
    );
    const newCode = boundedText(
      item.new_code ?? item.target_code,
      200,
    );
    if (oldCode === "" || newCode === "") continue;
    const duplicateKey = `${oldCode}\u0000${newCode}`;
    if (seen.has(duplicateKey)) continue;
    seen.add(duplicateKey);
    entries.push({
      old_code: oldCode,
      new_code: newCode,
      description: boundedText(item.description, 500),
      active: item.active !== false,
    });
  }
  return entries;
}

function connectedKeys(
  item: Record<string, unknown>,
): [string, string] | null {
  const source = text(item.source_system_key);
  const target = text(item.target_system_key);
  return source !== "" && target !== "" ? [source, target] : null;
}

export function buildIntegrationImpactReport(
  snapshot: IntegrationRegistrySnapshot,
  rootSystemKey: string,
): Record<string, unknown> {
  const root = normalizeRegistryKey(rootSystemKey);
  const adjacency = new Map<string, Set<string>>();
  const addEdge = (from: string, to: string) => {
    if (!adjacency.has(from)) adjacency.set(from, new Set());
    adjacency.get(from)!.add(to);
  };

  const activeInterfaces = snapshot.interfaces.filter((item) =>
    text(item.status, "active").toLowerCase() === "active"
  );
  const activeMappings = snapshot.mappings.filter((item) =>
    text(item.status, "active").toLowerCase() === "active"
  );

  for (const item of [...activeInterfaces, ...activeMappings]) {
    const endpoints = connectedKeys(item);
    if (!endpoints) continue;
    addEdge(endpoints[0], endpoints[1]);
    addEdge(endpoints[1], endpoints[0]);
  }

  const distances = new Map<string, number>([[root, 0]]);
  const queue = [root];
  while (queue.length > 0) {
    const current = queue.shift()!;
    const nextDistance = (distances.get(current) ?? 0) + 1;
    for (const neighbor of adjacency.get(current) ?? []) {
      if (distances.has(neighbor)) continue;
      distances.set(neighbor, nextDistance);
      queue.push(neighbor);
    }
  }

  const affectedSystemKeys = [...distances.keys()];
  const affectedSet = new Set(affectedSystemKeys);
  const affectedInterfaces = activeInterfaces.filter((item) => {
    const endpoints = connectedKeys(item);
    return endpoints &&
      (affectedSet.has(endpoints[0]) || affectedSet.has(endpoints[1]));
  });
  const affectedMappings = activeMappings.filter((item) => {
    const endpoints = connectedKeys(item);
    return endpoints &&
      (affectedSet.has(endpoints[0]) || affectedSet.has(endpoints[1]));
  });
  const affectedSystems: Record<string, unknown>[] = snapshot.systems
    .filter((item) => affectedSet.has(text(item.system_key)))
    .map((item): Record<string, unknown> => ({
      ...item,
      distance: distances.get(text(item.system_key)) ?? 0,
    }))
    .sort((a, b) =>
      integer(a.distance) - integer(b.distance) ||
      text(a.system_key).localeCompare(text(b.system_key))
    );

  return {
    root_system_key: root,
    systems: affectedSystems,
    interfaces: affectedInterfaces,
    mappings: affectedMappings,
    counts: {
      systems: affectedSystems.length,
      interfaces: affectedInterfaces.length,
      mappings: affectedMappings.length,
    },
  };
}

export function createSupabaseIntegrationRegistryStore(
  admin: SupabaseClient,
): IntegrationRegistryStore {
  return {
    async list(userId) {
      const { data, error } = await admin.from("hub_data")
        .select("id, source, metadata, created_at")
        .in("source", Object.values(INTEGRATION_REGISTRY_SOURCES))
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(5_000);
      if (error) throw new Error(error.message);
      return (data ?? []) as IntegrationRegistryRow[];
    },
    async insert(source, userId, metadata) {
      const { data, error } = await admin.from("hub_data")
        .insert({
          source,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, source, metadata, created_at")
        .single();
      if (error) throw new Error(error.message);
      return data as IntegrationRegistryRow;
    },
  };
}

export async function handleIntegrationRegistryAction(
  deps: {
    action: string;
    body: Record<string, unknown>;
    userId: string;
    store: IntegrationRegistryStore;
  },
): Promise<Response | null> {
  if (!deps.action.startsWith("integration.registry.")) return null;

  const rows = await deps.store.list(deps.userId);
  const snapshot = buildIntegrationRegistrySnapshot(rows);

  switch (deps.action) {
    case "integration.registry.snapshot":
      return json({ success: true, ...snapshot });

    case "integration.registry.system.save": {
      const name = boundedText(deps.body.name, 120);
      const systemKey = normalizeRegistryKey(
        deps.body.system_key ?? name,
      );
      if (name === "" || systemKey === "") {
        return json({ error: "name and system_key are required" }, 400);
      }
      const version = nextVersion(
        snapshot.system_versions,
        "system_key",
        systemKey,
      );
      const row = await deps.store.insert(
        INTEGRATION_REGISTRY_SOURCES.system,
        deps.userId,
        {
          system_key: systemKey,
          name,
          description: boundedText(deps.body.description, 1_000),
          owner: boundedText(deps.body.owner, 120),
          status: boundedText(deps.body.status, 30) || "active",
          version,
          published_at: new Date().toISOString(),
        },
      );
      return json({ success: true, system: rowItem(row) }, 201);
    }

    case "integration.registry.interface.publish": {
      const name = boundedText(deps.body.name, 160);
      const sourceKey = normalizeRegistryKey(deps.body.source_system_key);
      const targetKey = normalizeRegistryKey(deps.body.target_system_key);
      const interfaceKey = normalizeRegistryKey(
        deps.body.interface_key ?? `${sourceKey}-${targetKey}-${name}`,
      );
      if (
        name === "" || interfaceKey === "" || sourceKey === "" ||
        targetKey === ""
      ) {
        return json({
          error:
            "name, interface_key, source_system_key, and target_system_key are required",
        }, 400);
      }
      const knownSystems = new Set(
        snapshot.systems.map((item) => text(item.system_key)),
      );
      if (!knownSystems.has(sourceKey) || !knownSystems.has(targetKey)) {
        return json({
          error: "source_system_key and target_system_key must exist",
        }, 409);
      }
      if (
        Array.isArray(deps.body.fields) &&
        deps.body.fields.length > MAX_FIELDS
      ) {
        return json({
          error: `fields supports at most ${MAX_FIELDS} entries`,
          received: deps.body.fields.length,
        }, 400);
      }
      const fields = sanitizeFields(deps.body.fields);
      const version = nextVersion(
        snapshot.interface_versions,
        "interface_key",
        interfaceKey,
      );
      const row = await deps.store.insert(
        INTEGRATION_REGISTRY_SOURCES.interface,
        deps.userId,
        {
          interface_key: interfaceKey,
          name,
          source_system_key: sourceKey,
          target_system_key: targetKey,
          direction: boundedText(deps.body.direction, 30) || "outbound",
          protocol: boundedText(deps.body.protocol, 80) || "REST",
          format: boundedText(deps.body.format, 80) || "JSON",
          description: boundedText(deps.body.description, 1_000),
          status: boundedText(deps.body.status, 30) || "active",
          fields,
          version,
          published_at: new Date().toISOString(),
        },
      );
      return json({ success: true, interface: rowItem(row) }, 201);
    }

    case "integration.registry.mapping.import": {
      const name = boundedText(deps.body.name, 160);
      const sourceKey = normalizeRegistryKey(deps.body.source_system_key);
      const targetKey = normalizeRegistryKey(deps.body.target_system_key);
      const mappingKey = normalizeRegistryKey(
        deps.body.mapping_key ?? `${sourceKey}-${targetKey}-${name}`,
      );
      if (
        Array.isArray(deps.body.entries) &&
        deps.body.entries.length > MAX_MAPPING_ENTRIES
      ) {
        return json({
          error: `entries supports at most ${MAX_MAPPING_ENTRIES} entries`,
          received: deps.body.entries.length,
        }, 400);
      }
      const entries = sanitizeMappingEntries(deps.body.entries);
      if (
        name === "" || mappingKey === "" || sourceKey === "" ||
        targetKey === "" || entries.length === 0
      ) {
        return json({
          error:
            "name, mapping_key, source_system_key, target_system_key, and entries are required",
        }, 400);
      }
      const knownSystems = new Set(
        snapshot.systems.map((item) => text(item.system_key)),
      );
      if (!knownSystems.has(sourceKey) || !knownSystems.has(targetKey)) {
        return json({
          error: "source_system_key and target_system_key must exist",
        }, 409);
      }
      const version = nextVersion(
        snapshot.mapping_versions,
        "mapping_key",
        mappingKey,
      );
      const row = await deps.store.insert(
        INTEGRATION_REGISTRY_SOURCES.mapping,
        deps.userId,
        {
          mapping_key: mappingKey,
          name,
          source_system_key: sourceKey,
          target_system_key: targetKey,
          description: boundedText(deps.body.description, 1_000),
          entries,
          entry_count: entries.length,
          version,
          published_at: new Date().toISOString(),
        },
      );
      return json({ success: true, mapping: rowItem(row) }, 201);
    }

    case "integration.registry.impact": {
      const systemKey = normalizeRegistryKey(deps.body.system_key);
      if (systemKey === "") {
        return json({ error: "system_key is required" }, 400);
      }
      if (
        !snapshot.systems.some((item) => text(item.system_key) === systemKey)
      ) {
        return json({ error: "system not found" }, 404);
      }
      return json({
        success: true,
        impact: buildIntegrationImpactReport(snapshot, systemKey),
      });
    }

    default:
      return json({
        error: `Unknown integration registry action: ${deps.action}`,
      }, 400);
  }
}
