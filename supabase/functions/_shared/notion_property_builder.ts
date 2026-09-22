// Notion page-property payload builder (GitHub Issue #1287).
//
// Notion's Title property is special: its internal/API id is always the literal
// string "title". Naming a *non-title* property "title", or sending a bare value
// instead of the type-wrapped object Notion expects, both surface as an opaque
// HTTP 400 `validation_error` ("mismatched data type"). This module centralizes
// two responsibilities so callers never hand-roll Notion payloads again:
//
//   1. Strict per-type wrapping — turn a plain value into the exact JSON object
//      the Notion Page-properties API requires ({ number: 1 }, { select: { name }},
//      { rich_text: [{ text: { content }}]}, ...), for single or many properties.
//   2. Title-collision detection — flag any mapping that names a non-title
//      property "title" before the request is ever sent (warn, or throw in strict
//      mode), so the 400 never happens in production.
//
// A companion helper (`extractNotionErrorDetail`) parses Notion's structured
// error body so failures log the real `code`/`message`/`request_id` instead of a
// bare status. The module is dependency-free pure logic — fully unit testable
// (Deno test in CI) and safe to reuse from any Edge Function.

/** Notion page-property types this builder can wrap. */
export type NotionPropertyType =
  | "title"
  | "rich_text"
  | "number"
  | "select"
  | "status"
  | "multi_select"
  | "date"
  | "checkbox"
  | "url"
  | "email"
  | "phone_number"
  | "people"
  | "relation";

/** A single column mapping: the Notion property name and its declared type. */
export interface NotionPropertyMapping {
  name: string;
  type: NotionPropertyType;
}

export interface BuildNotionPropertiesOptions {
  /** When true, a title collision throws instead of returning a warning. */
  strictTitleCollision?: boolean;
  /** When true (default), mappings whose value is `undefined` are skipped. */
  skipUndefined?: boolean;
}

export interface BuildNotionPropertiesResult {
  /** The `properties` object to send under Notion's page create/update payload. */
  properties: Record<string, unknown>;
  /** Non-fatal issues detected while building (e.g. title-name collisions). */
  warnings: string[];
}

export interface NotionErrorDetail {
  status: number;
  code: string;
  message: string;
  requestId: string | null;
  /** Human-readable one-liner suitable for logs. */
  detail: string;
}

/**
 * Notion reserves the internal property id "title" for the single Title column.
 * Any other property named "title" (case-insensitive) collides with it.
 */
export const NOTION_TITLE_INTERNAL_ID = "title";

/** Notion caps a single rich-text object at 2000 characters. */
export const NOTION_RICH_TEXT_LIMIT = 2000;

/** Raised when a value cannot be wrapped into a valid Notion property object. */
export class NotionPropertyBuildError extends Error {
  readonly property: string;
  readonly expectedType: NotionPropertyType;
  constructor(
    property: string,
    expectedType: NotionPropertyType,
    reason: string,
  ) {
    super(
      `notion_property_build_failed: "${property}" (${expectedType}): ${reason}`,
    );
    this.name = "NotionPropertyBuildError";
    this.property = property;
    this.expectedType = expectedType;
  }
}

function asString(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "boolean") return String(value);
  return null;
}

/**
 * Split text into Notion-compliant rich-text objects (<= 2000 chars each).
 * Empty/blank input yields an empty array, which clears the property.
 */
export function notionRichTextValue(
  content: string,
): Array<Record<string, unknown>> {
  const chunks: Array<Record<string, unknown>> = [];
  let rest = content ?? "";
  while (rest.length > 0 && chunks.length < 100) {
    const slice = rest.slice(0, NOTION_RICH_TEXT_LIMIT);
    chunks.push({ text: { content: slice } });
    rest = rest.slice(NOTION_RICH_TEXT_LIMIT);
  }
  return chunks;
}

/**
 * Detect the classic mistake of naming a non-title property "title".
 * Returns a warning string, or null when there is no collision.
 */
export function detectTitleCollision(
  mapping: NotionPropertyMapping,
): string | null {
  const trimmed = (mapping.name ?? "").trim().toLowerCase();
  if (trimmed === NOTION_TITLE_INTERNAL_ID && mapping.type !== "title") {
    return `property "${mapping.name}" is typed "${mapping.type}" but named "title", ` +
      `which collides with Notion's reserved Title id and causes HTTP 400 ` +
      `(mismatched data type). Rename it or declare it as type "title".`;
  }
  return null;
}

function coerceString(
  mapping: NotionPropertyMapping,
  value: unknown,
): string {
  const s = asString(value);
  if (s === null) {
    throw new NotionPropertyBuildError(
      mapping.name,
      mapping.type,
      `expected a string-like value but got ${describe(value)}`,
    );
  }
  return s;
}

function coerceStringArray(
  mapping: NotionPropertyMapping,
  value: unknown,
): string[] {
  if (value === null || value === undefined) return [];
  const raw = Array.isArray(value) ? value : [value];
  return raw.map((item) => {
    const s = asString(item);
    if (s === null || s.trim() === "") {
      throw new NotionPropertyBuildError(
        mapping.name,
        mapping.type,
        `expected non-empty string entries but got ${describe(item)}`,
      );
    }
    return s;
  });
}

function buildDateValue(
  mapping: NotionPropertyMapping,
  value: unknown,
): Record<string, unknown> | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string") {
    if (value.trim() === "") return null;
    return { start: value };
  }
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const start = asString(obj.start);
    if (!start) {
      throw new NotionPropertyBuildError(
        mapping.name,
        mapping.type,
        `date object requires a non-empty "start"`,
      );
    }
    const out: Record<string, unknown> = { start };
    const end = asString(obj.end);
    if (end) out.end = end;
    const tz = asString(obj.time_zone);
    if (tz) out.time_zone = tz;
    return out;
  }
  throw new NotionPropertyBuildError(
    mapping.name,
    mapping.type,
    `expected an ISO date string or { start, end? } object but got ${
      describe(value)
    }`,
  );
}

