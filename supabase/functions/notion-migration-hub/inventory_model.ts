export const NOTION_MIGRATION_API_VERSION = "2026-03-11";

export type NotionObject = Record<string, unknown>;

export type NotionInventoryRow = {
  batch_id: string;
  user_id: string;
  source_id: string;
  parent_source_id: string | null;
  source_kind: string;
  title: string;
  source_path: string;
  source_updated_at: string | null;
  metadata: Record<string, unknown>;
};

export function asNotionRecord(value: unknown): NotionObject | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as NotionObject
    : null;
}

export function notionDurablePayload(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(notionDurablePayload);
  const record = asNotionRecord(value);
  if (!record) return value;

  const hasExpiringUrl = typeof record.expiry_time === "string" &&
    typeof record.url === "string";
  return Object.fromEntries(
    Object.entries(record)
      .filter(([key]) => !(hasExpiringUrl && key === "url"))
      .map(([key, child]) => [key, notionDurablePayload(child)]),
  );
}

export function notionPlainText(value: unknown): string {
  if (!Array.isArray(value)) return "";
  return value.map((entry) => {
    const record = asNotionRecord(entry);
    if (!record) return "";
    if (typeof record.plain_text === "string") return record.plain_text;
    const text = asNotionRecord(record.text);
    return typeof text?.content === "string" ? text.content : "";
  }).join("").trim();
}

export function notionObjectTitle(object: NotionObject): string {
  if (typeof object.name === "string" && object.name.trim()) {
    return object.name.trim().slice(0, 1000);
  }
  const directTitle = notionPlainText(object.title);
  if (directTitle) return directTitle.slice(0, 1000);

  const properties = asNotionRecord(object.properties);
  if (properties) {
    for (const value of Object.values(properties)) {
      const property = asNotionRecord(value);
      if (!property || property.type !== "title") continue;
      const title = notionPlainText(property.title);
      if (title) return title.slice(0, 1000);
    }
  }

  const childPage = asNotionRecord(object.child_page);
  if (typeof childPage?.title === "string" && childPage.title.trim()) {
    return childPage.title.trim().slice(0, 1000);
  }
  const childDatabase = asNotionRecord(object.child_database);
  if (
    typeof childDatabase?.title === "string" && childDatabase.title.trim()
  ) {
    return childDatabase.title.trim().slice(0, 1000);
  }

  const type = typeof object.type === "string" ? object.type : "item";
  return `${type} ${String(object.id ?? "").slice(0, 8)}`.trim();
}

export function notionSourceKind(object: NotionObject): string {
  if (object.type === "child_page") return "page";
  if (object.type === "child_database") return "database";
  const objectType = String(object.object ?? object.type ?? "block");
  if (objectType === "data_source") return "data_source";
  if (objectType === "database" || objectType === "child_database") {
    return "database";
  }
  if (objectType === "page" || objectType === "child_page") return "page";
  if (objectType === "comment") return "comment";
  if (objectType === "user") return "user";
  if (objectType === "view") return object.type === "form" ? "form" : "view";
  return "block";
}

export function notionSourceId(kind: string, rawId: unknown): string {
  return `${kind}:${String(rawId ?? "").trim()}`;
}

export function notionParentSourceId(object: NotionObject): string | null {
  const parent = asNotionRecord(object.parent);
  if (!parent) return null;
  const type = String(parent.type ?? "");
  const rawId = parent[type];
  if (!rawId) return type === "workspace" ? "workspace:root" : null;
  const prefix = type.replace(/_id$/, "");
  return notionSourceId(prefix, rawId);
}

export function notionInventoryRow(args: {
  batchId: string;
  userId: string;
  object: NotionObject;
  seenAt: string;
  parentSourceId?: string | null;
}): NotionInventoryRow | null {
  const rawId = String(args.object.id ?? "").trim();
  if (!rawId) return null;
  const sourceKind = notionSourceKind(args.object);
  const title = notionObjectTitle(args.object);
  const properties = asNotionRecord(args.object.properties);
  return {
    batch_id: args.batchId,
    user_id: args.userId,
    source_id: notionSourceId(sourceKind, rawId),
    parent_source_id: args.parentSourceId === undefined
      ? notionParentSourceId(args.object)
      : args.parentSourceId,
    source_kind: sourceKind,
    title,
    source_path: title,
    source_updated_at: typeof args.object.last_edited_time === "string"
      ? args.object.last_edited_time
      : null,
    metadata: {
      notion_object: String(args.object.object ?? args.object.type ?? ""),
      notion_type: String(args.object.type ?? ""),
      created_time: args.object.created_time ?? null,
      in_trash: args.object.in_trash === true,
      has_children: args.object.has_children === true,
      property_names: properties ? Object.keys(properties) : [],
      inventory_expanded: sourceKind === "page" ||
          sourceKind === "data_source" || sourceKind === "database"
        ? false
        : true,
      inventory_seen_at: args.seenAt,
      api_version: NOTION_MIGRATION_API_VERSION,
    },
  };
}

export function notionAttachmentRows(args: {
  batchId: string;
  userId: string;
  block: NotionObject;
  seenAt: string;
}): NotionInventoryRow[] {
  const blockId = String(args.block.id ?? "").trim();
  const blockType = String(args.block.type ?? "");
  if (!blockId || !notionFileBlockTypes.has(blockType)) return [];
  const payload = asNotionRecord(args.block[blockType]);
  if (!payload) return [];

  const file = asNotionRecord(payload.file) ?? asNotionRecord(payload.external);
  const caption = notionPlainText(payload.caption);
  const title = typeof payload.name === "string" && payload.name.trim()
    ? payload.name.trim()
    : caption || `${blockType} attachment`;
  return [{
    batch_id: args.batchId,
    user_id: args.userId,
    source_id: notionSourceId("attachment", blockId),
    parent_source_id: notionSourceId("block", blockId),
    source_kind: "attachment",
    title: title.slice(0, 1000),
    source_path: title.slice(0, 1000),
    source_updated_at: typeof args.block.last_edited_time === "string"
      ? args.block.last_edited_time
      : null,
    metadata: {
      media_type: blockType,
      source_type: payload.type ?? (payload.file ? "file" : "external"),
      expiry_time: file?.expiry_time ?? null,
      inventory_expanded: true,
      inventory_seen_at: args.seenAt,
      api_version: NOTION_MIGRATION_API_VERSION,
    },
  }];
}

export function countNotionKinds(
  rows: readonly NotionInventoryRow[],
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    counts[row.source_kind] = (counts[row.source_kind] ?? 0) + 1;
  }
  return counts;
}

const notionFileBlockTypes = new Set([
  "audio",
  "file",
  "image",
  "pdf",
  "video",
]);
