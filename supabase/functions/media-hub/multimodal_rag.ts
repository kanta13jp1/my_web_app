import { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const MULTIMODAL_RAG_BUCKET = "multimodal-rag-media";
export const GEMINI_EMBEDDING_2_MODEL = "gemini-embedding-2";
export const EMBEDDING_DIMENSION = 768;
export const MAX_MEDIA_BYTES = 10 * 1024 * 1024;
export const MAX_CHUNKS_PER_ITEM = 32;
export const SIGNED_URL_TTL_SECONDS = 300;

export type MultimodalModality =
  | "text"
  | "image"
  | "audio"
  | "video"
  | "pdf"
  | "mixed";

export type ChunkModality = "text" | "image" | "audio" | "video" | "pdf";

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface MultimodalChunkSpec {
  chunkIndex: number;
  modality: ChunkModality;
  textExcerpt: string;
  startOffsetSec: number | null;
  endOffsetSec: number | null;
  pageStart: number | null;
  pageEnd: number | null;
}

export interface EmbeddingPartInput {
  text?: string;
  inlineData?: {
    mimeType: string;
    dataBase64: string;
  };
}

export interface EmbeddingResult {
  vector: number[];
  model: "gemini-embedding-2" | "deterministic-fallback";
  mode: "live" | "offline_fallback";
}

export interface MultimodalSearchHitRow {
  id: string;
  source_key: string;
  title: string;
  modality: MultimodalModality;
  mime_type: string;
  storage_object_path: string | null;
  content_text: string;
  chunk_count: number;
  embedding_model: string;
  embedding_mode: string;
  embedding: number[] | string | null;
  updated_at: string;
}

const VALID_MODALITIES = new Set<MultimodalModality>([
  "text",
  "image",
  "audio",
  "video",
  "pdf",
  "mixed",
]);

const MIME_TO_EXTENSION: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "application/pdf": "pdf",
  "audio/mpeg": "mp3",
  "audio/wav": "wav",
  "video/mp4": "mp4",
};

const TEXT_MIME_TYPES = new Set<string>(["text/plain", "text/markdown"]);

export function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function asOptionalInt(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Math.floor(parsed);
}

export function normalizeSourceKey(rawKey: string, fallbackTitle: string): string {
  const base = (rawKey || fallbackTitle || "multimodal-item")
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return (base || "multimodal-item").slice(0, 120);
}

export function normalizeModality(
  value: unknown,
  mimeType: string,
  hasText: boolean,
  hasMedia: boolean,
): MultimodalModality {
  const raw = asTrimmedString(value).toLowerCase() as MultimodalModality;
  if (VALID_MODALITIES.has(raw)) {
    return raw;
  }
  if (hasText && hasMedia) return "mixed";
  if (mimeType.startsWith("image/")) return "image";
  if (mimeType.startsWith("audio/")) return "audio";
  if (mimeType.startsWith("video/")) return "video";
  if (mimeType === "application/pdf") return "pdf";
  return "text";
}

export function decodeAndVerifyMediaBase64(
  base64Raw: string,
  mimeTypeRaw: string,
): { bytes: Uint8Array; mimeType: string; extension: string } | { error: string } {
  const mimeType = asTrimmedString(mimeTypeRaw).toLowerCase();
  const extension = MIME_TO_EXTENSION[mimeType];
  if (!extension) {
    return {
      error:
        `Unsupported media MIME type '${mimeType}'. Allowed: ${
          Object.keys(MIME_TO_EXTENSION).join(", ")
        }`,
    };
  }

  const normalizedB64 = base64Raw
    .trim()
    .replace(/^data:[^;]+;base64,/i, "")
    .replace(/\s+/g, "");
  if (!normalizedB64) {
    return { error: "Media base64 payload must not be empty." };
  }

  let bytes: Uint8Array;
  try {
    const binary = atob(normalizedB64);
    bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
  } catch {
    return { error: "Invalid base64 encoding for media payload." };
  }

  if (bytes.length === 0 || bytes.length > MAX_MEDIA_BYTES) {
    return {
      error: `Media size (${bytes.length} bytes) must be between 1 and ${MAX_MEDIA_BYTES} bytes.`,
    };
  }

  const magicValid = matchesMimeMagicBytes(bytes, mimeType);
  if (!magicValid) {
    return {
      error: `Media magic bytes do not match declared MIME type '${mimeType}'.`,
    };
  }

  return { bytes, mimeType, extension };
}

