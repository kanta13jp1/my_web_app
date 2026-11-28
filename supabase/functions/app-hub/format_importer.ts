export const FORMAT_IMPORTER_RECORD_SOURCE = "format_importer_record";
export const FORMAT_IMPORTER_ATTR_SOURCE = "format_importer_attr_def";

export const SUPPORTED_IMPORT_FORMATS = ["json", "csv"] as const;
export type ImportFormat = (typeof SUPPORTED_IMPORT_FORMATS)[number];

export const SUPPORTED_EXPORT_FORMATS = ["json", "csv"] as const;
export type ExportFormat = (typeof SUPPORTED_EXPORT_FORMATS)[number];

export const SUPPORTED_ATTRIBUTE_TYPES = [
  "string",
  "number",
  "boolean",
  "date",
  "string_list",
] as const;
export type CustomAttributeType = (typeof SUPPORTED_ATTRIBUTE_TYPES)[number];

const FORBIDDEN_KEYS = new Set(["__proto__", "constructor", "prototype"]);
const ATTR_KEY_PATTERN = /^[a-z][a-z0-9_]{0,63}$/;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}(?:T.*)?$/;
const MAX_IMPORT_RECORDS = 50;
const MAX_PAYLOAD_CHARS = 120_000;

export class FormatImporterError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "FormatImporterError";
    this.status = status;
  }
}

