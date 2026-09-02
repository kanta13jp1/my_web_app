import { DOMParser } from "jsr:@b-fuze/deno-dom@0.1.56";

const MAX_SOURCE_BYTES = 1_000_000;
const MAX_REDIRECTS = 3;
const FETCH_TIMEOUT_MS = 12_000;
const TRACKING_PARAMS = new Set([
  "fbclid",
  "gclid",
  "mc_cid",
  "mc_eid",
  "ref",
]);

export type ResearchDocument = {
  sourceUrl: string;
  canonicalUrl: string;
  title: string;
  markdown: string;
  excerpt: string;
  contentType: string;
  httpStatus: number;
};

export type ResearchChunk = {
  chunkIndex: number;
  heading: string;
  location: string;
  content: string;
};

export type ResearchCitation = {
  index: number;
  sourceId: string;
  sourceUrl: string;
  title: string;
  heading: string;
  location: string;
  excerpt: string;
  score: number;
  fetchedAt: string | null;
};

type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

function normalizedHostname(url: URL): string {
  return url.hostname.toLowerCase().replace(/^\[|\]$/g, "").replace(/\.$/, "");
}

function parseIpv4(host: string): number[] | null {
  if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(host)) return null;
  const octets = host.split(".").map(Number);
  return octets.every((part) => part >= 0 && part <= 255) ? octets : null;
}

function isPrivateIpv4(octets: number[]): boolean {
  const [a, b] = octets;
  return a === 0 || a === 10 || a === 127 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0) ||
    (a === 192 && b === 168) ||
    (a === 198 && (b === 18 || b === 19)) ||
    a >= 224;
}

function isPrivateIpv6(host: string): boolean {
  const value = host.toLowerCase();
  if (!value.includes(":")) return false;
  if (value.startsWith("::") || value.startsWith("0:0:0:0:0:ffff:")) {
    return true;
  }
  if (value.startsWith("fc") || value.startsWith("fd")) return true;
  if (/^fe[89ab]/.test(value)) return true;
  if (value.startsWith("ff") || value.startsWith("64:ff9b:")) return true;
  if (value.startsWith("100:") || value.startsWith("2001:db8:")) return true;
  return false;
}

export function isPrivateNetworkHost(host: string): boolean {
  const normalized = host.toLowerCase().replace(/^\[|\]$/g, "").replace(
    /\.$/,
    "",
  );
  if (
    normalized === "localhost" || normalized.endsWith(".localhost") ||
    normalized.endsWith(".local") || normalized.endsWith(".internal") ||
    normalized.endsWith(".home") || normalized.endsWith(".lan")
  ) {
    return true;
  }
  const ipv4 = parseIpv4(normalized);
  return ipv4 ? isPrivateIpv4(ipv4) : isPrivateIpv6(normalized);
}

export function normalizePublicResearchUrl(raw: unknown): URL {
  const value = typeof raw === "string" ? raw.trim() : "";
  if (value.length === 0 || value.length > 2048) {
    throw new Error("A source URL between 1 and 2048 characters is required");
  }

  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Source URL is invalid");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new Error("Only HTTP and HTTPS sources are supported");
  }
  if (url.username || url.password) {
    throw new Error("Source URLs must not contain credentials");
  }
  if (url.port && !["80", "443"].includes(url.port)) {
    throw new Error("Source URL port is not allowed");
  }
  if (isPrivateNetworkHost(normalizedHostname(url))) {
    throw new Error("Private or local network sources are not allowed");
  }
  return url;
}

export function canonicalResearchUrl(raw: unknown): string {
  const url = normalizePublicResearchUrl(raw);
  url.hash = "";
  url.hostname = normalizedHostname(url);
  if (
    (url.protocol === "https:" && url.port === "443") ||
    (url.protocol === "http:" && url.port === "80")
  ) {
    url.port = "";
  }
  for (const key of [...url.searchParams.keys()]) {
    if (
      key.toLowerCase().startsWith("utm_") ||
      TRACKING_PARAMS.has(key.toLowerCase())
    ) {
      url.searchParams.delete(key);
    }
  }
  url.searchParams.sort();
  return url.toString();
}

function cleanInlineText(value: string): string {
  return value.replace(/\u00a0/g, " ").replace(/[ \t]+/g, " ")
    .replace(/\s*\n\s*/g, " ").trim();
}