function describe(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

/**
 * Wrap a single plain value into the exact type-object Notion's API expects.
 * Throws NotionPropertyBuildError on a type mismatch (Acceptance Criteria #2).
 */
export function wrapNotionPropertyValue(
  mapping: NotionPropertyMapping,
  value: unknown,
): Record<string, unknown> {
  switch (mapping.type) {
    case "title":
      return { title: notionRichTextValue(coerceString(mapping, value ?? "")) };
    case "rich_text":
      return {
        rich_text: notionRichTextValue(coerceString(mapping, value ?? "")),
      };
    case "number": {
      if (value === null || value === undefined) return { number: null };
      const n = typeof value === "number"
        ? value
        : Number(asString(value) ?? NaN);
      if (!Number.isFinite(n)) {
        throw new NotionPropertyBuildError(
          mapping.name,
          mapping.type,
          `expected a finite number but got ${describe(value)}`,
        );
      }
      return { number: n };
    }
    case "select": {
      const s = value === null || value === undefined
        ? null
        : coerceString(mapping, value);
      return { select: s ? { name: s } : null };
    }
    case "status": {
      const s = value === null || value === undefined
        ? null
        : coerceString(mapping, value);
      return { status: s ? { name: s } : null };
    }
    case "multi_select":
      return {
        multi_select: coerceStringArray(mapping, value).map((name) => ({
          name,
        })),
      };
    case "date":
      return { date: buildDateValue(mapping, value) };
    case "checkbox":
      return { checkbox: Boolean(value) };
    case "url":
      return {
        url: value === null || value === undefined
          ? null
          : coerceString(mapping, value),
      };
    case "email":
      return {
        email: value === null || value === undefined
          ? null
          : coerceString(mapping, value),
      };
    case "phone_number":
      return {
        phone_number: value === null || value === undefined
          ? null
          : coerceString(mapping, value),
      };
    case "people":
      return {
        people: coerceStringArray(mapping, value).map((id) => ({ id })),
      };
    case "relation":
      return {
        relation: coerceStringArray(mapping, value).map((id) => ({ id })),
      };
    default: {
      // Exhaustiveness guard — unreachable unless a new type is added.
      const _never: never = mapping.type;
      throw new NotionPropertyBuildError(
        mapping.name,
        mapping.type,
        `unsupported property type "${String(_never)}"`,
      );
    }
  }
}

/** Convenience wrapper for a single-property update. */
export function buildSingleNotionProperty(
  mapping: NotionPropertyMapping,
  value: unknown,
): Record<string, unknown> {
  return { [mapping.name]: wrapNotionPropertyValue(mapping, value) };
}

/**
 * Build the full `properties` object for a Notion page create/update from a
 * mapping list and a values record keyed by property name.
 *
 * - Title collisions are reported in `warnings` (or throw in strict mode).
 * - Mappings with no key in `values` are skipped; `undefined` values are
 *   skipped unless `skipUndefined` is disabled.
 * - Duplicate/empty property names throw, so a broken mapping fails fast.
 */
export function buildNotionProperties(
  mappings: NotionPropertyMapping[],
  values: Record<string, unknown>,
  options: BuildNotionPropertiesOptions = {},
): BuildNotionPropertiesResult {
  const strictTitleCollision = options.strictTitleCollision ?? false;
  const skipUndefined = options.skipUndefined ?? true;

  const properties: Record<string, unknown> = {};
  const warnings: string[] = [];
  const seen = new Set<string>();

  for (const mapping of mappings) {
    const name = (mapping.name ?? "").trim();
    if (name === "") {
      throw new NotionPropertyBuildError(
        String(mapping.name),
        mapping.type,
        "property name is empty",
      );
    }
    if (seen.has(name)) {
      throw new NotionPropertyBuildError(
        name,
        mapping.type,
        "duplicate property name in mapping",
      );
    }
    seen.add(name);

    const collision = detectTitleCollision(mapping);
    if (collision) {
      if (strictTitleCollision) {
        throw new NotionPropertyBuildError(name, mapping.type, collision);
      }
      warnings.push(collision);
    }

    if (!(name in values)) continue;
    const value = values[name];
    if (value === undefined && skipUndefined) continue;

    properties[name] = wrapNotionPropertyValue(mapping, value);
  }

  return { properties, warnings };
}

/**
 * Parse a Notion error response body into a structured, loggable detail
 * (Acceptance Criteria #3). Accepts either the raw text or a parsed object and
 * degrades gracefully when the body is not JSON.
 */
export function extractNotionErrorDetail(
  status: number,
  body: string | Record<string, unknown> | null,
): NotionErrorDetail {
  let parsed: Record<string, unknown> | null = null;

  if (typeof body === "string") {
    try {
      parsed = JSON.parse(body) as Record<string, unknown>;
    } catch {
      const raw = body.slice(0, 500);
      return {
        status,
        code: "unknown",
        message: raw || "(empty body)",
        requestId: null,
        detail: `Notion API error HTTP ${status}: ${raw || "(empty body)"}`,
      };
    }
  } else {
    parsed = body;
  }

  const code = asString(parsed?.code) ?? "unknown";
  const message = asString(parsed?.message) ?? "(no message)";
  const requestId = asString(parsed?.request_id);
  const detail = `Notion API error HTTP ${status} [${code}]: ${message}` +
    (requestId ? ` (request_id=${requestId})` : "");

  return { status, code, message, requestId, detail };
}