export interface CustomAttributeDefinition {
  id?: string;
  key: string;
  label: string;
  value_type: CustomAttributeType;
  required: boolean;
  default_value: unknown;
  created_at?: string;
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

export interface FormatImporterDb {
  from(table: string): unknown;
}

function asHubTable(admin: FormatImporterDb): HubQuery<unknown> {
  return admin.from("hub_data") as HubQuery<unknown>;
}

function assertSafeKey(key: string, label: string): string {
  const trimmed = key.trim();
  if (!trimmed || FORBIDDEN_KEYS.has(trimmed)) {
    throw new FormatImporterError(`Unsafe or empty ${label}: ${key}`);
  }
  return trimmed;
}

export function normalizeAttributeKey(raw: unknown): string {
  const key = String(raw ?? "").trim();
  if (FORBIDDEN_KEYS.has(key) || !ATTR_KEY_PATTERN.test(key)) {
    throw new FormatImporterError(
      "Attribute key must match ^[a-z][a-z0-9_]{0,63}$",
    );
  }
  return key;
}

export function normalizeAttributeType(raw: unknown): CustomAttributeType {
  const val = String(raw ?? "").trim();
  if (
    (SUPPORTED_ATTRIBUTE_TYPES as readonly string[]).includes(val)
  ) {
    return val as CustomAttributeType;
  }
  throw new FormatImporterError(`Unsupported value_type: ${val}`);
}

export function coerceCustomAttributeValue(
  value: unknown,
  valueType: CustomAttributeType,
  key: string,
): unknown {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  switch (valueType) {
    case "string":
      return String(value).slice(0, 512);
    case "number": {
      const parsed = typeof value === "number" ? value : Number(String(value));
      if (!Number.isFinite(parsed)) {
        throw new FormatImporterError(
          `Custom attribute '${key}' requires a finite number`,
        );
      }
      return parsed;
    }
    case "boolean": {
      if (typeof value === "boolean") return value;
      const lowered = String(value).trim().toLowerCase();
      if (lowered === "true" || lowered === "1") return true;
      if (lowered === "false" || lowered === "0") return false;
      throw new FormatImporterError(
        `Custom attribute '${key}' requires a boolean`,
      );
    }
    case "date": {
      const text = String(value).trim();
      if (!ISO_DATE_PATTERN.test(text) || Number.isNaN(Date.parse(text))) {
        throw new FormatImporterError(
          `Custom attribute '${key}' requires an ISO-8601 date`,
        );
      }
      return text;
    }
    case "string_list": {
      if (Array.isArray(value)) {
        return value
          .map((item) => String(item).trim())
          .filter((item) => item.length > 0)
          .slice(0, 32);
      }
      return String(value)
        .split(",")
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
        .slice(0, 32);
    }
  }
}

export function readDotPath(
  source: Record<string, unknown>,
  dotPath: string,
): unknown {
  const parts = dotPath.split(".").map((p) => p.trim()).filter(Boolean);
  if (parts.length === 0) return undefined;
  let current: unknown = source;
  for (const part of parts) {
    assertSafeKey(part, "dot path segment");
    if (
      current === null ||
      typeof current !== "object" ||
      Array.isArray(current)
    ) {
      return undefined;
    }
    const obj = current as Record<string, unknown>;
    if (!Object.hasOwn(obj, part)) return undefined;
    current = obj[part];
  }
  return current;
}

export function flattenDotPaths(
  input: unknown,
  prefix = "",
  out: Record<string, unknown> = {},
): Record<string, unknown> {
  if (input === null || input === undefined) {
    return out;
  }
  if (Array.isArray(input) || typeof input !== "object") {
    if (prefix) out[prefix] = input;
    return out;
  }
  const entries = Object.entries(input as Record<string, unknown>);
  for (const [rawKey, val] of entries) {
    const key = assertSafeKey(rawKey, "field key");
    const nextPrefix = prefix ? `${prefix}.${key}` : key;
    if (val !== null && typeof val === "object" && !Array.isArray(val)) {
      flattenDotPaths(val, nextPrefix, out);
    } else {
      out[nextPrefix] = val;
    }
  }
  return out;
}

export function parseCsvRecords(rawText: string): Record<string, unknown>[] {
  const normalized = rawText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").trim();
  if (!normalized) {
    throw new FormatImporterError("CSV payload is empty");
  }
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < normalized.length; i += 1) {
    const ch = normalized[i];
    if (inQuotes) {
      if (ch === '"') {
        if (normalized[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
      continue;
    }
    if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      row.push(field.trim());
      field = "";
    } else if (ch === "\n") {
      row.push(field.trim());
      if (row.some((cell) => cell.length > 0)) {
        rows.push(row);
      }
      row = [];
      field = "";
    } else {
      field += ch;
    }
  }
  if (inQuotes) {
    throw new FormatImporterError("Unterminated quoted string in CSV payload");
  }
  row.push(field.trim());
  if (row.some((cell) => cell.length > 0)) {
    rows.push(row);
  }
  if (rows.length < 2) {
    throw new FormatImporterError(
      "CSV payload must include a header row and at least one data row",
    );
  }

  const headers = rows[0].map((h) => assertSafeKey(h, "CSV column"));
  const records: Record<string, unknown>[] = [];
  for (const dataRow of rows.slice(1, MAX_IMPORT_RECORDS + 1)) {
    const record: Record<string, unknown> = {};
    for (let idx = 0; idx < headers.length; idx += 1) {
      record[headers[idx]] = idx < dataRow.length ? dataRow[idx] : "";
    }
    records.push(record);
  }
  return records;
}

export function parseHierarchicalJsonRecords(
  rawText: string,
  rootPath = "",
): Record<string, unknown>[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new FormatImporterError("Invalid JSON payload");
  }

  let target: unknown = parsed;
  if (rootPath.trim()) {
    if (
      target === null || typeof target !== "object" || Array.isArray(target)
    ) {
      throw new FormatImporterError(
        `Root path '${rootPath}' cannot traverse non-object JSON`,
      );
    }
    target = readDotPath(target as Record<string, unknown>, rootPath);
  } else if (
    target !== null && typeof target === "object" && !Array.isArray(target)
  ) {
    const obj = target as Record<string, unknown>;
    if (Array.isArray(obj.records)) {
      target = obj.records;
    } else if (Array.isArray(obj.items)) {
      target = obj.items;
    }
  }

  const list = Array.isArray(target)
    ? target
    : target !== null && typeof target === "object"
    ? [target]
    : null;
  if (!list || list.length === 0) {
    throw new FormatImporterError("JSON payload yielded zero records");
  }

  const records: Record<string, unknown>[] = [];
  for (const entry of list.slice(0, MAX_IMPORT_RECORDS)) {
    if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new FormatImporterError(
        "Each imported JSON entry must be an object",
      );
    }
    records.push(entry as Record<string, unknown>);
  }
  return records;
}

export function mapRecordWithSchema(
  rawRecord: Record<string, unknown>,
  fieldMapping: Record<string, string>,
): Record<string, unknown> {
  const flat = flattenDotPaths(rawRecord);
  const mappingEntries = Object.entries(fieldMapping);
  if (mappingEntries.length === 0) {
    return flat;
  }
  const mapped: Record<string, unknown> = {};
  for (const [rawTarget, rawSource] of mappingEntries) {
    const targetKey = assertSafeKey(rawTarget, "target mapping key");
    const sourcePath = assertSafeKey(String(rawSource ?? ""), "source path");
    const value = Object.hasOwn(flat, sourcePath)
      ? flat[sourcePath]
      : readDotPath(rawRecord, sourcePath);
    if (value !== undefined) {
      mapped[targetKey] = value;
    }
  }
  return mapped;
}

