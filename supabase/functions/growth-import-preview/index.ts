import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ImportPreviewRequest {
  sourceType: string;
  fileName?: string;
  contentBase64?: string;
  notionToken?: string;
  pageLimit?: number;
}

interface ImportedNoteDraft {
  title: string;
  content: string;
  source: string;
  tags: string[];
}

interface ImportPreviewResult {
  sourceType: string;
  sourceLabel: string;
  fileName: string;
  notes: ImportedNoteDraft[];
  warnings: string[];
  previewMode: "edge-function";
}

interface NotionRichText {
  plain_text?: string;
}

interface NotionBlock {
  id?: string;
  type: string;
  has_children?: boolean;
  children?: NotionBlock[];
  [key: string]: unknown;
}

interface NotionPage {
  id: string;
  properties?: Record<string, {
    title?: NotionRichText[];
    rich_text?: NotionRichText[];
    [key: string]: unknown;
  }>;
}

interface NotionSelectOption {
  name: string;
}

interface NotionProperty {
  type: string;
  title?: NotionRichText[];
  rich_text?: NotionRichText[];
  select?: NotionSelectOption | null;
  multi_select?: NotionSelectOption[];
  checkbox?: boolean;
  number?: number | null;
  date?: { start: string } | null;
}

interface NotionDatabase {
  id: string;
}

interface NotionDatabaseEntry {
  id: string;
  properties?: Record<string, NotionProperty>;
}

interface NotionPaginatedResponse<T> {
  results?: T[];
  has_more?: boolean;
  next_cursor?: string | null;
}

