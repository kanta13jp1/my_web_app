/** Notion data-source and page-property pagination helpers. */

export const NOTION_API_VERSION = "2025-09-03";

export type NotionRequest = (
  path: string,
  init?: RequestInit,
) => Promise<Response>;

export class NotionDataSourceError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status?: number,
    public readonly detail?: string,
  ) {
    super(message);
    this.name = "NotionDataSourceError";
  }
}

export interface ResolveNotionDataSourceOptions {
  databaseId?: string | null;
  dataSourceId?: string | null;
  dataSourceName?: string | null;
}

export interface NotionQueryOptions {
  pageSize?: number;
  maxPages?: number;
}

export interface NotionPropertyItemsResult {
  results: Record<string, unknown>[];
  propertyItem: Record<string, unknown> | null;
}

function normalizedId(value: string | null | undefined): string {
  return String(value ?? "").replaceAll("-", "").trim();
}

function encodedPropertyId(value: string): string {
  try {
    return encodeURIComponent(decodeURIComponent(value));
  } catch {
    return encodeURIComponent(value);
  }
}

function boundedInteger(
  value: number | undefined,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  if (value === undefined) return fallback;
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new NotionDataSourceError(
      "notion_pagination_invalid",
      `Expected an integer between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

async function responseJson(
  response: Response,
  operation: string,
): Promise<Record<string, unknown>> {
  const text = await response.text().catch(() => "");
  if (!response.ok) {
    throw new NotionDataSourceError(
      `${operation}_failed`,
      `${operation} failed with HTTP ${response.status}.`,
      response.status,
      text.slice(0, 500),
    );
  }

  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("response is not an object");
    }
    return parsed as Record<string, unknown>;
  } catch {
    throw new NotionDataSourceError(
      `${operation}_invalid_json`,
      `${operation} returned invalid JSON.`,
      response.status,
      text.slice(0, 500),
    );
  }
}

function pageResults(
  payload: Record<string, unknown>,
): Record<string, unknown>[] {
  if (!Array.isArray(payload.results)) return [];
  return payload.results.filter(
    (item): item is Record<string, unknown> =>
      Boolean(item) && typeof item === "object" && !Array.isArray(item),
  );
}

function nextCursor(
  payload: Record<string, unknown>,
  operation: string,
): string | null {
  if (payload.has_more !== true) return null;
  if (typeof payload.next_cursor !== "string" || !payload.next_cursor.trim()) {
    throw new NotionDataSourceError(
      `${operation}_missing_cursor`,
      `${operation} returned has_more=true without next_cursor.`,
    );
  }
  return payload.next_cursor;
}

/** Resolve the current data-source ID from an environment-provided ID pair. */
export async function resolveNotionDataSourceId(
  request: NotionRequest,
  options: ResolveNotionDataSourceOptions,
): Promise<string> {
  const explicitDataSourceId = normalizedId(options.dataSourceId);
  if (explicitDataSourceId) return explicitDataSourceId;

  const databaseId = normalizedId(options.databaseId);
  if (!databaseId) {
    throw new NotionDataSourceError(
      "notion_data_source_id_missing",
      "A Notion data-source ID or database ID is required.",
    );
  }

  const payload = await responseJson(
    await request(`/databases/${databaseId}`),
    "notion_database_retrieve",
  );
  const sources = Array.isArray(payload.data_sources)
    ? payload.data_sources.filter(
      (item): item is Record<string, unknown> =>
        Boolean(item) && typeof item === "object" && !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).id === "string",
    )
    : [];

  const requestedName = String(options.dataSourceName ?? "").trim();
  const matches = requestedName
    ? sources.filter((source) => source.name === requestedName)
    : sources;
  if (matches.length === 1) return normalizedId(String(matches[0].id));
  if (matches.length === 0) {
    throw new NotionDataSourceError(
      "notion_data_source_not_found",
      requestedName
        ? `Notion database has no data source named ${requestedName}.`
        : "Notion database has no queryable data source.",
    );
  }
  throw new NotionDataSourceError(
    "notion_data_source_ambiguous",
    "Notion database has multiple data sources; configure an explicit data-source ID or name.",
  );
}

/** Query every page from a Notion data source with a bounded cursor loop. */
export async function queryAllNotionDataSourcePages(
  request: NotionRequest,
  dataSourceId: string,
  body: Record<string, unknown> = {},
  options: NotionQueryOptions = {},
): Promise<Record<string, unknown>[]> {
  const id = normalizedId(dataSourceId);
  if (!id) {
    throw new NotionDataSourceError(
      "notion_data_source_id_missing",
      "A Notion data-source ID is required.",
    );
  }
  const pageSize = boundedInteger(options.pageSize, 100, 1, 100);
  const maxPages = boundedInteger(options.maxPages, 100, 1, 1000);
  const results: Record<string, unknown>[] = [];
  const seenCursors = new Set<string>();
  let cursor: string | null = null;

  for (let page = 0; page < maxPages; page++) {
    const payload = await responseJson(
      await request(`/data_sources/${id}/query`, {
        method: "POST",
        body: JSON.stringify({
          ...body,
          page_size: pageSize,
          ...(cursor ? { start_cursor: cursor } : {}),
        }),
      }),
      "notion_data_source_query",
    );
    results.push(...pageResults(payload));
    const candidate = nextCursor(payload, "notion_data_source_query");
    if (!candidate) return results;
    if (seenCursors.has(candidate)) {
      throw new NotionDataSourceError(
        "notion_data_source_query_repeated_cursor",
        "Notion data-source query repeated a cursor.",
      );
    }
    seenCursors.add(candidate);
    cursor = candidate;
  }

  throw new NotionDataSourceError(
    "notion_data_source_query_page_limit",
    `Notion data-source query exceeded ${maxPages} pages.`,
  );
}

/** Retrieve a complete page property, including values after the 25-item limit. */
export async function retrieveAllNotionPagePropertyItems(
  request: NotionRequest,
  pageId: string,
  propertyId: string,
  options: NotionQueryOptions = {},
): Promise<NotionPropertyItemsResult> {
  const normalizedPageId = normalizedId(pageId);
  const normalizedPropertyId = String(propertyId ?? "").trim();
  if (!normalizedPageId || !normalizedPropertyId) {
    throw new NotionDataSourceError(
      "notion_page_property_id_missing",
      "Both Notion page ID and property ID are required.",
    );
  }
  const pageSize = boundedInteger(options.pageSize, 100, 1, 100);
  const maxPages = boundedInteger(options.maxPages, 100, 1, 1000);
  const results: Record<string, unknown>[] = [];
  const seenCursors = new Set<string>();
  let propertyItem: Record<string, unknown> | null = null;
  let cursor: string | null = null;

  for (let page = 0; page < maxPages; page++) {
    const search = new URLSearchParams({ page_size: String(pageSize) });
    if (cursor) search.set("start_cursor", cursor);
    const payload = await responseJson(
      await request(
        `/pages/${normalizedPageId}/properties/${
          encodedPropertyId(normalizedPropertyId)
        }?${search}`,
      ),
      "notion_page_property_retrieve",
    );

    if (payload.object !== "list") {
      return { results: [payload], propertyItem: payload };
    }
    results.push(...pageResults(payload));
    if (
      payload.property_item && typeof payload.property_item === "object" &&
      !Array.isArray(payload.property_item)
    ) {
      propertyItem = payload.property_item as Record<string, unknown>;
    }
    const candidate = nextCursor(payload, "notion_page_property_retrieve");
    if (!candidate) return { results, propertyItem };
    if (seenCursors.has(candidate)) {
      throw new NotionDataSourceError(
        "notion_page_property_repeated_cursor",
        "Notion page-property retrieval repeated a cursor.",
      );
    }
    seenCursors.add(candidate);
    cursor = candidate;
  }

  throw new NotionDataSourceError(
    "notion_page_property_page_limit",
    `Notion page-property retrieval exceeded ${maxPages} pages.`,
  );
}
