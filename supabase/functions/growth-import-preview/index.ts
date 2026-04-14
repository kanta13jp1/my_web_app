import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { buildNotionApiPreview } from "./notion_api.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ImportPreviewRequest {
  sourceType: string;
  fileName?: string;
  contentBase64?: string;
  // Notion API 直接連携用
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

    // Notion API 直接連携ルート
    if (sourceType === "notion_api") {
      const notionToken = body.notionToken?.trim();
      if (!notionToken) throw new Error("notionToken is required for notion_api.");
      const pageLimit = Math.min(body.pageLimit ?? 10, 20);
      const preview = await buildNotionApiPreview(notionToken, pageLimit);
      return jsonResponse({ success: true, preview });
    }

    // ファイルベースルート (従来)
    const fileName = body.fileName?.trim();
    const contentBase64 = body.contentBase64?.trim();
    if (!fileName || !contentBase64) {
      throw new Error("fileName and contentBase64 are required for file-based import.");
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

// ── ファイルベース import ────────────────────────────────────────────────────

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
  ]);
  const tagsIndex = findColumnIndex(header, ["tags", "tag", "labels"]);

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