const NOTION_BLOCK_PAGE_SIZE = 50;
const NOTION_DATABASE_LIMIT = 3;
const NOTION_MAX_BLOCK_DEPTH = 4;
const NOTION_MAX_BLOCKS_PER_PAGE = 250;
const NOTION_RETRY_LIMIT = 3;
const NOTION_RETRY_BASE_MS = 600;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as ImportPreviewRequest;
    const sourceType = body.sourceType?.trim().toLowerCase();

    if (!sourceType) {
      throw new Error("sourceType is required.");
    }

    if (sourceType === "notion_api") {
      const notionToken = body.notionToken?.trim();
      if (!notionToken) {
        throw new Error("notionToken is required for notion_api.");
      }

      const pageLimit = Math.max(1, Math.min(body.pageLimit ?? 10, 20));
      const preview = await buildNotionApiPreview(notionToken, pageLimit);
      return jsonResponse({ success: true, preview });
    }

    const fileName = body.fileName?.trim();
    const contentBase64 = body.contentBase64?.trim();
    if (!fileName || !contentBase64) {
      throw new Error(
        "fileName and contentBase64 are required for file-based import.",
      );
    }

    const bytes = decodeBase64(contentBase64);
    const preview = buildPreview({
      sourceType,
      fileName,
      bytes,
    });

    return jsonResponse({
      success: true,
      preview,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse(
      {
        success: false,
        error: message,
      },
      400,
    );
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extractNotionTitle(page: NotionPage): string {
  for (const prop of Object.values(page.properties ?? {})) {
    const texts = prop.title ?? prop.rich_text ?? [];
    const text = texts.map((t) => t.plain_text ?? "").join("").trim();
    if (text) {
      return text;
    }
  }
  return "Notion Page";
}

function pushWarningOnce(warnings: string[], message: string): void {
  if (!warnings.includes(message)) {
    warnings.push(message);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseRetryAfterMs(value: string | null, attempt: number): number {
  if (value) {
    const seconds = Number(value);
    if (!Number.isNaN(seconds)) {
      return Math.max(seconds * 1000, NOTION_RETRY_BASE_MS);
    }

    const retryAt = Date.parse(value);
    if (!Number.isNaN(retryAt)) {
      return Math.max(retryAt - Date.now(), NOTION_RETRY_BASE_MS);
    }
  }

  return NOTION_RETRY_BASE_MS * (attempt + 1);
}

async function fetchNotionJson<T>(
  url: string,
  headers: HeadersInit,
  init?: RequestInit,
  attempt = 0,
): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers,
  });

  if (
    (response.status === 408 || response.status === 409 ||
      response.status === 429 || response.status >= 500) &&
    attempt < NOTION_RETRY_LIMIT - 1
  ) {
    await sleep(
      parseRetryAfterMs(response.headers.get("Retry-After"), attempt),
    );
    return await fetchNotionJson<T>(url, headers, init, attempt + 1);
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Notion API error (${response.status}): ${errorText}`);
  }

  const json = await response.json();
  return json as T;
}

function extractBlockText(block: NotionBlock): string {
  const inner = block[block.type] as Record<string, unknown> | undefined;
  const richText = (inner?.rich_text as NotionRichText[] | undefined) ?? [];
  const text = richText.map((item) => item.plain_text ?? "").join("").trim();

  switch (block.type) {
    case "bulleted_list_item":
      return text ? `- ${text}` : "";
    case "numbered_list_item":
      return text ? `1. ${text}` : "";
    case "to_do": {
      const checked = Boolean(inner?.checked);
      return text ? `${checked ? "[x]" : "[ ]"} ${text}` : "";
    }
    case "quote":
      return text ? `> ${text}` : "";
    case "code": {
      const language = typeof inner?.language === "string"
        ? inner.language
        : "";
      return text ? `${language ? `[${language}] ` : ""}${text}` : "";
    }
    case "divider":
      return "---";
    case "bookmark":
      return typeof inner?.url === "string" ? inner.url : "";
    case "child_page":
    case "child_database":
      return typeof inner?.title === "string" ? inner.title : "";
    default:
      return text;
  }
}

function notionBlocksToText(blocks: NotionBlock[], depth = 0): string {
  const indent = "  ".repeat(depth);
  const lines: string[] = [];

  for (const block of blocks) {
    const line = extractBlockText(block);
    if (line) {
      lines.push(`${indent}${line}`);
    }

    if (block.children?.length) {
      const nested = notionBlocksToText(block.children, depth + 1);
      if (nested) {
        lines.push(nested);
      }
    }
  }

  return lines.join("\n").trim();
}

function extractDbEntryTitle(entry: NotionDatabaseEntry): string {
  for (const prop of Object.values(entry.properties ?? {})) {
    if (prop.type === "title" && prop.title) {
      const text = prop.title.map((t) => t.plain_text ?? "").join("").trim();
      if (text) {
        return text;
      }
    }
  }
  return "Database Entry";
}

function extractDbEntryTags(entry: NotionDatabaseEntry): string[] {
  const tags: string[] = [];
  for (const prop of Object.values(entry.properties ?? {})) {
    if (prop.type === "multi_select" && prop.multi_select) {
      for (const tag of prop.multi_select) {
        if (tag.name) {
          tags.push(tag.name);
        }
      }
    } else if (prop.type === "select" && prop.select?.name) {
      tags.push(prop.select.name);
    }
  }
  return tags;
}

function extractDbEntryContent(entry: NotionDatabaseEntry): string {
  const lines: string[] = [];

  for (const [key, prop] of Object.entries(entry.properties ?? {})) {
    if (prop.type === "title") continue;

    if (prop.type === "rich_text" && prop.rich_text?.length) {
      const text = prop.rich_text.map((t) => t.plain_text ?? "").join("")
        .trim();
      if (text) {
        lines.push(`${key}: ${text}`);
      }
    } else if (
      prop.type === "number" &&
      prop.number !== null &&
      prop.number !== undefined
    ) {
      lines.push(`${key}: ${prop.number}`);
    } else if (prop.type === "checkbox" && prop.checkbox !== undefined) {
      lines.push(`${key}: ${prop.checkbox ? "Yes" : "No"}`);
    } else if (prop.type === "date" && prop.date?.start) {
      lines.push(`${key}: ${prop.date.start}`);
    }
  }

  return lines.join("\n");
}

async function fetchNotionBlockTree(
  blockId: string,
  headers: HeadersInit,
  warnings: string[],
  contextLabel: string,
  depth = 0,
  budget = { remaining: NOTION_MAX_BLOCKS_PER_PAGE },
): Promise<NotionBlock[]> {
  if (depth >= NOTION_MAX_BLOCK_DEPTH) {
    pushWarningOnce(
      warnings,
      `Nested Notion blocks were truncated for "${contextLabel}" after depth ${NOTION_MAX_BLOCK_DEPTH}.`,
    );
    return [];
  }

  if (budget.remaining <= 0) {
    pushWarningOnce(
      warnings,
      `Notion preview for "${contextLabel}" was truncated after ${NOTION_MAX_BLOCKS_PER_PAGE} blocks.`,
    );
    return [];
  }

  const blocks: NotionBlock[] = [];
  let cursor: string | null = null;

  do {
    const url = new URL(`https://api.notion.com/v1/blocks/${blockId}/children`);
    url.searchParams.set(
      "page_size",
      String(Math.min(NOTION_BLOCK_PAGE_SIZE, budget.remaining)),
    );
    if (cursor) {
      url.searchParams.set("start_cursor", cursor);
    }

    const response = await fetchNotionJson<
      NotionPaginatedResponse<NotionBlock>
    >(
      url.toString(),
      headers,
    );

    for (const block of response.results ?? []) {
      if (budget.remaining <= 0) {
        pushWarningOnce(
          warnings,
          `Notion preview for "${contextLabel}" was truncated after ${NOTION_MAX_BLOCKS_PER_PAGE} blocks.`,
        );
        return blocks;
      }

      budget.remaining -= 1;

      if (block.has_children && block.id) {
        try {
          block.children = await fetchNotionBlockTree(
            block.id,
            headers,
            warnings,
            contextLabel,
            depth + 1,
            budget,
          );
        } catch {
          pushWarningOnce(
            warnings,
            `Failed to fetch nested blocks for "${contextLabel}".`,
          );
        }
      }

      blocks.push(block);
    }

    cursor = response.has_more ? response.next_cursor ?? null : null;
  } while (cursor && budget.remaining > 0);

  return blocks;
}

async function buildNotionApiPreview(
  token: string,
  pageLimit: number,
): Promise<ImportPreviewResult> {
  const headers = {
    "Authorization": `Bearer ${token}`,
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json",
  };

  const warnings: string[] = [];
  const notes: ImportedNoteDraft[] = [];

  const pageSearchData = await fetchNotionJson<
    NotionPaginatedResponse<NotionPage>
  >(
    "https://api.notion.com/v1/search",
    headers,
    {
      method: "POST",
      body: JSON.stringify({
        filter: { property: "object", value: "page" },
        page_size: pageLimit,
      }),
    },
  );
  const pages = pageSearchData.results ?? [];

  for (const page of pages) {
    const title = extractNotionTitle(page);
    let content = "";

    try {
      const blockTree = await fetchNotionBlockTree(
        page.id,
        headers,
        warnings,
        title,
      );
      content = notionBlocksToText(blockTree);
    } catch {
      pushWarningOnce(warnings, `Failed to fetch content for "${title}".`);
    }

    notes.push({
      title,
      content,
      source: "notion_page",
      tags: [],
    });
  }

  try {
    const dbSearchData = await fetchNotionJson<
      NotionPaginatedResponse<NotionDatabase>
    >(
      "https://api.notion.com/v1/search",
      headers,
      {
        method: "POST",
        body: JSON.stringify({
          filter: { property: "object", value: "database" },
          page_size: 5,
        }),
      },
    );
    const databases = (dbSearchData.results ?? []).slice(
      0,
      NOTION_DATABASE_LIMIT,
    );

    for (const db of databases) {
      try {
        let dbCursor: string | null = null;
        let fetchedEntries = 0;

        do {
          const pageSize = Math.min(100, pageLimit - fetchedEntries);
          if (pageSize <= 0) break;

          const queryData = await fetchNotionJson<
            NotionPaginatedResponse<NotionDatabaseEntry>
          >(
            `https://api.notion.com/v1/databases/${db.id}/query`,
            headers,
            {
              method: "POST",
              body: JSON.stringify({
                page_size: pageSize,
                ...(dbCursor ? { start_cursor: dbCursor } : {}),
              }),
            },
          );

          for (const entry of queryData.results ?? []) {
            const title = extractDbEntryTitle(entry);
            const tags = extractDbEntryTags(entry);
            const content = extractDbEntryContent(entry);
            notes.push({
              title,
              content,
              source: "notion_database",
              tags,
            });
            fetchedEntries++;
          }

          dbCursor = queryData.has_more ? queryData.next_cursor ?? null : null;
        } while (dbCursor && fetchedEntries < pageLimit);
      } catch {
        pushWarningOnce(
          warnings,
          `Failed to fetch entries for database ${db.id}.`,
        );
      }
    }
  } catch {
    pushWarningOnce(warnings, "Failed to search for Notion databases.");
  }

  if (notes.length === 0) {
    warnings.push(
      "No pages or database entries found. Check your integration token and page access permissions.",
    );
  }

  return {
    sourceType: "notion_api",
    sourceLabel: "Notion (API連携)",
    fileName: "notion_api",
    notes,
    warnings,
    previewMode: "edge-function",
  };
}

function buildPreview({
  sourceType,
  fileName,
  bytes,
}: {
  sourceType: string;
  fileName: string;
  bytes: Uint8Array;
}): ImportPreviewResult {
  switch (sourceType) {
    case "notion":
      return {
        sourceType,
        sourceLabel: "Notion",
        fileName,
        notes: parseNotionCsvText(decodeText(bytes)),
        warnings: [
          "The preview checks Title / Name / Content / Text columns when available.",
        ],
        previewMode: "edge-function",
      };
    case "evernote":
      return {
        sourceType,
        sourceLabel: "Evernote",
        fileName,
        notes: parseEvernoteEnexText(decodeText(bytes)),
        warnings: [
          "The preview strips ENEX markup and imports the plain text body plus tags.",
        ],
        previewMode: "edge-function",
      };
    case "markdown":
      return {
        sourceType,
        sourceLabel: "Markdown",
        fileName,
        notes: [parseMarkdownText(decodeText(bytes), fileName)],
        warnings: [],
        previewMode: "edge-function",
      };
    default:
      throw new Error(`Unsupported import source: ${sourceType}`);
  }
}

function parseNotionCsvText(csvText: string): ImportedNoteDraft[] {
  const rows = parseCsv(csvText);
  if (rows.length <= 1) {
    return [];
  }

  const header = rows[0].map((cell) => cell.trim().toLowerCase());
  const titleIndex = findColumnIndex(header, [
    "title",
    "name",
    "note",
    "ページ",
    "タイトル",
  ]);
  const contentIndex = findColumnIndex(header, [
    "content",
    "text",
    "body",
    "plain text",
    "本文",
    "内容",
  ]);
  const tagsIndex = findColumnIndex(header, [
    "tags",
    "tag",
    "labels",
    "タグ",
  ]);

  const drafts: ImportedNoteDraft[] = [];
  for (const row of rows.slice(1)) {
    const title = readCell(row, titleIndex).trim();
    const content = readCell(row, contentIndex).trim();
    const tags = readCell(row, tagsIndex)
      .split(/[,;]/)
      .map((tag) => tag.trim())
      .filter((tag) => tag.length > 0);

    if (!title && !content) {
      continue;
    }

    drafts.push({
      title: title || "Notion import",
      content,
      source: "notion",
      tags,
    });
  }

  return drafts;
}

function parseEvernoteEnexText(enexText: string): ImportedNoteDraft[] {
  const noteMatches = [...enexText.matchAll(/<note>([\s\S]*?)<\/note>/gi)];
  const drafts: ImportedNoteDraft[] = [];

  for (const match of noteMatches) {
    const rawNote = match[1] ?? "";
    const title = extractTag(rawNote, "title").trim();
    const contentBlock = extractTag(rawNote, "content");
    const tags = [...rawNote.matchAll(/<tag>([\s\S]*?)<\/tag>/gi)]
      .map((tagMatch) => (tagMatch[1] ?? "").trim())
      .filter((tag) => tag.length > 0);

    const strippedContent = normalizeWhitespace(
      stripHtml(
        contentBlock
          .replace(/<!\[CDATA\[|\]\]>/gi, "")
          .replaceAll("&nbsp;", " ")
          .replaceAll("&amp;", "&")
          .replaceAll("&lt;", "<")
          .replaceAll("&gt;", ">"),
      ),
    );

    if (!title && !strippedContent) {
      continue;
    }

    drafts.push({
      title: title || "Evernote import",
      content: strippedContent,
      source: "evernote",
      tags,
    });
  }

  return drafts;
}

function parseMarkdownText(text: string, fileName: string): ImportedNoteDraft {
  return {
    title: deriveMarkdownTitle(text, fileName),
    content: text.trim(),
    source: "markdown",
    tags: [],
  };
}

function parseCsv(input: string): string[][] {
  const rows: string[][] = [];
  const currentRow: string[] = [];
  let currentCell = "";
  let inQuotes = false;

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    const next = index + 1 < input.length ? input[index + 1] : null;

    if (char === '"') {
      if (inQuotes && next === '"') {
        currentCell += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char === "," && !inQuotes) {
      currentRow.push(currentCell);
      currentCell = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") {
        index += 1;
      }
      currentRow.push(currentCell);
      rows.push([...currentRow]);
      currentRow.length = 0;
      currentCell = "";
      continue;
    }

    currentCell += char;
  }

  if (currentCell.length > 0 || currentRow.length > 0) {
    currentRow.push(currentCell);
    rows.push([...currentRow]);
  }

  return rows;
}