function textExcerpt(markdown: string): string {
  return markdown.replace(/^#{1,6}\s+/gm, "").replace(/^[-*>]\s+/gm, "")
    .replace(/\s+/g, " ").trim().slice(0, 600);
}

export function htmlToResearchMarkdown(
  html: string,
  fallbackTitle = "",
): { title: string; markdown: string; excerpt: string } {
  const document = new DOMParser().parseFromString(html, "text/html");
  if (!document) throw new Error("HTML could not be parsed");

  document.querySelectorAll(
    "script,style,noscript,svg,canvas,nav,footer,header,form,dialog,template,iframe,object,embed",
  ).forEach((node) => node.remove());
  const root = document.querySelector("article,main,[role='main']") ??
    document.body;
  const title = cleanInlineText(
    document.querySelector("title")?.textContent ??
      document.querySelector("h1")?.textContent ?? fallbackTitle,
  ).slice(0, 500);
  const lines: string[] = [];
  root.querySelectorAll("h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,tr").forEach(
    (node) => {
      const text = cleanInlineText(node.textContent ?? "");
      if (text.length === 0) return;
      const tag = node.localName.toLowerCase();
      if (/^h[1-6]$/.test(tag)) {
        lines.push(`${"#".repeat(Number(tag[1]))} ${text}`);
      } else if (tag === "li") {
        lines.push(`- ${text}`);
      } else if (tag === "blockquote") {
        lines.push(`> ${text}`);
      } else if (tag === "pre") {
        lines.push(`\`\`\`\n${text.slice(0, 6000)}\n\`\`\``);
      } else {
        lines.push(text);
      }
    },
  );

  const markdown = lines.join("\n\n").replace(/\n{3,}/g, "\n\n").trim();
  if (markdown.length < 40) {
    throw new Error("Source did not contain enough readable text");
  }
  return { title, markdown, excerpt: textExcerpt(markdown) };
}

export function plainTextToResearchMarkdown(
  text: string,
  fallbackTitle = "",
): { title: string; markdown: string; excerpt: string } {
  const markdown = text.replace(/\r\n?/g, "\n").replace(/[ \t]+$/gm, "")
    .replace(/\n{4,}/g, "\n\n\n").trim();
  if (markdown.length < 40) {
    throw new Error("Source did not contain enough readable text");
  }
  return {
    title: fallbackTitle.trim().slice(0, 500),
    markdown,
    excerpt: textExcerpt(markdown),
  };
}

async function readResponseBody(response: Response): Promise<string> {
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_SOURCE_BYTES) {
    throw new Error("Source exceeds the 1 MB ingestion limit");
  }
  if (!response.body) return "";

  const reader = response.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_SOURCE_BYTES) {
      await reader.cancel();
      throw new Error("Source exceeds the 1 MB ingestion limit");
    }
    parts.push(value);
  }
  const joined = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    joined.set(part, offset);
    offset += part.byteLength;
  }
  return new TextDecoder().decode(joined);
}

async function assertPublicDns(
  host: string,
  fetcher: FetchLike,
): Promise<void> {
  if (parseIpv4(host) || host.includes(":")) return;
  const addresses = new Set<string>();
  for (const type of ["A", "AAAA"]) {
    const lookup = new URL("https://cloudflare-dns.com/dns-query");
    lookup.searchParams.set("name", host);
    lookup.searchParams.set("type", type);
    const response = await fetcher(lookup, {
      headers: { Accept: "application/dns-json" },
      signal: AbortSignal.timeout(5_000),
    });
    if (!response.ok) throw new Error("Public DNS validation is unavailable");
    const payload = await response.json() as {
      Answer?: Array<{ type?: number; data?: string }>;
    };
    for (const answer of payload.Answer ?? []) {
      if ((answer.type === 1 || answer.type === 28) && answer.data) {
        addresses.add(answer.data.replace(/^\[|\]$/g, ""));
      }
    }
  }
  if (addresses.size === 0) {
    throw new Error("Source hostname did not resolve publicly");
  }
  if ([...addresses].some(isPrivateNetworkHost)) {
    throw new Error("Source hostname resolves to a private network");
  }
}

export async function fetchPublicResearchDocument(
  rawUrl: unknown,
  fetcher: FetchLike = fetch,
): Promise<ResearchDocument> {
  let current = normalizePublicResearchUrl(rawUrl);
  const sourceUrl = current.toString();

  for (let redirect = 0; redirect <= MAX_REDIRECTS; redirect++) {
    await assertPublicDns(normalizedHostname(current), fetcher);
    const response = await fetcher(current, {
      method: "GET",
      redirect: "manual",
      headers: {
        Accept: "text/html,text/plain,text/markdown;q=0.9",
        "User-Agent": "my-web-app-company-research/1.0",
      },
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location || redirect === MAX_REDIRECTS) {
        throw new Error("Source redirect limit exceeded");
      }
      current = normalizePublicResearchUrl(
        new URL(location, current).toString(),
      );
      continue;
    }
    if (!response.ok) {
      throw new Error(`Source returned HTTP ${response.status}`);
    }

    const contentType = (response.headers.get("content-type") ?? "text/plain")
      .split(";", 1)[0].trim().toLowerCase();
    if (
      !["text/html", "application/xhtml+xml", "text/plain", "text/markdown"]
        .includes(contentType)
    ) {
      throw new Error(`Unsupported source content type: ${contentType}`);
    }
    const raw = await readResponseBody(response);
    const parsed = contentType.includes("html")
      ? htmlToResearchMarkdown(raw, current.hostname)
      : plainTextToResearchMarkdown(raw, current.hostname);
    return {
      sourceUrl,
      canonicalUrl: canonicalResearchUrl(current.toString()),
      title: parsed.title || current.hostname,
      markdown: parsed.markdown,
      excerpt: parsed.excerpt,
      contentType,
      httpStatus: response.status,
    };
  }
  throw new Error("Source redirect limit exceeded");
}