export function matchesMimeMagicBytes(bytes: Uint8Array, mimeType: string): boolean {
  switch (mimeType) {
    case "image/png":
      return bytes.length >= 8 &&
        bytes[0] === 0x89 &&
        bytes[1] === 0x50 &&
        bytes[2] === 0x4e &&
        bytes[3] === 0x47 &&
        bytes[4] === 0x0d &&
        bytes[5] === 0x0a &&
        bytes[6] === 0x1a &&
        bytes[7] === 0x0a;
    case "image/jpeg":
      return bytes.length >= 3 &&
        bytes[0] === 0xff &&
        bytes[1] === 0xd8 &&
        bytes[2] === 0xff;
    case "application/pdf":
      return bytes.length >= 5 &&
        bytes[0] === 0x25 &&
        bytes[1] === 0x50 &&
        bytes[2] === 0x44 &&
        bytes[3] === 0x46 &&
        bytes[4] === 0x2d;
    case "audio/wav":
      return bytes.length >= 12 &&
        String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
        String.fromCharCode(...bytes.slice(8, 12)) === "WAVE";
    case "audio/mpeg":
      return bytes.length >= 3 &&
        (
          (bytes[0] === 0x49 && bytes[1] === 0x44 && bytes[2] === 0x33) ||
          (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0)
        );
    case "video/mp4":
      return bytes.length >= 8 &&
        String.fromCharCode(...bytes.slice(4, 8)) === "ftyp";
    default:
      return false;
  }
}

