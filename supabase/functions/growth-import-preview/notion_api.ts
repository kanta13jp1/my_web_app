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

interface NotionPage {
  id: string;
  properties?: Record<string, NotionProperty>;
}

interface NotionDatabase {
  id: string;
}

interface NotionDatabaseEntry {
  id: string;
  properties?: Record<string, NotionProperty>;
}

interface NotionBlockInner {
  rich_text?: NotionRichText[];
  checked?: boolean;
  title?: string;
  language?: string;
}

export interface NotionBlockNode {
  id?: string;
  type: string;
  has_children?: boolean;
  children?: NotionBlockNode[];
  [key: string]: unknown;
}

interface NotionListResponse<T> {
  results?: T[];
  has_more?: boolean;
  next_cursor?: string | null;
}

type FetchImpl = typeof fetch;
type SleepImpl = (ms: number) => Promise<void>;

interface RetryOptions {
  fetchImpl?: FetchImpl;
  sleep?: SleepImpl;
  maxRetries?: number;
}

interface BlockTreeOptions extends RetryOptions {
  headers: HeadersInit;
  maxDepth?: number;
  maxBlocks?: number;
}

const defaultSleep: SleepImpl = (ms) =>
  new Promise((resolve) => setTimeout(resolve, ms));

function readRetryDelayMs(response: Response, attempt: number): number {
  const retryAfter = Number(response.headers.get("Retry-After"));
  if (Number.isFinite(retryAfter) && retryAfter > 0) {
    return retryAfter * 1000;
  }
  return Math.min(1000 * (attempt + 1), 4000);
}

export async function fetchNotionJsonWithRetry<T>(
  url: string,
  init: RequestInit,
  options: RetryOptions = {},
): Promise<T> {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const sleep = options.sleep ?? defaultSleep;
  const maxRetries = options.maxRetries ?? 3;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const response = await fetchImpl(url, init);
    if (response.ok) {
      return await response.json() as T;
    }

    if (response.status === 429 && attempt < maxRetries) {
      await sleep(readRetryDelayMs(response, attempt));
      continue;
    }

    const errorText = await response.text();
    throw new Error(`Notion API error (${response.status}): ${errorText}`);
  }

  throw new Error("Notion API retry limit exceeded.");
}

function richTextToPlainText(texts?: NotionRichText[]): string {
  return (texts ?? []).map((text) => text.plain_text ?? "").join("").trim();
}

function extractNotionTitle(page: NotionPage): string {
  for (const property of Object.values(page.properties ?? {})) {
    const text = richTextToPlainText(property.title ?? property.rich_text);
    if (text) return text;
  }
  return "Notion Page";
}

function extractDbEntryTitle(entry: NotionDatabaseEntry): string {
  for (const property of Object.values(entry.properties ?? {})) {
    if (property.type !== "title") continue;
    const text = richTextToPlainText(property.title);
    if (text) return text;
  }
  return "Database Entry";
}

function extractDbEntryTags(entry: NotionDatabaseEntry): string[] {
  const tags: string[] = [];
  for (const property of Object.values(entry.properties ?? {})) {
    if (property.type === "multi_select" && property.multi_select) {
      for (const option of property.multi_select) {
        if (option.name) tags.push(option.name);
      }
      continue;
    }
    if (property.type === "select" && property.select?.name) {
      tags.push(property.select.name);
    }
  }
  return tags;
}

function extractDbEntryContent(entry: NotionDatabaseEntry): string {
  const lines: string[] = [];
  for (const [key, property] of Object.entries(entry.properties ?? {})) {
    if (property.type === "title") continue;

    if (property.type === "rich_text" && property.rich_text?.length) {
      const text = richTextToPlainText(property.rich_text);
      if (text) lines.push(`${key}: ${text}`);
      continue;
    }

    if (
      property.type === "number" &&
      property.number !== null &&
      property.number !== undefined
    ) {
      lines.push(`${key}: ${property.number}`);
      continue;
    }

    if (property.type === "checkbox" && property.checkbox !== undefined) {
      lines.push(`${key}: ${property.checkbox ? "yes" : "no"}`);
      continue;
    }

    if (property.type === "date" && property.date?.start) {
      lines.push(`${key}: ${property.date.start}`);
    }
  }

  return lines.join("\n");
}

function extractBlockText(block: NotionBlockNode): string {
  const inner = block[block.type] as NotionBlockInner | undefined;

  switch (block.type) {
    case "child_page":
    case "child_database":
      return inner?.title?.trim() ?? "";
    default:
      return richTextToPlainText(inner?.rich_text);
  }
}

function blockPrefix(block: NotionBlockNode): string {
  const inner = block[block.type] as NotionBlockInner | undefined;

  switch (block.type) {
    case "heading_1":
      return "# ";
    case "heading_2":
      return "## ";
    case "heading_3":
      return "### ";
    case "bulleted_list_item":
      return "- ";
    case "numbered_list_item":
      return "1. ";
    case "to_do":
      return inner?.checked ? "- [x] " : "- [ ] ";
    case "quote":
      return "> ";
    case "callout":
      return "! ";
    case "toggle":
      return "> ";
    case "child_page":
      return "Page: ";
    case "child_database":
      return "Database: ";
    default:
      return "";
  }
}