function splitLongParagraph(value: string, maxChars: number): string[] {
  const parts: string[] = [];
  let remaining = value.trim();
  while (remaining.length > maxChars) {
    const candidates = [
      remaining.lastIndexOf("\n", maxChars),
      remaining.lastIndexOf("。", maxChars),
      remaining.lastIndexOf(". ", maxChars),
      remaining.lastIndexOf(" ", maxChars),
    ];
    const splitAt = Math.max(...candidates, Math.floor(maxChars * 0.6));
    parts.push(remaining.slice(0, splitAt + 1).trim());
    remaining = remaining.slice(splitAt + 1).trim();
  }
  if (remaining) parts.push(remaining);
  return parts;
}

export function chunkResearchMarkdown(
  markdown: string,
  maxChars = 2800,
): ResearchChunk[] {
  const paragraphs = markdown.split(/\n{2,}/).map((part) => part.trim())
    .filter(Boolean).flatMap((part) => splitLongParagraph(part, maxChars));
  const chunks: ResearchChunk[] = [];
  let current: string[] = [];
  let currentLength = 0;
  let heading = "";
  let startParagraph = 1;

  const flush = (endParagraph: number) => {
    const content = current.join("\n\n").trim();
    if (!content) return;
    chunks.push({
      chunkIndex: chunks.length,
      heading,
      location: `paragraphs ${startParagraph}-${endParagraph}`,
      content,
    });
    current = [];
    currentLength = 0;
  };

  paragraphs.forEach((paragraph, index) => {
    const headingMatch = paragraph.match(/^#{1,6}\s+(.+)$/);
    if (headingMatch) heading = headingMatch[1].trim().slice(0, 500);
    const projected = currentLength + (current.length === 0 ? 0 : 2) +
      paragraph.length;
    if (current.length > 0 && projected > maxChars) {
      flush(index);
      startParagraph = index + 1;
    }
    current.push(paragraph);
    currentLength += (current.length === 1 ? 0 : 2) + paragraph.length;
  });
  flush(paragraphs.length);
  return chunks.slice(0, 200);
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  )
    .join("");
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function normalizeResearchCitations(
  rows: Array<Record<string, unknown>>,
  limit = 6,
): ResearchCitation[] {
  const seen = new Set<string>();
  const citations: ResearchCitation[] = [];
  for (const row of rows) {
    const sourceId = asString(row.source_id);
    const sourceUrl = asString(row.source_url);
    const location = asString(row.location);
    const key = `${sourceId}:${location}`;
    if (!sourceId || !sourceUrl || seen.has(key)) continue;
    seen.add(key);
    citations.push({
      index: citations.length + 1,
      sourceId,
      sourceUrl,
      title: asString(row.title) || sourceUrl,
      heading: asString(row.heading),
      location,
      excerpt: asString(row.content).replace(/\s+/g, " ").slice(0, 700),
      score: Math.max(0, asNumber(row.score)),
      fetchedAt: asString(row.fetched_at) || null,
    });
    if (citations.length >= Math.max(1, Math.min(limit, 10))) break;
  }
  return citations;
}

export function buildResearchCitationContext(
  citations: ResearchCitation[],
): string {
  if (citations.length === 0) return "";
  return citations.map((citation) =>
    [
      `[${citation.index}] ${citation.title}`,
      `URL: ${citation.sourceUrl}`,
      `Location: ${citation.heading || citation.location || "source excerpt"}`,
      `Excerpt: ${citation.excerpt}`,
    ].join("\n")
  ).join("\n\n");
}

export function ensureCitationFooter(
  result: string,
  citations: ResearchCitation[],
): string {
  if (citations.length === 0) return result.trim();
  const footer = citations.map((citation) =>
    `[${citation.index}] ${citation.title} - ${citation.sourceUrl} (${
      citation.heading || citation.location
    })`
  ).join("\n");
  return `${result.trim()}\n\nSources\n${footer}`;
}

export function buildExtractiveResearchFallback(
  taskTitle: string,
  citations: ResearchCitation[],
): string {
  const evidence = citations.slice(0, 3).map((citation) =>
    `- ${citation.excerpt} [${citation.index}]`
  ).join("\n");
  return ensureCitationFooter(
    [
      `# ${taskTitle || "Research deliverable"}`,
      "",
      "The model provider was unavailable, so this is an extractive evidence fallback.",
      "",
      evidence,
      "",
      "Next action: review the cited passages before making an irreversible decision.",
    ].join("\n"),
    citations,
  );
}