export function chunkMultimodalContent(args: {
  text: string;
  mimeType: string;
  durationSec: number | null;
  pageCount: number | null;
  maxTextChars?: number;
  textOverlapChars?: number;
}): MultimodalChunkSpec[] {
  const chunks: MultimodalChunkSpec[] = [];
  const maxTextChars = Math.max(120, Math.min(args.maxTextChars ?? 1400, 4000));
  const overlap = Math.max(0, Math.min(args.textOverlapChars ?? 160, Math.floor(maxTextChars / 3)));

  if (args.mimeType.startsWith("video/") || args.mimeType.startsWith("audio/")) {
    const windowSize = args.mimeType.startsWith("video/") ? 120 : 180;
    const totalDuration = Math.max(1, args.durationSec ?? windowSize);
    const modality: ChunkModality = args.mimeType.startsWith("video/") ? "video" : "audio";
    for (
      let start = 0;
      start < totalDuration && chunks.length < MAX_CHUNKS_PER_ITEM;
      start += windowSize
    ) {
      const end = Math.min(totalDuration, start + windowSize);
      const baseNote = args.text.trim();
      chunks.push({
        chunkIndex: chunks.length,
        modality,
        textExcerpt: baseNote
          ? `${baseNote.slice(0, 200)} [${start}s-${end}s]`
          : `${modality} segment [${start}s-${end}s]`,
        startOffsetSec: start,
        endOffsetSec: end,
        pageStart: null,
        pageEnd: null,
      });
    }
    return chunks;
  }

  if (args.mimeType === "application/pdf") {
    const pagesPerWindow = 6;
    const totalPages = Math.max(1, args.pageCount ?? 1);
    for (
      let startPage = 1;
      startPage <= totalPages && chunks.length < MAX_CHUNKS_PER_ITEM;
      startPage += pagesPerWindow
    ) {
      const endPage = Math.min(totalPages, startPage + pagesPerWindow - 1);
      const baseNote = args.text.trim();
      chunks.push({
        chunkIndex: chunks.length,
        modality: "pdf",
        textExcerpt: baseNote
          ? `${baseNote.slice(0, 200)} [p.${startPage}-${endPage}]`
          : `PDF pages ${startPage}-${endPage}`,
        startOffsetSec: null,
        endOffsetSec: null,
        pageStart: startPage,
        pageEnd: endPage,
      });
    }
    return chunks;
  }

  if (args.mimeType.startsWith("image/")) {
    chunks.push({
      chunkIndex: 0,
      modality: "image",
      textExcerpt: args.text.trim().slice(0, 400) || "image embedding unit",
      startOffsetSec: null,
      endOffsetSec: null,
      pageStart: null,
      pageEnd: null,
    });
    return chunks;
  }

  const normalizedText = args.text.replace(/\s+/g, " ").trim();
  if (!normalizedText) {
    return [{
      chunkIndex: 0,
      modality: "text",
      textExcerpt: "",
      startOffsetSec: null,
      endOffsetSec: null,
      pageStart: null,
      pageEnd: null,
    }];
  }

  const step = Math.max(1, maxTextChars - overlap);
  for (
    let pos = 0;
    pos < normalizedText.length && chunks.length < MAX_CHUNKS_PER_ITEM;
    pos += step
  ) {
    const slice = normalizedText.slice(pos, pos + maxTextChars).trim();
    if (!slice) break;
    chunks.push({
      chunkIndex: chunks.length,
      modality: "text",
      textExcerpt: slice,
      startOffsetSec: null,
      endOffsetSec: null,
      pageStart: null,
      pageEnd: null,
    });
    if (pos + maxTextChars >= normalizedText.length) break;
  }
  return chunks;
}

export function normalizeVector(values: number[]): number[] {
  const norm = Math.sqrt(values.reduce((acc, v) => acc + v * v, 0));
  if (norm <= 0) return values.slice();
  return values.map((v) => v / norm);
}

export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length === 0 || b.length === 0 || a.length !== b.length) return 0;
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom <= 0 ? 0 : Math.max(0, dot / denom);
}

export function parsePgVector(raw: number[] | string | null | undefined): number[] {
  if (Array.isArray(raw)) {
    return raw.map((v) => Number(v)).filter((v) => Number.isFinite(v));
  }
  if (typeof raw !== "string") return [];
  const trimmed = raw.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) return [];
  return trimmed
    .slice(1, -1)
    .split(",")
    .map((part) => Number(part.trim()))
    .filter((v) => Number.isFinite(v));
}