export function validateCustomAttributeMap(
  input: Record<string, unknown>,
  definitions: CustomAttributeDefinition[],
): Record<string, unknown> {
  const defByKey = new Map(definitions.map((def) => [def.key, def]));
  const result: Record<string, unknown> = {};

  for (const [rawKey, rawValue] of Object.entries(input)) {
    const key = normalizeAttributeKey(rawKey);
    const def = defByKey.get(key);
    if (def) {
      const coerced = coerceCustomAttributeValue(rawValue, def.value_type, key);
      if (coerced !== null) {
        result[key] = coerced;
      }
    } else if (rawValue !== null && rawValue !== undefined) {
      result[key] = rawValue;
    }
  }

  for (const def of definitions) {
    if (!Object.hasOwn(result, def.key)) {
      if (
        def.default_value !== null &&
        def.default_value !== undefined &&
        def.default_value !== ""
      ) {
        result[def.key] = coerceCustomAttributeValue(
          def.default_value,
          def.value_type,
          def.key,
        );
      } else if (def.required) {
        throw new FormatImporterError(
          `Missing required custom attribute: ${def.key}`,
        );
      }
    }
  }
  return result;
}

function escapeCsvCell(value: unknown): string {
  const raw = value === null || value === undefined
    ? ""
    : typeof value === "object"
    ? JSON.stringify(value)
    : String(value);
  if (/[",\n\r]/.test(raw)) {
    return `"${raw.replaceAll('"', '""')}"`;
  }
  return raw;
}

export function exportFilteredRecords(
  records: HubDataRow[],
  {
    excludedFields = [],
    excludedTags = [],
    format = "json",
  }: {
    excludedFields?: string[];
    excludedTags?: string[];
    format?: ExportFormat;
  },
): {
  format: ExportFormat;
  record_count: number;
  excluded_fields: string[];
  excluded_tags: string[];
  records: Record<string, unknown>[];
  payload_text: string;
} {
  const excludedFieldSet = new Set(
    excludedFields.map((f) => f.trim()).filter(Boolean),
  );
  const excludedTagSet = new Set(
    excludedTags.map((t) => t.trim().toLowerCase()).filter(Boolean),
  );

  const filteredRows: Record<string, unknown>[] = [];
  for (const row of records) {
    const meta = (row.metadata ?? {}) as Record<string, unknown>;
    const tags = Array.isArray(meta.tags)
      ? meta.tags.map((t) => String(t).trim()).filter(Boolean)
      : [];
    const hasExcludedTag = tags.some((tag) =>
      excludedTagSet.has(tag.toLowerCase())
    );
    if (hasExcludedTag) continue;

    const mapped = (meta.mapped_fields ?? {}) as Record<string, unknown>;
    const customAttrs = (meta.custom_attributes ?? {}) as Record<
      string,
      unknown
    >;

    const out: Record<string, unknown> = {};
    if (!excludedFieldSet.has("id")) out.id = row.id;
    if (!excludedFieldSet.has("format_profile") && meta.format_profile) {
      out.format_profile = meta.format_profile;
    }
    if (!excludedFieldSet.has("source_format") && meta.source_format) {
      out.source_format = meta.source_format;
    }
    if (!excludedFieldSet.has("tags")) {
      out.tags = tags;
    }

    for (const [k, v] of Object.entries(mapped)) {
      if (
        excludedFieldSet.has(k) ||
        excludedFieldSet.has(`mapped_fields.${k}`)
      ) {
        continue;
      }
      out[k] = v;
    }
    for (const [k, v] of Object.entries(customAttrs)) {
      if (
        excludedFieldSet.has(k) ||
        excludedFieldSet.has(`custom_attributes.${k}`)
      ) {
        continue;
      }
      out[k] = v;
    }
    filteredRows.push(out);
  }

  let payloadText = "";
  if (format === "csv") {
    const columns: string[] = [];
    const seenCols = new Set<string>();
    for (const item of filteredRows) {
      for (const col of Object.keys(item)) {
        if (!seenCols.has(col)) {
          seenCols.add(col);
          columns.push(col);
        }
      }
    }
    if (columns.length === 0) {
      payloadText = "";
    } else {
      const lines = [columns.map(escapeCsvCell).join(",")];
      for (const item of filteredRows) {
        lines.push(columns.map((col) => escapeCsvCell(item[col])).join(","));
      }
      payloadText = lines.join("\n");
    }
  } else {
    payloadText = JSON.stringify(filteredRows, null, 2);
  }

  return {
    format,
    record_count: filteredRows.length,
    excluded_fields: [...excludedFieldSet],
    excluded_tags: [...excludedTagSet],
    records: filteredRows,
    payload_text: payloadText,
  };
}

function rowToAttributeDefinition(row: HubDataRow): CustomAttributeDefinition {
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  return {
    id: row.id,
    key: String(meta.key ?? ""),
    label: String(meta.label ?? meta.key ?? ""),
    value_type: normalizeAttributeType(meta.value_type ?? "string"),
    required: Boolean(meta.required),
    default_value: meta.default_value ?? null,
    created_at: row.created_at,
  };
}

async function listHubRows(
  admin: FormatImporterDb,
  source: string,
  userId: string,
  limit = 100,
): Promise<HubDataRow[]> {
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) {
    throw new FormatImporterError(
      error.message ?? "Failed to load hub_data",
      500,
    );
  }
  return (data ?? []) as HubDataRow[];
}