function findColumnIndex(header: string[], candidates: string[]): number {
  for (const candidate of candidates) {
    const index = header.indexOf(candidate);
    if (index !== -1) {
      return index;
    }
  }
  return -1;
}

function readCell(row: string[], index: number): string {
  if (index < 0 || index >= row.length) {
    return "";
  }
  return row[index];
}

function extractTag(source: string, tagName: string): string {
  const match = source.match(
    new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)<\\/${tagName}>`, "i"),
  );
  return match?.[1] ?? "";
}

function stripHtml(value: string): string {
  return value
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/div\s*>/gi, "\n")
    .replace(/<\/p\s*>/gi, "\n")
    .replace(/<[^>]+>/g, "");
}

function normalizeWhitespace(value: string): string {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join("\n");
}

function deriveMarkdownTitle(text: string, fileName: string): string {
  const lines = text.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("# ")) {
      return trimmed.slice(2).trim();
    }
    if (trimmed.length > 0) {
      break;
    }
  }

  const dotIndex = fileName.lastIndexOf(".");
  if (dotIndex > 0) {
    return fileName.slice(0, dotIndex);
  }
  return fileName;
}

function decodeText(bytes: Uint8Array): string {
  return new TextDecoder("utf-8").decode(bytes);
}

function decodeBase64(base64Text: string): Uint8Array {
  const normalized = base64Text.includes(",")
    ? base64Text.split(",").pop() ?? ""
    : base64Text;
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