export function notionBlocksToText(
  blocks: NotionBlockNode[],
  depth = 0,
): string {
  const lines: string[] = [];

  for (const block of blocks) {
    const text = extractBlockText(block);
    const indent = "  ".repeat(depth);

    if (text) {
      if (block.type === "code") {
        const language = ((block[block.type] as NotionBlockInner | undefined)
          ?.language ?? "").trim();
        lines.push(`${indent}\`\`\`${language}`);
        for (const line of text.split("\n")) {
          lines.push(`${indent}${line}`);
        }
        lines.push(`${indent}\`\`\``);
      } else {
        lines.push(`${indent}${blockPrefix(block)}${text}`.trimRight());
      }
    }

    if (block.children?.length) {
      const childText = notionBlocksToText(block.children, depth + 1);
      if (childText) lines.push(childText);
    }
  }

  return lines.join("\n").trimEnd();
}

async function searchNotionObjects<T>(
  objectType: "page" | "database",
  limit: number,
  headers: HeadersInit,
  options: RetryOptions = {},
): Promise<T[]> {
  const results: T[] = [];
  let nextCursor: string | undefined;

  while (results.length < limit) {
    const requestBody = {
      filter: { property: "object", value: objectType },
      page_size: Math.min(100, limit - results.length),
      ...(nextCursor ? { start_cursor: nextCursor } : {}),
    };

    const data = await fetchNotionJsonWithRetry<NotionListResponse<T>>(
      "https://api.notion.com/v1/search",
      {
        method: "POST",
        headers,
        body: JSON.stringify(requestBody),
      },
      options,
    );

    results.push(...(data.results ?? []).slice(0, limit - results.length));
    if (!data.has_more || !data.next_cursor) break;
    nextCursor = data.next_cursor;
  }

  return results;
}

export async function fetchNotionBlockTree(
  blockId: string,
  options: BlockTreeOptions,
): Promise<{ blocks: NotionBlockNode[]; warnings: string[] }> {
  const warnings: string[] = [];
  const state = {
    remainingBlocks: options.maxBlocks ?? 200,
    warnedDepth: false,
    warnedLimit: false,
  };
  const maxDepth = options.maxDepth ?? 2;

  const fetchChildren = async (
    currentBlockId: string,
    depth: number,
  ): Promise<NotionBlockNode[]> => {
    let nextCursor: string | undefined;
    const blocks: NotionBlockNode[] = [];

    while (state.remainingBlocks > 0) {
      const url = new URL(
        `https://api.notion.com/v1/blocks/${currentBlockId}/children`,
      );
      url.searchParams.set("page_size", "100");
      if (nextCursor) {
        url.searchParams.set("start_cursor", nextCursor);
      }

      const data = await fetchNotionJsonWithRetry<NotionListResponse<NotionBlockNode>>(
        url.toString(),
        { headers: options.headers },
        options,
      );

      for (const rawBlock of data.results ?? []) {
        if (state.remainingBlocks <= 0) {
          if (!state.warnedLimit) {
            warnings.push(
              "Notion preview truncated after 200 blocks to keep the preview responsive.",
            );
            state.warnedLimit = true;
          }
          break;
        }

        state.remainingBlocks--;
        const block: NotionBlockNode = { ...rawBlock };

        if (block.has_children && block.id) {
          if (depth >= maxDepth) {
            if (!state.warnedDepth) {
              warnings.push(
                `Nested Notion blocks deeper than ${maxDepth + 1} levels were truncated in the preview.`,
              );
              state.warnedDepth = true;
            }
          } else {
            block.children = await fetchChildren(block.id, depth + 1);
          }
        }

        blocks.push(block);
      }

      if (!data.has_more || !data.next_cursor) break;
      nextCursor = data.next_cursor;
    }

    return blocks;
  };

  return { blocks: await fetchChildren(blockId, 0), warnings };
}

export async function buildNotionApiPreview(
  token: string,
  pageLimit: number,
  options: RetryOptions = {},
): Promise<ImportPreviewResult> {
  const headers = {
    Authorization: `Bearer ${token}`,
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json",
  };

  const warnings: string[] = [];
  const notes: ImportedNoteDraft[] = [];

  const pages = await searchNotionObjects<NotionPage>(
    "page",
    pageLimit,
    headers,
    options,
  );

  for (const page of pages) {
    const title = extractNotionTitle(page);
    let content = "";

    try {
      const blockTree = await fetchNotionBlockTree(page.id, {
        headers,
        ...options,
      });
      content = notionBlocksToText(blockTree.blocks);
      warnings.push(...blockTree.warnings);
    } catch {
      warnings.push(`Failed to fetch content for "${title}".`);
    }

    notes.push({
      title,
      content,
      source: "notion_page",
      tags: [],
    });
  }

  try {
    const databases = await searchNotionObjects<NotionDatabase>(
      "database",
      3,
      headers,
      options,
    );

    for (const database of databases) {
      const entriesPerDatabase = Math.min(5, pageLimit);
      const queryData = await fetchNotionJsonWithRetry<
        NotionListResponse<NotionDatabaseEntry>
      >(
        `https://api.notion.com/v1/databases/${database.id}/query`,
        {
          method: "POST",
          headers,
          body: JSON.stringify({ page_size: entriesPerDatabase }),
        },
        options,
      );

      for (const entry of queryData.results ?? []) {
        notes.push({
          title: extractDbEntryTitle(entry),
          content: extractDbEntryContent(entry),
          source: "notion_database",
          tags: extractDbEntryTags(entry),
        });
      }
    }
  } catch {
    warnings.push("Failed to search for Notion databases.");
  }

  if (notes.length === 0) {
    warnings.push(
      "No pages or database entries found. Check the integration token and page access permissions.",
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
