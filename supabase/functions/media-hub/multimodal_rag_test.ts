import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildGeminiEmbedding2RequestBody,
  chunkMultimodalContent,
  cosineSimilarity,
  decodeAndVerifyMediaBase64,
  EMBEDDING_DIMENSION,
  generateMultimodalEmbedding,
  handleMultimodalRagAction,
} from "./multimodal_rag.ts";

const VALID_PNG_BYTES = new Uint8Array([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
]);

function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) {
    bin += String.fromCharCode(b);
  }
  return btoa(bin);
}

function buildJsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("decodeAndVerifyMediaBase64 validates magic bytes and rejects spoofing", () => {
  const pngB64 = bytesToBase64(VALID_PNG_BYTES);
  const ok = decodeAndVerifyMediaBase64(pngB64, "image/png");
  assert(!("error" in ok));
  assertEquals(ok.extension, "png");
  assertEquals(ok.bytes.length, VALID_PNG_BYTES.length);

  const spoofed = decodeAndVerifyMediaBase64(pngB64, "image/jpeg");
  assert("error" in spoofed);

  const unsupported = decodeAndVerifyMediaBase64(pngB64, "image/svg+xml");
  assert("error" in unsupported);
});

Deno.test("chunkMultimodalContent splits video, audio, pdf, and overlapping text within Gemini Embedding 2 limits", () => {
  const videoChunks = chunkMultimodalContent({
    text: "product walkthrough",
    mimeType: "video/mp4",
    durationSec: 250,
    pageCount: null,
  });
  assertEquals(videoChunks.length, 3);
  assertEquals(videoChunks[0].startOffsetSec, 0);
  assertEquals(videoChunks[0].endOffsetSec, 120);
  assertEquals(videoChunks[2].startOffsetSec, 240);
  assertEquals(videoChunks[2].endOffsetSec, 250);

  const pdfChunks = chunkMultimodalContent({
    text: "architecture manual",
    mimeType: "application/pdf",
    durationSec: null,
    pageCount: 13,
  });
  assertEquals(pdfChunks.length, 3);
  assertEquals(pdfChunks[0].pageStart, 1);
  assertEquals(pdfChunks[0].pageEnd, 6);
  assertEquals(pdfChunks[2].pageStart, 13);
  assertEquals(pdfChunks[2].pageEnd, 13);

  const textChunks = chunkMultimodalContent({
    text: "a".repeat(260),
    mimeType: "text/plain",
    durationSec: null,
    pageCount: null,
    maxTextChars: 140,
    textOverlapChars: 20,
  });
  assertEquals(textChunks.length, 3);
  assertEquals(textChunks[0].modality, "text");
});

Deno.test("buildGeminiEmbedding2RequestBody emits primary REST contract without task_type", () => {
  const pngB64 = bytesToBase64(VALID_PNG_BYTES);
  const payload = buildGeminiEmbedding2RequestBody([
    { text: "manual diagram search" },
    { inlineData: { mimeType: "image/png", dataBase64: pngB64 } },
  ]);

  assertEquals(payload.model, "models/gemini-embedding-2");
  assertEquals(payload.output_dimensionality, EMBEDDING_DIMENSION);
  assertEquals("task_type" in payload, false);
  const content = payload.content as { parts: Array<Record<string, unknown>> };
  assertEquals(content.parts.length, 2);
  assertEquals(content.parts[0].text, "manual diagram search");
  assert("inline_data" in content.parts[1]);
});

