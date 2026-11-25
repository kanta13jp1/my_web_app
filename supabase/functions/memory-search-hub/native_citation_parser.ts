export interface ParsedCitationSegment {
  text: string;
  reference_id?: string;
  marker_only?: boolean;
}

export interface ParsedNativeAnswer {
  plain_text: string;
  segments: ParsedCitationSegment[];
  reference_ids: string[];
  has_native_tokens: boolean;
}

const ANSWER_START = "<|answer_start|>";
const ANSWER_END = "<|answer_end|>";
const CITATION_START = "<|citation_start|>";
const CITATION_END = "<|citation_end|>";
const SOURCE_START = "<|source_start|>";
const SOURCE_END = "<|source_end|>";

const SOURCE_CLOSE_TOKENS = [
  "<|/source|>",
  "<|source_close|>",
  "<|source_stop|>",
  "<|source_finish|>",
];

const CITATION_CLOSE_TOKENS = [
  "<|/citation|>",
  "<|citation_close|>",
  "<|citation_stop|>",
  "<|citation_finish|>",
  ...SOURCE_CLOSE_TOKENS,
];

const ANSWER_STRIP_RE = /<\|\/?(?:answer_start|answer_end|answer)\|>/gi;
const REF_OPEN_RE = /<ref\b([^>]*)>/gi;
const BRACKET_SOURCE_RE = /\[source\s*:\s*([^\]]+)\]/gi;
const NUMERIC_BRACKET_RE = /\[(\d+)\](?!\()/g;
const REF_ATTR_RE = new RegExp(
  "\\b(?:reference_id|source_id|source|id|ref|doc|name)\\s*=\\s*" +
    "(?:\"([^\"]+)\"|'([^']+)'|([^\\s\"'>/]+))",
  "i",
);

export function normalizeCitationReferenceId(raw: string): string {
  return raw
    .trim()
    .replace(/^(?:source|reference|ref|id)\s*:\s*/i, "")
    .trim();
}

function extractAnswerEnvelope(
  raw: string,
): { text: string; hadAnswerTokens: boolean } {
  const startIdx = raw.indexOf(ANSWER_START);
  const endIdx = raw.indexOf(ANSWER_END);
  if (startIdx < 0 && endIdx < 0) {
    return { text: raw, hadAnswerTokens: false };
  }
  let sliced = raw;
  if (startIdx >= 0) {
    const bodyStart = startIdx + ANSWER_START.length;
    const bodyEnd = raw.indexOf(ANSWER_END, bodyStart);
    sliced = bodyEnd >= 0
      ? raw.slice(bodyStart, bodyEnd)
      : raw.slice(bodyStart);
  }
  return {
    text: sliced.replace(ANSWER_STRIP_RE, "").trim(),
    hadAnswerTokens: true,
  };
}

function findFirstMatch(
  re: RegExp,
  input: string,
  fromIndex: number,
): RegExpExecArray | null {
  re.lastIndex = fromIndex;
  return re.exec(input);
}

function findEarliestCloseToken(
  input: string,
  fromIndex: number,
  closingTags: string[],
): { index: number; token: string } | null {
  let best: { index: number; token: string } | null = null;
  for (const tag of closingTags) {
    const idx = input.indexOf(tag, fromIndex);
    if (idx < 0) continue;
    if (best === null || idx < best.index) {
      best = { index: idx, token: tag };
    }
  }
  return best;
}

function parseRefIdFromAttributes(attrsRaw: string): string {
  const trimmed = attrsRaw.replace(/\/$/, "").trim();
  if (!trimmed) return "";
  const attrMatch = REF_ATTR_RE.exec(trimmed);
  if (attrMatch) {
    return normalizeCitationReferenceId(
      attrMatch[1] ?? attrMatch[2] ?? attrMatch[3] ?? "",
    );
  }
  if (/^(?:source\s*:\s*)?[A-Za-z0-9._-]+$/i.test(trimmed)) {
    return normalizeCitationReferenceId(trimmed);
  }
  return "";
}

function isBareReferenceId(value: string): boolean {
  const trimmed = value.trim();
  return /^(?:source\s*:\s*)?(?:\d+|(?:doc|source)[-_][A-Za-z0-9._-]+)$/i
    .test(trimmed);
}

function mergeSegments(
  items: ParsedCitationSegment[],
): ParsedCitationSegment[] {
  const merged: ParsedCitationSegment[] = [];
  for (const item of items) {
    if (!item.text) continue;
    const prev = merged.at(-1);
    if (
      prev &&
      !prev.reference_id &&
      !item.reference_id &&
      !prev.marker_only &&
      !item.marker_only
    ) {
      prev.text += item.text;
    } else {
      merged.push({ ...item });
    }
  }
  return merged;
}

export function parseNativeCitations(raw: string): ParsedNativeAnswer {
  if (!raw) {
    return {
      plain_text: "",
      segments: [],
      reference_ids: [],
      has_native_tokens: false,
    };
  }

  const envelope = extractAnswerEnvelope(raw);
  const text = envelope.text;
  const segments: ParsedCitationSegment[] = [];
  const refIds: string[] = [];
  const seenRefs = new Set<string>();
  let found = envelope.hadAnswerTokens;
  let cursor = 0;

  const pushRefId = (id: string) => {
    if (id && !seenRefs.has(id)) {
      seenRefs.add(id);
      refIds.push(id);
    }
  };

  const pushPlain = (value: string) => {
    if (value) segments.push({ text: value });
  };

  const pushCited = (value: string, id: string, markerOnly = false) => {
    if (id) pushRefId(id);
    if (markerOnly) {
      segments.push({
        text: value,
        ...(id ? { reference_id: id } : {}),
        marker_only: true,
      });
    } else if (value) {
      segments.push({
        text: value,
        ...(id ? { reference_id: id } : {}),
      });
    }
  };

  while (cursor < text.length) {
    const candidates: Array<{
      kind: "source" | "citation" | "ref" | "bracket_source" | "numeric";
      index: number;
      match?: RegExpExecArray;
    }> = [];

    const sourceIdx = text.indexOf(SOURCE_START, cursor);
    if (sourceIdx >= 0) {
      candidates.push({ kind: "source", index: sourceIdx });
    }

    const citationIdx = text.indexOf(CITATION_START, cursor);
    if (citationIdx >= 0) {
      candidates.push({ kind: "citation", index: citationIdx });
    }

    const refMatch = findFirstMatch(REF_OPEN_RE, text, cursor);
    if (refMatch) {
      candidates.push({ kind: "ref", index: refMatch.index, match: refMatch });
    }

    const bSourceMatch = findFirstMatch(BRACKET_SOURCE_RE, text, cursor);
    if (bSourceMatch) {
      candidates.push({
        kind: "bracket_source",
        index: bSourceMatch.index,
        match: bSourceMatch,
      });
    }

    const numMatch = findFirstMatch(NUMERIC_BRACKET_RE, text, cursor);
    if (numMatch) {
      candidates.push({
        kind: "numeric",
        index: numMatch.index,
        match: numMatch,
      });
    }

    if (candidates.length === 0) {
      pushPlain(text.slice(cursor));
      break;
    }

    candidates.sort((a, b) => a.index - b.index);
    const next = candidates[0];
    pushPlain(text.slice(cursor, next.index));

    if (next.kind === "numeric" && next.match) {
      const id = next.match[1].trim();
      found = true;
      pushCited(`[${id}]`, id, true);
      cursor = next.index + next.match[0].length;
      continue;
    }

    if (next.kind === "bracket_source" && next.match) {
      const id = normalizeCitationReferenceId(next.match[1]);
      found = true;
      pushCited(`[source:${id}]`, id, true);
      cursor = next.index + next.match[0].length;
      continue;
    }

    if (next.kind === "source") {
      const idStart = next.index + SOURCE_START.length;
      const idEnd = text.indexOf(SOURCE_END, idStart);
      if (idEnd < 0) {
        pushPlain(text.slice(next.index));
        break;
      }
      const id = normalizeCitationReferenceId(text.slice(idStart, idEnd));
      const bodyStart = idEnd + SOURCE_END.length;
      const close = findEarliestCloseToken(
        text,
        bodyStart,
        SOURCE_CLOSE_TOKENS,
      );
      found = true;
      if (!close) {
        pushCited(`[source:${id}]`, id, true);
        cursor = bodyStart;
        continue;
      }
      const citedText = text.slice(bodyStart, close.index);
      if (!citedText) {
        pushCited(`[source:${id}]`, id, true);
      } else {
        pushCited(citedText, id, false);
      }
      cursor = close.index + close.token.length;
      continue;
    }

    if (next.kind === "citation") {
      const innerStart = next.index + CITATION_START.length;
      const endIdx = text.indexOf(CITATION_END, innerStart);
      if (endIdx < 0) {
        found = true;
        cursor = innerStart;
        continue;
      }
      found = true;
      const inner = text.slice(innerStart, endIdx);
      const afterEnd = endIdx + CITATION_END.length;
      const close = findEarliestCloseToken(
        text,
        afterEnd,
        CITATION_CLOSE_TOKENS,
      );
      const nextCitationStart = text.indexOf(CITATION_START, afterEnd);
      const pairedClose = close &&
          (nextCitationStart < 0 || close.index < nextCitationStart)
        ? close
        : null;
      if (pairedClose && isBareReferenceId(inner)) {
        const id = normalizeCitationReferenceId(inner);
        const citedText = text.slice(afterEnd, pairedClose.index);
        if (!citedText) {
          pushCited(`[source:${id}]`, id, true);
        } else {
          pushCited(citedText, id, false);
        }
        cursor = pairedClose.index + pairedClose.token.length;
        continue;
      }
      const nested = parseNativeCitations(inner);
      for (const seg of nested.segments) {
        pushCited(seg.text, seg.reference_id ?? "", Boolean(seg.marker_only));
      }
      cursor = afterEnd;
      continue;
    }

    if (next.kind === "ref" && next.match) {
      found = true;
      const rawTag = next.match[0];
      const attrs = next.match[1] ?? "";
      const attrId = parseRefIdFromAttributes(attrs);
      const tagEnd = next.index + rawTag.length;
      if (rawTag.trimEnd().endsWith("/>")) {
        if (attrId) {
          pushCited(`[source:${attrId}]`, attrId, true);
        }
        cursor = tagEnd;
        continue;
      }
      const closeTagIdx = text.toLowerCase().indexOf("</ref>", tagEnd);
      if (closeTagIdx < 0) {
        if (attrId) {
          pushCited(`[source:${attrId}]`, attrId, true);
        }
        cursor = tagEnd;
        continue;
      }
      const inner = text.slice(tagEnd, closeTagIdx);
      if (attrId) {
        if (!inner.trim()) {
          pushCited(`[source:${attrId}]`, attrId, true);
        } else {
          pushCited(inner, attrId, false);
        }
      } else if (isBareReferenceId(inner)) {
        const bareId = normalizeCitationReferenceId(inner);
        pushCited(`[source:${bareId}]`, bareId, true);
      } else {
        pushPlain(inner);
      }
      cursor = closeTagIdx + "</ref>".length;
      continue;
    }
  }

  const normalized = mergeSegments(segments);
  return {
    plain_text: normalized.map((s) => s.text).join(""),
    segments: normalized,
    reference_ids: refIds,
    has_native_tokens: found,
  };
}
