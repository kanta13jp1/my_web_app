export const MAX_TITLE_LENGTH = 200;
export const MAX_CONTENT_LENGTH = 100000;
export const MAX_TAGS = 20;
export const MAX_TAG_LENGTH = 40;
export const MAX_SOURCE_KEY_LENGTH = 160;

/**
 * Only allow http/https URLs in saved note metadata.
 * Rejects javascript:, data:, chrome:, file:, and malformed URLs.
 */
export function sanitizeClipUrl(rawUrl) {
  if (typeof rawUrl !== 'string') return null;
  const trimmed = rawUrl.trim();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

/**
 * Normalizes comma/whitespace separated tags, stripping leading '#' and deduplicating.
 */
export function normalizeTagsInput(rawInput, { includeDefaultTag = true } = {}) {
  const tokens = [];
  if (typeof rawInput === 'string' && rawInput.trim()) {
    tokens.push(...rawInput.split(/[,\s、]+/));
  } else if (Array.isArray(rawInput)) {
    for (const item of rawInput) {
      if (typeof item === 'string') {
        tokens.push(item);
      }
    }
  }
  if (includeDefaultTag) {
    tokens.push('web-clip');
  }
  const seen = new Set();
  const out = [];
  for (const raw of tokens) {
    const cleaned = raw.trim().replace(/^#+/, '');
    if (!cleaned || cleaned.length > MAX_TAG_LENGTH) continue;
    const dedupeKey = cleaned.toLowerCase();
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    out.push(cleaned);
    if (out.length >= MAX_TAGS) break;
  }
  return out;
}

function fnv1aHex(input) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

/**
 * Builds a deterministic source_key within MAX_SOURCE_KEY_LENGTH chars.
 */
export function buildSourceKey(url, mode = 'article') {
  const safeMode = ['article', 'selection', 'bookmark'].includes(mode)
    ? mode
    : 'article';
  const safeUrl = sanitizeClipUrl(url) ?? String(url ?? 'about:blank').trim();
  const primaryHash = fnv1aHex(safeUrl);
  const secondaryHash = fnv1aHex(`${safeMode}:${safeUrl}`);
  const key = `web-clip:${safeMode}:${primaryHash}${secondaryHash}`;
  return key.slice(0, MAX_SOURCE_KEY_LENGTH);
}

function truncateText(text, maxLength) {
  if (text.length <= maxLength) return text;
  if (maxLength <= 1) return text.slice(0, maxLength);
  return `${text.slice(0, maxLength - 1)}…`;
}

/**
 * Formats extracted page content into Markdown suitable for public.notes.content.
 */
export function buildClipMarkdown({
  title,
  url,
  excerpt = '',
  markdownBody = '',
  selectedText = '',
  clippedAtIso = new Date().toISOString(),
  mode = 'article',
}) {
  const safeUrl = sanitizeClipUrl(url);
  const resolvedTitle = truncateText(
    (typeof title === 'string' && title.trim()) ||
      safeUrl ||
      'Webクリップ',
    MAX_TITLE_LENGTH,
  );
  const safeMode = ['article', 'selection', 'bookmark'].includes(mode)
    ? mode
    : 'article';

  const headerLines = [];
  if (safeUrl) {
    headerLines.push(`> 出典: [${safeUrl}](${safeUrl})`);
  }
  headerLines.push(`> クリップ日時: ${clippedAtIso}`);
  if (excerpt && typeof excerpt === 'string' && excerpt.trim() && safeMode === 'article') {
    headerLines.push(`> 概要: ${excerpt.trim().replace(/\r?\n+/g, ' ')}`);
  }

  let bodySection = '';
  if (safeMode === 'selection') {
    const picked = (typeof selectedText === 'string' ? selectedText : '').trim();
    bodySection = picked
      ? picked
          .split(/\r?\n/)
          .map((line) => (line.trim() ? `> ${line}` : '>'))
          .join('\n')
      : (typeof markdownBody === 'string' ? markdownBody.trim() : '');
  } else if (safeMode === 'bookmark') {
    bodySection = safeUrl ? `- 保存リンク: ${safeUrl}` : '';
  } else {
    bodySection = (typeof markdownBody === 'string' ? markdownBody : '').trim();
    if (!bodySection && typeof selectedText === 'string' && selectedText.trim()) {
      bodySection = selectedText.trim();
    }
  }

  const parts = [headerLines.join('\n')];
  if (bodySection) {
    parts.push(bodySection);
  }
  const combined = truncateText(parts.join('\n\n'), MAX_CONTENT_LENGTH);

  return {
    title: resolvedTitle,
    content: combined,
    url: safeUrl,
    mode: safeMode,
  };
}
