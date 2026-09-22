import { tokenize } from "./search/bm25.ts";

const MAX_PREVIEW_CHARS = 1600;
const MAX_HIGHLIGHT_CHARS = 600;

export interface CitationEvidenceInput {
  citationId: string;
  query: string;
  filePath: string;
  title: string;
  content: string;
  snippet: string;
  sourceType: string;
  sourceUrl: string;
  metadata: Record<string, unknown>;
  confidence: number;
  lastSyncedAt: string | null;
}

interface HighlightRange {
  start: number;
  end: number;
  startLine: number;
  endLine: number;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function positiveInteger(...values: unknown[]): number | null {
  for (const value of values) {
    const parsed = typeof value === "number" ? value : Number(value);
    if (Number.isInteger(parsed) && parsed > 0) return parsed;
  }
  return null;
}

function compact(value: string, maxChars: number): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, maxChars - 3)}...`;
}

function fileNameFor(input: CitationEvidenceInput): string {
  const fromMetadata = text(
    input.metadata.file_name ?? input.metadata.filename ??
      input.metadata.document_name,
  );
  if (fromMetadata) return fromMetadata;

  for (const candidate of [input.sourceUrl, input.filePath]) {
    const withoutQuery = candidate.split(/[?#]/, 1)[0].replace(/\\/g, "/");
    const tail = withoutQuery.split("/").filter(Boolean).at(-1) ?? "";
    if (tail && !tail.includes(":")) {
      try {
        return decodeURIComponent(tail);
      } catch {
        return tail;
      }
    }
  }
  return input.title || input.filePath || `source-${input.citationId}`;
}

function findMatchIndex(
  content: string,
  query: string,
  snippet: string,
  metadata: Record<string, unknown>,
): { index: number; length: number } {
  const normalized = content.toLowerCase();
  const candidates = [
    text(metadata.highlight_text),
    query.trim(),
    ...Array.from(new Set(tokenize(query))).sort((a, b) => b.length - a.length),
    snippet.trim(),
  ].filter((candidate) => candidate.length >= 2);

  for (const candidate of candidates) {
    const index = normalized.indexOf(candidate.toLowerCase());
    if (index >= 0) return { index, length: candidate.length };
  }
  const firstContent = content.search(/\S/);
  return { index: Math.max(0, firstContent), length: 1 };
}

function lineNumberAt(content: string, offset: number): number {
  let line = 1;
  for (let index = 0; index < offset; index++) {
    if (content.charCodeAt(index) === 10) line++;
  }
  return line;
}

function highlightRange(
  content: string,
  query: string,
  snippet: string,
  metadata: Record<string, unknown>,
): HighlightRange {
  if (!content) {
    return { start: 0, end: 0, startLine: 1, endLine: 1 };
  }
  const match = findMatchIndex(content, query, snippet, metadata);
  let start = content.lastIndexOf("\n", Math.max(0, match.index - 1)) + 1;
  let end = content.indexOf("\n", match.index + match.length);
  if (end < 0) end = content.length;

  while (start < end && /\s/.test(content[start])) start++;
  while (end > start && /\s/.test(content[end - 1])) end--;

  if (end - start > MAX_HIGHLIGHT_CHARS) {
    start = Math.max(start, match.index - 180);
    end = Math.min(end, start + MAX_HIGHLIGHT_CHARS);
    if (match.index + match.length > end) {
      end = Math.min(content.length, match.index + match.length + 180);
      start = Math.max(0, end - MAX_HIGHLIGHT_CHARS);
    }
  }
  if (end <= start) {
    start = match.index;
    end = Math.min(content.length, match.index + Math.max(1, match.length));
  }

  return {
    start,
    end,
    startLine: lineNumberAt(content, start),
    endLine: lineNumberAt(content, Math.max(start, end - 1)),
  };
}

function previewWindow(content: string, range: HighlightRange) {
  if (!content) {
    return {
      previewText: "",
      highlightStart: 0,
      highlightEnd: 0,
      truncatedBefore: false,
      truncatedAfter: false,
    };
  }

  let previewStart = Math.max(0, range.start - 450);
  let previewEnd = Math.min(content.length, range.end + 450);
  if (previewEnd - previewStart > MAX_PREVIEW_CHARS) {
    previewStart = Math.max(0, range.start - 350);
    previewEnd = Math.min(content.length, previewStart + MAX_PREVIEW_CHARS);
    if (range.end > previewEnd) {
      previewEnd = Math.min(content.length, range.end + 150);
      previewStart = Math.max(0, previewEnd - MAX_PREVIEW_CHARS);
    }
  }

  if (previewStart > 0) {
    const boundary = content.indexOf("\n", previewStart);
    if (boundary >= 0 && boundary < range.start) previewStart = boundary + 1;
  }
  if (previewEnd < content.length) {
    const boundary = content.lastIndexOf("\n", previewEnd);
    if (boundary > range.end) previewEnd = boundary;
  }

  return {
    previewText: content.slice(previewStart, previewEnd),
    highlightStart: range.start - previewStart,
    highlightEnd: range.end - previewStart,
    truncatedBefore: previewStart > 0,
    truncatedAfter: previewEnd < content.length,
  };
}

export function buildCitationEvidence(input: CitationEvidenceInput) {
  const content = input.content || input.snippet || input.title ||
    input.filePath;
  const range = highlightRange(
    content,
    input.query,
    input.snippet,
    input.metadata,
  );
  const preview = previewWindow(content, range);
  const explicitStartLine = positiveInteger(
    input.metadata.start_line,
    input.metadata.line_start,
  );
  const explicitEndLine = positiveInteger(
    input.metadata.end_line,
    input.metadata.line_end,
  );
  const startLine = explicitStartLine ?? range.startLine;
  const endLine = explicitEndLine ??
    (explicitStartLine == null ? range.endLine : explicitStartLine);
  const pageNumber = positiveInteger(
    input.metadata.page_number,
    input.metadata.page,
  );
  const section = text(
    input.metadata.section ?? input.metadata.heading ??
      input.metadata.section_title,
  );
  const locationParts: string[] = [];
  if (pageNumber != null) locationParts.push(`page ${pageNumber}`);
  if (section) locationParts.push(section);
  locationParts.push(
    startLine == endLine
      ? `line ${startLine}`
      : `lines ${startLine}-${endLine}`,
  );

  return {
    citation_id: input.citationId,
    source_type: input.sourceType,
    source_url: input.sourceUrl,
    title: input.title || fileNameFor(input),
    file_name: fileNameFor(input),
    excerpt: compact(content.slice(range.start, range.end), 280),
    preview_text: preview.previewText,
    highlight_start: preview.highlightStart,
    highlight_end: preview.highlightEnd,
    highlight_text: content.slice(range.start, range.end),
    preview_truncated_before: preview.truncatedBefore,
    preview_truncated_after: preview.truncatedAfter,
    position: {
      page_number: pageNumber,
      section: section || null,
      start_line: startLine,
      end_line: endLine,
      label: locationParts.join(" · "),
    },
    confidence: Number(Math.max(0, Math.min(1, input.confidence)).toFixed(4)),
    last_synced_at: input.lastSyncedAt,
  };
}

export function hasOnlyValidCitationMarkers(
  answer: string,
  citationCount: number,
): boolean {
  if (citationCount <= 0) return false;
  const markers = Array.from(answer.matchAll(/\[(\d+)\]/g));
  if (markers.length === 0) return false;
  return markers.every((marker) => {
    const citationNumber = Number(marker[1]);
    return Number.isInteger(citationNumber) &&
      citationNumber >= 1 &&
      citationNumber <= citationCount;
  });
}