export async function handleFormatImporterAction({
  action,
  admin,
  body,
  userId,
}: {
  action: string;
  admin: FormatImporterDb;
  body: Record<string, unknown>;
  userId: string;
}): Promise<Record<string, unknown>> {
  switch (action) {
    case "format_importer.list": {
      const [recordRows, attrRows] = await Promise.all([
        listHubRows(admin, FORMAT_IMPORTER_RECORD_SOURCE, userId, 100),
        listHubRows(admin, FORMAT_IMPORTER_ATTR_SOURCE, userId, 50),
      ]);
      return {
        records: recordRows,
        custom_attributes: attrRows.map(rowToAttributeDefinition),
      };
    }

    case "format_importer.define_attribute": {
      const key = normalizeAttributeKey(body.key);
      const valueType = normalizeAttributeType(body.value_type ?? "string");
      const label = String(body.label ?? key).trim().slice(0, 80) || key;
      const required = Boolean(body.required);
      const defaultValue = coerceCustomAttributeValue(
        body.default_value ?? null,
        valueType,
        key,
      );

      const existingRows = await listHubRows(
        admin,
        FORMAT_IMPORTER_ATTR_SOURCE,
        userId,
        100,
      );
      const existing = existingRows.find(
        (r) => String((r.metadata ?? {}).key ?? "") === key,
      );

      const metadata = {
        user_id: userId,
        key,
        label,
        value_type: valueType,
        required,
        default_value: defaultValue,
        updated_at: new Date().toISOString(),
      };

      if (existing) {
        const { data, error } = await asHubTable(admin)
          .update({ metadata })
          .eq("id", existing.id)
          .eq("source", FORMAT_IMPORTER_ATTR_SOURCE)
          .filter("metadata->>user_id", "eq", userId)
          .select("id, metadata, created_at")
          .single();
        if (error) {
          throw new FormatImporterError(
            error.message ?? "Failed to update attribute",
            500,
          );
        }
        return {
          custom_attribute: rowToAttributeDefinition(data as HubDataRow),
        };
      }

      const { data, error } = await asHubTable(admin)
        .insert({ source: FORMAT_IMPORTER_ATTR_SOURCE, metadata })
        .select("id, metadata, created_at")
        .single();
      if (error) {
        throw new FormatImporterError(
          error.message ?? "Failed to create attribute",
          500,
        );
      }
      return {
        custom_attribute: rowToAttributeDefinition(data as HubDataRow),
      };
    }

    case "format_importer.preview":
    case "format_importer.import": {
      const sourceFormatRaw = String(body.source_format ?? "json").trim();
      const allowedImport = SUPPORTED_IMPORT_FORMATS as readonly string[];
      if (!allowedImport.includes(sourceFormatRaw)) {
        throw new FormatImporterError(`Unsupported format: ${sourceFormatRaw}`);
      }
      const sourceFormat = sourceFormatRaw as ImportFormat;
      const rawPayload = String(body.payload ?? "");
      if (!rawPayload.trim() || rawPayload.length > MAX_PAYLOAD_CHARS) {
        throw new FormatImporterError(
          `Payload must be non-empty and <= ${MAX_PAYLOAD_CHARS} characters`,
        );
      }

      const fieldMappingRaw = (body.field_mapping ?? {}) as Record<
        string,
        unknown
      >;
      const fieldMapping: Record<string, string> = {};
      for (const [k, v] of Object.entries(fieldMappingRaw)) {
        fieldMapping[k] = String(v ?? "");
      }
      const rootPath = String(body.root_path ?? "").trim();
      const formatProfile =
        String(body.format_profile ?? `generic_${sourceFormat}`).trim()
          .slice(0, 64) || `generic_${sourceFormat}`;
      const tags = Array.isArray(body.tags)
        ? body.tags.map((t) => String(t).trim()).filter(Boolean).slice(0, 20)
        : [];

      const parsedEntries = sourceFormat === "csv"
        ? parseCsvRecords(rawPayload)
        : parseHierarchicalJsonRecords(rawPayload, rootPath);

      const attrRows = await listHubRows(
        admin,
        FORMAT_IMPORTER_ATTR_SOURCE,
        userId,
        50,
      );
      const attrDefs = attrRows.map(rowToAttributeDefinition);
      const baseCustomAttrs = validateCustomAttributeMap(
        (body.custom_attributes ?? {}) as Record<string, unknown>,
        attrDefs,
      );

      const prepared = parsedEntries.map((entry) => ({
        format_profile: formatProfile,
        source_format: sourceFormat,
        tags,
        mapped_fields: mapRecordWithSchema(entry, fieldMapping),
        custom_attributes: { ...baseCustomAttrs },
      }));

      if (action === "format_importer.preview") {
        return { preview_count: prepared.length, candidates: prepared };
      }

      const inserted: HubDataRow[] = [];
      for (const candidate of prepared) {
        const { data, error } = await asHubTable(admin)
          .insert({
            source: FORMAT_IMPORTER_RECORD_SOURCE,
            metadata: {
              user_id: userId,
              ...candidate,
              imported_at: new Date().toISOString(),
            },
          })
          .select("id, metadata, created_at")
          .single();
        if (error) {
          throw new FormatImporterError(
            error.message ?? "Import insert failed",
            500,
          );
        }
        inserted.push(data as HubDataRow);
      }
      return { imported_count: inserted.length, records: inserted };
    }

    case "format_importer.update_record_attributes": {
      const recordId = String(body.record_id ?? "").trim();
      if (!recordId) {
        throw new FormatImporterError("record_id is required");
      }
      const { data: existingData, error: readError } = await asHubTable(admin)
        .select("metadata")
        .eq("id", recordId)
        .eq("source", FORMAT_IMPORTER_RECORD_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (readError) {
        throw new FormatImporterError(
          readError.message ?? "Failed to load record",
          500,
        );
      }
      if (!existingData) {
        throw new FormatImporterError("Imported record not found", 404);
      }

      const metaEnvelope = existingData as {
        metadata?: Record<string, unknown>;
      };
      const existingMeta = (metaEnvelope.metadata ?? {}) as Record<
        string,
        unknown
      >;
      const attrRows = await listHubRows(
        admin,
        FORMAT_IMPORTER_ATTR_SOURCE,
        userId,
        50,
      );
      const attrDefs = attrRows.map(rowToAttributeDefinition);
      const prevAttrs = (existingMeta.custom_attributes ?? {}) as Record<
        string,
        unknown
      >;
      const patchAttrs = (body.custom_attributes ?? {}) as Record<
        string,
        unknown
      >;
      const mergedAttrs = validateCustomAttributeMap(
        {
          ...prevAttrs,
          ...patchAttrs,
        },
        attrDefs,
      );

      const nextTags = Array.isArray(body.tags)
        ? body.tags.map((t) => String(t).trim()).filter(Boolean).slice(0, 20)
        : existingMeta.tags ?? [];

      const { data: updated, error: updateError } = await asHubTable(admin)
        .update({
          metadata: {
            ...existingMeta,
            custom_attributes: mergedAttrs,
            tags: nextTags,
            user_id: userId,
            updated_at: new Date().toISOString(),
          },
        })
        .eq("id", recordId)
        .eq("source", FORMAT_IMPORTER_RECORD_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .single();
      if (updateError) {
        throw new FormatImporterError(
          updateError.message ?? "Failed to update record",
          500,
        );
      }
      return { record: updated };
    }

    case "format_importer.export": {
      const formatRaw = String(body.format ?? "json").trim();
      const allowedExport = SUPPORTED_EXPORT_FORMATS as readonly string[];
      if (!allowedExport.includes(formatRaw)) {
        throw new FormatImporterError(
          `Unsupported export format: ${formatRaw}`,
        );
      }
      const excludedFields = Array.isArray(body.excluded_fields)
        ? body.excluded_fields.map((v) => String(v))
        : [];
      const excludedTags = Array.isArray(body.excluded_tags)
        ? body.excluded_tags.map((v) => String(v))
        : [];
      const rows = await listHubRows(
        admin,
        FORMAT_IMPORTER_RECORD_SOURCE,
        userId,
        200,
      );
      return exportFilteredRecords(rows, {
        excludedFields,
        excludedTags,
        format: formatRaw as ExportFormat,
      });
    }

    default:
      throw new FormatImporterError(`Unsupported action: ${action}`, 400);
  }
}