Deno.test("generateMultimodalEmbedding uses live API when key present and offline fallback otherwise", async () => {
  const pngB64 = bytesToBase64(VALID_PNG_BYTES);
  let capturedUrl = "";
  const mockVec = new Array<number>(EMBEDDING_DIMENSION).fill(0);
  mockVec[0] = 3;
  mockVec[1] = 4;

  const live = await generateMultimodalEmbedding({
    parts: [
      { text: "flutter architecture diagram" },
      { inlineData: { mimeType: "image/png", dataBase64: pngB64 } },
    ],
    authCredential: "fake-unit-test-credential-value",
    fetchImpl: (input) => {
      capturedUrl = String(input);
      return Promise.resolve(
        buildJsonResponse({ embedding: { values: mockVec } }, 200),
      );
    },
  });

  assert(capturedUrl.includes("models/gemini-embedding-2:embedContent"));
  assertEquals(live.model, "gemini-embedding-2");
  assertEquals(live.mode, "live");
  assertEquals(live.vector.length, EMBEDDING_DIMENSION);
  assert(Math.abs(live.vector[0] - 0.6) < 1e-6);

  const offlineA = await generateMultimodalEmbedding({
    parts: [{ text: "supabase pgvector receipt scan" }],
    authCredential: "",
  });
  const offlineB = await generateMultimodalEmbedding({
    parts: [{ text: "supabase pgvector receipt" }],
    authCredential: "",
  });
  const offlineOther = await generateMultimodalEmbedding({
    parts: [{ text: "guitar tuner chord progression" }],
    authCredential: "",
  });

  assertEquals(offlineA.model, "deterministic-fallback");
  assertEquals(offlineA.mode, "offline_fallback");
  assert(
    cosineSimilarity(offlineA.vector, offlineB.vector) >
      cosineSimilarity(offlineA.vector, offlineOther.vector),
  );
});

Deno.test("handleMultimodalRagAction enforces owner scoping and storage linkage", async () => {
  const uploadedPaths: string[] = [];
  const removedPaths: string[] = [];

  const mockAdmin = {
    storage: {
      from: (_bucket: string) => ({
        upload: (path: string) => {
          uploadedPaths.push(path);
          return Promise.resolve({ error: null });
        },
        remove: (paths: string[]) => {
          removedPaths.push(...paths);
          return Promise.resolve({ error: null });
        },
        createSignedUrl: (path: string) =>
          Promise.resolve({
            data: { signedUrl: `https://storage.local/signed/${path}` },
            error: null,
          }),
      }),
    },
    from: (table: string) => {
      if (table === "multimodal_rag_items") {
        return {
          upsert: (row: Record<string, unknown>) => ({
            select: () => ({
              single: () =>
                Promise.resolve({
                  data: {
                    id: "item-1",
                    source_key: row.source_key,
                    title: row.title,
                    modality: row.modality,
                    mime_type: row.mime_type,
                    storage_object_path: row.storage_object_path,
                    chunk_count: row.chunk_count,
                    embedding_model: row.embedding_model,
                    embedding_mode: row.embedding_mode,
                    updated_at: "2026-11-25T04:50:00Z",
                  },
                  error: null,
                }),
            }),
          }),
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: () =>
                  Promise.resolve({
                    data: {
                      id: "item-1",
                      owner_user_id: "user-abc",
                      storage_object_path: "other-user/2026-11-25/bad.png",
                    },
                    error: null,
                  }),
              }),
            }),
          }),
        };
      }
      return {
        delete: () => ({
          eq: () => Promise.resolve({ error: null }),
        }),
        insert: () => Promise.resolve({ error: null }),
      };
    },
  } as unknown as SupabaseClient;

  const unauthResp = await handleMultimodalRagAction({
    action: "multimodal_rag.list",
    body: {},
    userId: "service_role",
    admin: mockAdmin,
    json: buildJsonResponse,
  });
  assertEquals(unauthResp.status, 401);

  const ingestResp = await handleMultimodalRagAction({
    action: "multimodal_rag.ingest",
    body: {
      title: "Circuit Manual Screenshot",
      source_key: "circuit-doc-1",
      content_text: "Diagram showing multimodal rag wiring",
      media_base64: bytesToBase64(VALID_PNG_BYTES),
      mime_type: "image/png",
    },
    userId: "user-abc",
    admin: mockAdmin,
    authCredential: "",
    json: buildJsonResponse,
  });
  assertEquals(ingestResp.status, 200);
  const ingestJson = await ingestResp.json() as Record<string, unknown>;
  assertEquals(ingestJson.success, true);
  assertEquals(ingestJson.embedding_mode, "offline_fallback");
  assert(uploadedPaths.length === 1);
  assert(uploadedPaths[0].startsWith("user-abc/"));

  const mismatchResp = await handleMultimodalRagAction({
    action: "multimodal_rag.signed_url",
    body: { item_id: "item-1" },
    userId: "user-abc",
    admin: mockAdmin,
    json: buildJsonResponse,
  });
  assertEquals(mismatchResp.status, 403);
  assertEquals(removedPaths.length, 0);
});
