import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildContentAddressablePath,
  computeBytesSha256Hex,
  handleMediaLibraryAction,
  UNIFIED_MEDIA_BUCKET,
} from "./media_library.ts";

class MockMediaLibraryClient {
  readonly assets: Record<string, unknown>[] = [];
  readonly usages: Record<string, unknown>[] = [];
  readonly uploadedPaths: string[] = [];
  private seq = 1;

  get storage() {
    const uploadedPaths = this.uploadedPaths;
    return {
      from(bucket: string) {
        assertEquals(bucket, UNIFIED_MEDIA_BUCKET);
        return {
          upload: (path: string, _bytes: Uint8Array) => {
            uploadedPaths.push(path);
            return Promise.resolve({ data: { path }, error: null });
          },
          createSignedUrl: (path: string, ttl: number) =>
            Promise.resolve({
              data: { signedUrl: `https://storage.local/${path}?ttl=${ttl}` },
              error: null,
            }),
          remove: (_paths: string[]) => Promise.resolve({ data: [], error: null }),
        };
      },
    };
  }

  from(table: string) {
    const source = table === "media_library_project_usages"
      ? this.usages
      : this.assets;
    const filters: Array<{ col: string; val: unknown }> = [];
    let isDelete = false;
    let updatePayload: Record<string, unknown> | null = null;

    const applyFilters = () =>
      source.filter((row) => filters.every((f) => row[f.col] === f.val));

    const query: Record<string, unknown> = {
      select(_cols?: string) {
        return query;
      },
      eq(col: string, val: unknown) {
        filters.push({ col, val });
        if (isDelete) {
          const remaining = source.filter((r) =>
            !filters.every((f) => r[f.col] === f.val)
          );
          source.splice(0, source.length, ...remaining);
          return Promise.resolve({ data: null, error: null });
        }
        return query;
      },
      order(_col: string, _opts?: { ascending?: boolean }) {
        return query;
      },
      limit(count: number) {
        return Promise.resolve({
          data: applyFilters().slice(0, count),
          error: null,
        });
      },
      maybeSingle() {
        return Promise.resolve({ data: applyFilters()[0] ?? null, error: null });
      },
      insert: (payload: Record<string, unknown>) => {
        const row: Record<string, unknown> = {
          id: `${table}-${this.seq++}`,
          reuse_count: 0,
          tags: [],
          auto_tags: [],
          created_at: "2026-11-25T10:00:00Z",
          updated_at: "2026-11-25T10:00:00Z",
          ...payload,
        };
        source.push(row);
        return {
          select: () => ({
            single: () => Promise.resolve({ data: { ...row }, error: null }),
          }),
        };
      },
      update: (payload: Record<string, unknown>) => {
        updatePayload = payload;
        return query;
      },
      delete: () => {
        isDelete = true;
        return query;
      },
      single: () => {
        const matched = applyFilters();
        if (!matched[0]) {
          return Promise.resolve({ data: null, error: { message: "Not found" } });
        }
        if (updatePayload) {
          Object.assign(matched[0], updatePayload, {
            updated_at: "2026-11-25T10:05:00Z",
          });
        }
        return Promise.resolve({ data: { ...matched[0] }, error: null });
      },
    };
    return query;
  }
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status });
}

Deno.test("deduplicates identical media uploads by SHA-256 and skips duplicate storage write", async () => {
  const mockDb = new MockMediaLibraryClient();
  const sampleB64 = btoa("fake-mp4-video-binary-bytes-12345");
  const expectedSha = await computeBytesSha256Hex(
    new TextEncoder().encode("fake-mp4-video-binary-bytes-12345"),
  );

  const firstRes = await handleMediaLibraryAction({
    action: "media_library.upload_or_deduplicate",
    userId: "user-1",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      title: "Product Demo Intro",
      description: "Opening shot for product showcase video",
      mime_type: "video/mp4",
      content_base64: sampleB64,
      tags: ["intro", "showcase"],
      duration_sec: 12,
      ai_model: "claude-sonnet-4-6",
      project_key: "proj-alpha",
    },
    autoTagger: () =>
      Promise.resolve({
        autoTags: ["intro", "product-demo", "short-clip"],
        taggingModel: "claude-sonnet-4-6",
      }),
  });
  assertEquals(firstRes.status, 200);
  const firstBody = await firstRes.json();
  assertEquals(firstBody.deduplicated, false);
  assertEquals(firstBody.storage_upload_skipped, false);
  assertEquals(mockDb.uploadedPaths.length, 1);
  assertEquals(
    firstBody.asset.storage_object_path,
    buildContentAddressablePath("user-1", expectedSha, "video/mp4"),
  );
  assertEquals(firstBody.asset.reuse_count, 1);

  // Second upload of identical bytes MUST reuse the existing object and skip Storage upload
  const secondRes = await handleMediaLibraryAction({
    action: "media_library.upload_or_deduplicate",
    userId: "user-1",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      title: "Duplicate Intro Reupload",
      mime_type: "video/mp4",
      content_base64: sampleB64,
      tags: ["reused"],
      project_key: "proj-beta",
      pipeline_stage: "b_roll",
    },
  });
  assertEquals(secondRes.status, 200);
  const secondBody = await secondRes.json();
  assertEquals(secondBody.deduplicated, true);
  assertEquals(secondBody.storage_upload_skipped, true);
  assertEquals(mockDb.uploadedPaths.length, 1);
  assertEquals(mockDb.assets.length, 1);
  assertEquals(secondBody.asset.reuse_count, 2);
});

Deno.test("reuses asset across projects, updates tags, filters search, and isolates owners", async () => {
  const mockDb = new MockMediaLibraryClient();
  const sampleB64 = btoa("shared-audio-track-999");

  const uploadRes = await handleMediaLibraryAction({
    action: "media_library.upload_or_deduplicate",
    userId: "user-owner",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      title: "Ambient Synth BGM",
      mime_type: "audio/mpeg",
      content_base64: sampleB64,
      tags: ["bgm", "ambient"],
      duration_sec: 45,
    },
  });
  const uploadBody = await uploadRes.json();
  const assetId = String(uploadBody.asset.id);
  assertExists(assetId);

  const reuseRes = await handleMediaLibraryAction({
    action: "media_library.reuse_in_project",
    userId: "user-owner",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      asset_id: assetId,
      project_key: "youtube-launch",
      project_title: "Launch Trailer",
      pipeline_stage: "audio_track",
    },
  });
  assertEquals(reuseRes.status, 200);
  const reuseBody = await reuseRes.json();
  assertEquals(reuseBody.asset.reuse_count, 1);

  // Other user cannot reuse or access owner's asset
  const idorRes = await handleMediaLibraryAction({
    action: "media_library.reuse_in_project",
    userId: "other-user",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      asset_id: assetId,
      project_key: "evil-proj",
    },
  });
  assertEquals(idorRes.status, 404);

  const searchRes = await handleMediaLibraryAction({
    action: "media_library.search",
    userId: "user-owner",
    admin: mockDb as unknown as SupabaseClient,
    json: jsonResponse,
    body: {
      asset_kind: "audio",
      tag: "bgm",
      project_key: "youtube-launch",
    },
  });
  assertEquals(searchRes.status, 200);
  const searchBody = await searchRes.json();
  assertEquals(searchBody.assets.length, 1);
  assertEquals(searchBody.assets[0].usages.length, 1);
});