export function computeDeterministicFallbackEmbedding(
  parts: EmbeddingPartInput[],
  dimensions = EMBEDDING_DIMENSION,
): number[] {
  const vec = new Array<number>(dimensions).fill(0);
  const featureTerms: string[] = [];

  for (const part of parts) {
    if (part.text) {
      const normalized = part.text.trim().toLowerCase();
      if (normalized) {
        const words = normalized.split(/[\s,.;:!?/\\()[\]{}"'`]+/).filter(Boolean);
        for (const word of words) {
          featureTerms.push(`w:${word}`);
        }
        for (let i = 0; i < normalized.length; i++) {
          const code = normalized.charCodeAt(i);
          if (code > 32) {
            featureTerms.push(`c:${code}`);
          }
          if (i + 1 < normalized.length) {
            featureTerms.push(`bg:${normalized.slice(i, i + 2)}`);
          }
        }
      }
    }
    if (part.inlineData) {
      const mime = part.inlineData.mimeType.toLowerCase();
      featureTerms.push(`mime:${mime}`);
      featureTerms.push(`modality:${mime.split("/")[0] ?? "binary"}`);
      const sample = part.inlineData.dataBase64.slice(0, 128);
      for (let i = 0; i + 4 <= sample.length; i += 4) {
        featureTerms.push(`img4:${sample.slice(i, i + 4)}`);
      }
    }
  }

  if (featureTerms.length === 0) {
    vec[0] = 1;
    return vec;
  }

  for (const term of featureTerms) {
    let h1 = 2166136261;
    let h2 = 0x811c9dc5;
    for (let i = 0; i < term.length; i++) {
      const ch = term.charCodeAt(i);
      h1 = Math.imul(h1 ^ ch, 16777619) >>> 0;
      h2 = Math.imul(h2 + ch + i, 2654435761) >>> 0;
    }
    const idx1 = h1 % dimensions;
    const idx2 = (h2 >>> 1) % dimensions;
    const sign = (h2 & 1) === 0 ? 1 : -1;
    vec[idx1] += 1;
    vec[idx2] += 0.5 * sign;
  }

  return normalizeVector(vec);
}

export function buildGeminiEmbedding2RequestBody(
  parts: EmbeddingPartInput[],
  dimensions = EMBEDDING_DIMENSION,
): Record<string, unknown> {
  const apiParts: Array<Record<string, unknown>> = [];
  for (const part of parts) {
    const text = asTrimmedString(part.text);
    if (text) {
      apiParts.push({ text: text.slice(0, 16000) });
    }
    if (part.inlineData) {
      apiParts.push({
        inline_data: {
          mime_type: part.inlineData.mimeType,
          data: part.inlineData.dataBase64,
        },
      });
    }
  }

  // Primary docs note: gemini-embedding-2 forbids task_type and supports output_dimensionality (768/1536/3072).
  return {
    model: `models/${GEMINI_EMBEDDING_2_MODEL}`,
    content: { parts: apiParts },
    output_dimensionality: dimensions,
  };
}

export async function generateMultimodalEmbedding(args: {
  parts: EmbeddingPartInput[];
  authCredential?: string;
  fetchImpl?: FetchLike;
  dimensions?: number;
}): Promise<EmbeddingResult> {
  const dimensions = args.dimensions ?? EMBEDDING_DIMENSION;
  const authCredential = (args.authCredential ?? Deno.env.get("GEMINI_API_KEY") ?? "").trim();

  if (!authCredential) {
    return {
      vector: computeDeterministicFallbackEmbedding(args.parts, dimensions),
      model: "deterministic-fallback",
      mode: "offline_fallback",
    };
  }

  const fetchImpl = args.fetchImpl ?? fetch;
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_EMBEDDING_2_MODEL}:embedContent`;
  const reqHeaders = new Headers({ "Content-Type": "application/json" });
  reqHeaders.set("x-goog-api-key", authCredential);
  const response = await fetchImpl(endpoint, {
    method: "POST",
    headers: reqHeaders,
    body: JSON.stringify(buildGeminiEmbedding2RequestBody(args.parts, dimensions)),
  });

  if (!response.ok) {
    const raw = await response.text();
    throw new Error(`Gemini Embedding 2 error ${response.status}: ${raw.slice(0, 300)}`);
  }

  const payload = await response.json() as {
    embedding?: { values?: number[] };
  };
  const values = payload.embedding?.values ?? [];
  if (values.length !== dimensions) {
    throw new Error(
      `Gemini Embedding 2 dimension mismatch: got ${values.length}, expected ${dimensions}`,
    );
  }

  return {
    vector: normalizeVector(values),
    model: "gemini-embedding-2",
    mode: "live",
  };
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  const digest = await crypto.subtle.digest("SHA-256", copy);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function handleMultimodalRagAction(args: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  admin: SupabaseClient;
  authCredential?: string;
  fetchImpl?: FetchLike;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { action, body, userId, admin, json } = args;
  const ownerUserId = userId === "service_role"
    ? asTrimmedString(body.user_id)
    : userId;
  if (!ownerUserId || ownerUserId === "service_role") {
    return json({ error: "Authenticated owner user_id is required" }, 401);
  }

  switch (action) {
    case "multimodal_rag.ingest":
      return await handleIngest({ ...args, ownerUserId });
    case "multimodal_rag.search":
      return await handleSearch({ ...args, ownerUserId });
    case "multimodal_rag.list":
      return await handleList({ ...args, ownerUserId });
    case "multimodal_rag.signed_url":
      return await handleSignedUrl({ ...args, ownerUserId });
    case "multimodal_rag.delete":
      return await handleDelete({ ...args, ownerUserId });
    default:
      return json({ error: `Unknown multimodal_rag action: ${action}` }, 400);
  }
}

async function handleIngest(args: {
  body: Record<string, unknown>;
  ownerUserId: string;
  admin: SupabaseClient;
  authCredential?: string;
  fetchImpl?: FetchLike;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { body, ownerUserId, admin, json } = args;
  const title = asTrimmedString(body.title);
  if (!title) {
    return json({ error: "title is required" }, 400);
  }
  const sourceKey = normalizeSourceKey(asTrimmedString(body.source_key), title);
  const contentText = asTrimmedString(body.content_text ?? body.text);
  const mediaBase64 = asTrimmedString(body.media_base64 ?? body.image_base64);
  const rawMime = asTrimmedString(body.mime_type) ||
    (mediaBase64 ? "image/png" : "text/plain");
  const durationSec = asOptionalInt(body.duration_sec);
  const pageCount = asOptionalInt(body.page_count);

  if (!contentText && !mediaBase64) {
    return json({ error: "content_text or media_base64 is required" }, 400);
  }

  let decodedMedia: { bytes: Uint8Array; mimeType: string; extension: string } | null = null;
  let storagePath: string | null = null;
  let mediaSha = "";
  let byteSize = new TextEncoder().encode(contentText).length;

  if (mediaBase64) {
    const verified = decodeAndVerifyMediaBase64(mediaBase64, rawMime);
    if ("error" in verified) {
      return json({ error: verified.error }, 400);
    }
    decodedMedia = verified;
    byteSize = verified.bytes.length;
    mediaSha = await sha256Hex(verified.bytes);
    const datePrefix = new Date().toISOString().slice(0, 10);
    storagePath =
      `${ownerUserId}/${datePrefix}/${sourceKey}-${mediaSha.slice(0, 12)}.${verified.extension}`;
  } else {
    if (!TEXT_MIME_TYPES.has(rawMime.toLowerCase())) {
      return json({ error: `Unsupported text mime_type '${rawMime}'` }, 400);
    }
    mediaSha = await sha256Hex(new TextEncoder().encode(contentText));
  }

  const effectiveMime = decodedMedia ? decodedMedia.mimeType : rawMime.toLowerCase();
  const modality = normalizeModality(
    body.modality,
    effectiveMime,
    Boolean(contentText),
    Boolean(decodedMedia),
  );

  const chunks = chunkMultimodalContent({
    text: contentText || title,
    mimeType: effectiveMime,
    durationSec,
    pageCount,
  });

  const itemParts: EmbeddingPartInput[] = [];
  if (title || contentText) {
    itemParts.push({ text: `${title}\n${contentText}`.trim() });
  }
  if (decodedMedia && mediaBase64) {
    itemParts.push({
      inlineData: {
        mimeType: decodedMedia.mimeType,
        dataBase64: mediaBase64.replace(/^data:[^;]+;base64,/i, "").replace(/\s+/g, ""),
      },
    });
  }

  const itemEmbedding = await generateMultimodalEmbedding({
    parts: itemParts,
    authCredential: args.authCredential,
    fetchImpl: args.fetchImpl,
  });

  if (decodedMedia && storagePath) {
    const { error: uploadError } = await admin.storage
      .from(MULTIMODAL_RAG_BUCKET)
      .upload(storagePath, decodedMedia.bytes, {
        contentType: decodedMedia.mimeType,
        upsert: true,
      });
    if (uploadError) {
      return json({ error: `Storage upload failed: ${uploadError.message}` }, 500);
    }
  }

  const extraMeta = body.metadata && typeof body.metadata === "object" && !Array.isArray(body.metadata)
    ? body.metadata as Record<string, unknown>
    : {};

  const { data: itemRow, error: itemError } = await admin
    .from("multimodal_rag_items")
    .upsert(
      {
        owner_user_id: ownerUserId,
        source_key: sourceKey,
        title,
        modality,
        mime_type: effectiveMime,
        storage_object_path: storagePath,
        content_text: contentText,
        media_sha256: mediaSha,
        byte_size: byteSize,
        duration_sec: durationSec,
        page_count: pageCount,
        chunk_count: chunks.length,
        embedding_model: itemEmbedding.model,
        embedding_mode: itemEmbedding.mode,
        embedding: itemEmbedding.vector,
        metadata: extraMeta,
      },
      { onConflict: "owner_user_id,source_key" },
    )
    .select("id,source_key,title,modality,mime_type,storage_object_path,chunk_count,embedding_model,embedding_mode,updated_at")
    .single();

  if (itemError || !itemRow) {
    if (storagePath) {
      await admin.storage.from(MULTIMODAL_RAG_BUCKET).remove([storagePath]).catch(() => undefined);
    }
    return json({ error: `Failed to save multimodal vector item: ${itemError?.message ?? "unknown"}` }, 500);
  }

  const itemId = String((itemRow as Record<string, unknown>).id);
  await admin.from("multimodal_rag_chunks").delete().eq("item_id", itemId);

  const chunkRecords = [];
  for (const chunk of chunks) {
    const chunkParts: EmbeddingPartInput[] = [];
    if (chunk.textExcerpt) {
      chunkParts.push({ text: chunk.textExcerpt });
    }
    if (decodedMedia && mediaBase64 && chunk.chunkIndex === 0) {
      chunkParts.push({
        inlineData: {
          mimeType: decodedMedia.mimeType,
          dataBase64: mediaBase64.replace(/^data:[^;]+;base64,/i, "").replace(/\s+/g, ""),
        },
      });
    }
    const chunkEmb = chunk.chunkIndex === 0 && chunks.length === 1
      ? itemEmbedding
      : await generateMultimodalEmbedding({
        parts: chunkParts,
        authCredential: args.authCredential,
        fetchImpl: args.fetchImpl,
      });

    chunkRecords.push({
      item_id: itemId,
      owner_user_id: ownerUserId,
      chunk_index: chunk.chunkIndex,
      modality: chunk.modality,
      text_excerpt: chunk.textExcerpt,
      start_offset_sec: chunk.startOffsetSec,
      end_offset_sec: chunk.endOffsetSec,
      page_start: chunk.pageStart,
      page_end: chunk.pageEnd,
      embedding: chunkEmb.vector,
      metadata: {
        embedding_model: chunkEmb.model,
        embedding_mode: chunkEmb.mode,
      },
    });
  }

  const { error: chunkError } = await admin
    .from("multimodal_rag_chunks")
    .insert(chunkRecords);

  if (chunkError) {
    return json({ error: `Failed to save multimodal chunks: ${chunkError.message}` }, 500);
  }

  return json({
    success: true,
    item: itemRow,
    chunks_indexed: chunkRecords.length,
    embedding_model: itemEmbedding.model,
    embedding_mode: itemEmbedding.mode,
    storage_bucket: storagePath ? MULTIMODAL_RAG_BUCKET : null,
  });
}

async function handleSearch(args: {
  body: Record<string, unknown>;
  ownerUserId: string;
  admin: SupabaseClient;
  authCredential?: string;
  fetchImpl?: FetchLike;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { body, ownerUserId, admin, json } = args;
  const queryText = asTrimmedString(body.query_text ?? body.query);
  const queryImageBase64 = asTrimmedString(body.query_image_base64 ?? body.image_base64);
  const queryImageMime = asTrimmedString(body.query_image_mime_type ?? body.mime_type) || "image/png";
  const limitRaw = asOptionalInt(body.limit) ?? 10;
  const limit = Math.max(1, Math.min(limitRaw, 50));
  const modalitiesFilter = Array.isArray(body.modalities)
    ? body.modalities
      .map((m) => asTrimmedString(m).toLowerCase())
      .filter((m): m is MultimodalModality => VALID_MODALITIES.has(m as MultimodalModality))
    : [];

  if (!queryText && !queryImageBase64) {
    return json({ error: "query_text or query_image_base64 is required" }, 400);
  }

  const parts: EmbeddingPartInput[] = [];
  if (queryText) {
    parts.push({ text: queryText });
  }
  if (queryImageBase64) {
    const verified = decodeAndVerifyMediaBase64(queryImageBase64, queryImageMime);
    if ("error" in verified) {
      return json({ error: verified.error }, 400);
    }
    if (!verified.mimeType.startsWith("image/")) {
      return json({ error: "Visual search query must use image/png or image/jpeg" }, 400);
    }
    parts.push({
      inlineData: {
        mimeType: verified.mimeType,
        dataBase64: queryImageBase64.replace(/^data:[^;]+;base64,/i, "").replace(/\s+/g, ""),
      },
    });
  }

  const queryEmbedding = await generateMultimodalEmbedding({
    parts,
    authCredential: args.authCredential,
    fetchImpl: args.fetchImpl,
  });

  let dbQuery = admin
    .from("multimodal_rag_items")
    .select("id,source_key,title,modality,mime_type,storage_object_path,content_text,chunk_count,embedding_model,embedding_mode,embedding,updated_at")
    .eq("owner_user_id", ownerUserId)
    .order("updated_at", { ascending: false })
    .limit(200);

  if (modalitiesFilter.length > 0) {
    dbQuery = dbQuery.in("modality", modalitiesFilter);
  }

  const { data: rows, error } = await dbQuery;
  if (error) {
    return json({ error: `Search failed: ${error.message}` }, 500);
  }

  const lowerQuery = queryText.toLowerCase();
  const candidates = ((rows ?? []) as MultimodalSearchHitRow[]).map((row) => {
    const vec = parsePgVector(row.embedding);
    const vecScore = vec.length === EMBEDDING_DIMENSION
      ? cosineSimilarity(queryEmbedding.vector, vec)
      : 0;
    const hay = `${row.title} ${row.content_text} ${row.source_key}`.toLowerCase();
    const lexicalBoost = lowerQuery && hay.includes(lowerQuery) ? 0.25 : 0;
    const score = Math.min(1, Number((vecScore + lexicalBoost).toFixed(4)));
    return {
      item_id: row.id,
      source_key: row.source_key,
      title: row.title,
      modality: row.modality,
      mime_type: row.mime_type,
      storage_object_path: row.storage_object_path,
      matched_excerpt: row.content_text.slice(0, 220),
      chunk_count: row.chunk_count,
      embedding_model: row.embedding_model,
      embedding_mode: row.embedding_mode,
      similarity_score: score,
      updated_at: row.updated_at,
    };
  })
    .sort((a, b) => b.similarity_score - a.similarity_score)
    .slice(0, limit);

  const hits = await Promise.all(
    candidates.map(async (hit) => {
      let signedUrl: string | null = null;
      if (hit.storage_object_path) {
        const { data: signed } = await admin.storage
          .from(MULTIMODAL_RAG_BUCKET)
          .createSignedUrl(hit.storage_object_path, SIGNED_URL_TTL_SECONDS);
        signedUrl = signed?.signedUrl ?? null;
      }
      return { ...hit, signed_url: signedUrl };
    }),
  );

  return json({
    success: true,
    query_modality: queryText && queryImageBase64
      ? "mixed"
      : (queryImageBase64 ? "image" : "text"),
    embedding_model: queryEmbedding.model,
    embedding_mode: queryEmbedding.mode,
    hits,
  });
}

async function handleList(args: {
  body: Record<string, unknown>;
  ownerUserId: string;
  admin: SupabaseClient;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { body, ownerUserId, admin, json } = args;
  const limit = Math.max(1, Math.min(asOptionalInt(body.limit) ?? 30, 100));
  const { data, error } = await admin
    .from("multimodal_rag_items")
    .select("id,source_key,title,modality,mime_type,storage_object_path,content_text,byte_size,duration_sec,page_count,chunk_count,embedding_model,embedding_mode,updated_at")
    .eq("owner_user_id", ownerUserId)
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) {
    return json({ error: `Failed to list items: ${error.message}` }, 500);
  }
  return json({ success: true, items: data ?? [] });
}

async function handleSignedUrl(args: {
  body: Record<string, unknown>;
  ownerUserId: string;
  admin: SupabaseClient;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { body, ownerUserId, admin, json } = args;
  const itemId = asTrimmedString(body.item_id ?? body.id);
  if (!itemId) {
    return json({ error: "item_id is required" }, 400);
  }
  const { data, error } = await admin
    .from("multimodal_rag_items")
    .select("id,owner_user_id,storage_object_path")
    .eq("id", itemId)
    .eq("owner_user_id", ownerUserId)
    .maybeSingle();

  if (error) {
    return json({ error: error.message }, 500);
  }
  if (!data || !data.storage_object_path) {
    return json({ error: "Storage object not found for owned item" }, 404);
  }
  const objectPath = String(data.storage_object_path);
  if (!objectPath.startsWith(`${ownerUserId}/`)) {
    return json({ error: "Forbidden storage prefix mismatch" }, 403);
  }

  const { data: signed, error: signError } = await admin.storage
    .from(MULTIMODAL_RAG_BUCKET)
    .createSignedUrl(objectPath, SIGNED_URL_TTL_SECONDS);
  if (signError || !signed?.signedUrl) {
    return json({ error: `Signed URL failed: ${signError?.message ?? "unknown"}` }, 500);
  }
  return json({
    success: true,
    item_id: itemId,
    storage_object_path: objectPath,
    signed_url: signed.signedUrl,
    expires_in_seconds: SIGNED_URL_TTL_SECONDS,
  });
}

async function handleDelete(args: {
  body: Record<string, unknown>;
  ownerUserId: string;
  admin: SupabaseClient;
  json: (data: unknown, status?: number) => Response;
}): Promise<Response> {
  const { body, ownerUserId, admin, json } = args;
  const itemId = asTrimmedString(body.item_id ?? body.id);
  if (!itemId) {
    return json({ error: "item_id is required" }, 400);
  }

  const { data: existing, error: fetchError } = await admin
    .from("multimodal_rag_items")
    .select("id,storage_object_path")
    .eq("id", itemId)
    .eq("owner_user_id", ownerUserId)
    .maybeSingle();

  if (fetchError) {
    return json({ error: fetchError.message }, 500);
  }
  if (!existing) {
    return json({ error: "Item not found" }, 404);
  }

  const { error: deleteError } = await admin
    .from("multimodal_rag_items")
    .delete()
    .eq("id", itemId)
    .eq("owner_user_id", ownerUserId);

  if (deleteError) {
    return json({ error: deleteError.message }, 500);
  }

  if (existing.storage_object_path) {
    await admin.storage
      .from(MULTIMODAL_RAG_BUCKET)
      .remove([String(existing.storage_object_path)])
      .catch(() => undefined);
  }

  return json({ success: true, deleted_item_id: itemId });
}
