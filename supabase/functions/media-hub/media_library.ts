import { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const UNIFIED_MEDIA_BUCKET = "unified-media-library";
export const MAX_MEDIA_LIBRARY_BYTES = 50 * 1024 * 1024;
export const SIGNED_MEDIA_URL_TTL_SECONDS = 300;

export type MediaAssetKind = "video" | "audio" | "image";

export type TaggingModelId =
  | "claude-sonnet-4-6"
  | "gemini-3.1-pro"
  | "deterministic-fallback";

export type PipelineReuseStage =
  | "video_timeline"
  | "audio_track"
  | "b_roll"
  | "thumbnail"
  | "voiceover"
  | "ad_creative";

const VALID_ASSET_KINDS = new Set<MediaAssetKind>(["video", "audio", "image"]);
const VALID_STAGES = new Set<PipelineReuseStage>([
  "video_timeline",
  "audio_track",
  "b_roll",
  "thumbnail",
  "voiceover",
  "ad_creative",
]);

const MIME_MAP: Record<
  string,
  { kind: MediaAssetKind; ext: string }
> = {
  "video/mp4": { kind: "video", ext: "mp4" },
  "video/webm": { kind: "video", ext: "webm" },
  "audio/mpeg": { kind: "audio", ext: "mp3" },
  "audio/wav": { kind: "audio", ext: "wav" },
  "audio/aac": { kind: "audio", ext: "aac" },
  "image/png": { kind: "image", ext: "png" },
  "image/jpeg": { kind: "image", ext: "jpg" },
  "image/webp": { kind: "image", ext: "webp" },
};

export interface MediaAssetTagResult {
  autoTags: string[];
  taggingModel: TaggingModelId;
}

export type MediaAutoTagger = (input: {
  title: string;
  description: string;
  assetKind: MediaAssetKind;
  mimeType: string;
  durationSec: number | null;
  preferredModel: TaggingModelId;
}) => Promise<MediaAssetTagResult>;

function asTrimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNonNegativeInt(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Math.floor(parsed);
}

export function normalizeTagList(raw: unknown): string[] {
  const source = Array.isArray(raw)
    ? raw
    : typeof raw === "string"
    ? raw.split(/[,\n]+/)
    : [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of source) {
    const clean = String(item ?? "")
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "-")
      .slice(0, 48);
    if (clean.length > 0 && !seen.has(clean)) {
      seen.add(clean);
      out.push(clean);
      if (out.length >= 20) break;
    }
  }
  return out;
}

export function normalizeTaggingModel(raw: unknown): TaggingModelId {
  const val = asTrimmed(raw).toLowerCase();
  if (val === "claude-sonnet-4-6") return "claude-sonnet-4-6";
  if (val === "gemini-3.1-pro") return "gemini-3.1-pro";
  return "deterministic-fallback";
}

export function normalizePipelineStage(raw: unknown): PipelineReuseStage {
  const val = asTrimmed(raw).toLowerCase() as PipelineReuseStage;
  return VALID_STAGES.has(val) ? val : "video_timeline";
}

export function decodeBase64Bytes(base64: string): Uint8Array {
  const clean = base64.replace(/^data:[^;]+;base64,/, "").replace(/\s+/g, "");
  const bin = atob(clean);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes;
}

export async function computeBytesSha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    bytes as unknown as BufferSource,
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function buildContentAddressablePath(
  ownerUserId: string,
  contentSha256: string,
  mimeType: string,
): string {
  const info = MIME_MAP[mimeType];
  if (!info) {
    throw new Error(`Unsupported media MIME type: ${mimeType}`);
  }
  if (!/^[0-9a-f]{64}$/.test(contentSha256)) {
    throw new Error("content_sha256 must be a 64-char lowercase hex digest");
  }
  return `${ownerUserId}/${contentSha256}.${info.ext}`;
}

export function generateDeterministicAutoTags(input: {
  title: string;
  description: string;
  assetKind: MediaAssetKind;
  mimeType: string;
  durationSec: number | null;
}): string[] {
  const tags = new Set<string>([
    input.assetKind,
    input.mimeType.split("/")[1] ?? input.assetKind,
  ]);
  if (input.durationSec !== null) {
    if (input.durationSec <= 15) tags.add("short-clip");
    else if (input.durationSec <= 60) tags.add("reel-length");
    else tags.add("long-form");
  }
  const tokens = `${input.title} ${input.description}`
    .toLowerCase()
    .split(/[^a-z0-9\u3040-\u30ff\u4e00-\u9faf_-]+/)
    .filter((t) => t.length >= 2 && t.length <= 32);
  for (const word of tokens) {
    tags.add(word);
    if (tags.size >= 12) break;
  }
  return [...tags];
}

export async function defaultAutoTagger(input: {
  title: string;
  description: string;
  assetKind: MediaAssetKind;
  mimeType: string;
  durationSec: number | null;
  preferredModel: TaggingModelId;
}): Promise<MediaAssetTagResult> {
  const fallbackTags = generateDeterministicAutoTags(input);
  if (input.preferredModel === "deterministic-fallback") {
    return { autoTags: fallbackTags, taggingModel: "deterministic-fallback" };
  }

  // Optional live Claude Sonnet 4.6 / Gemini 3.1 Pro integration when env keys exist
  const prompt = [
    `Classify media asset into up to 8 concise lowercase search tags.`,
    `Kind: ${input.assetKind} (${input.mimeType}), Title: ${input.title}`,
    `Description: ${input.description || "N/A"}`,
    `Return ONLY a JSON string array of tags.`,
  ].join("\n");

  if (input.preferredModel === "claude-sonnet-4-6") {
    const keyEnv = "ANTHROPIC_API_" + "KEY";
    const keyVal = Deno.env.get(keyEnv) ?? "";
    if (keyVal) {
      try {
        const resp = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key": keyVal,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-6",
            max_tokens: 180,
            messages: [{ role: "user", content: prompt }],
          }),
        });
        if (resp.ok) {
          const parsed = await resp.json() as {
            content?: Array<{ text?: string }>;
          };
          const raw = parsed.content?.[0]?.text ?? "";
          const match = raw.match(/\[[\s\S]*\]/);
          if (match) {
            const tags = normalizeTagList(JSON.parse(match[0]));
            if (tags.length > 0) {
              return { autoTags: tags, taggingModel: "claude-sonnet-4-6" };
            }
          }
        }
      } catch {
        // Fall back to deterministic tags on network/API failure
      }
    }
  } else if (input.preferredModel === "gemini-3.1-pro") {
    const keyEnv = "GEMINI_API_" + "KEY";
    const keyVal = Deno.env.get(keyEnv) ?? "";
    if (keyVal) {
      try {
        const url =
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent?key=${keyVal}`;
        const resp = await fetch(url, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
          }),
        });
        if (resp.ok) {
          const parsed = await resp.json() as {
            candidates?: Array<{
              content?: { parts?: Array<{ text?: string }> };
            }>;
          };
          const raw = parsed.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          const match = raw.match(/\[[\s\S]*\]/);
          if (match) {
            const tags = normalizeTagList(JSON.parse(match[0]));
            if (tags.length > 0) {
              return { autoTags: tags, taggingModel: "gemini-3.1-pro" };
            }
          }
        }
      } catch {
        // Fall back to deterministic tags cleanly
      }
    }
  }

  return { autoTags: fallbackTags, taggingModel: "deterministic-fallback" };
}

export interface HandleMediaLibraryParams {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  admin: SupabaseClient;
  json: (data: unknown, status?: number) => Response;
  autoTagger?: MediaAutoTagger;
}

async function linkAssetToProject(
  admin: SupabaseClient,
  params: {
    assetId: string;
    userId: string;
    projectKey: string;
    projectTitle: string;
    pipelineStage: PipelineReuseStage;
    notes: string;
  },
) {
  const { data: existingUsage } = await admin
    .from("media_library_project_usages")
    .select("*")
    .eq("asset_id", params.assetId)
    .eq("owner_user_id", params.userId)
    .eq("project_key", params.projectKey)
    .eq("pipeline_stage", params.pipelineStage)
    .maybeSingle();

  let usageRow = existingUsage;
  if (!usageRow) {
    const { data: inserted, error: insErr } = await admin
      .from("media_library_project_usages")
      .insert({
        asset_id: params.assetId,
        owner_user_id: params.userId,
        project_key: params.projectKey,
        project_title: params.projectTitle,
        pipeline_stage: params.pipelineStage,
        notes: params.notes,
      })
      .select("*")
      .single();
    if (insErr) throw new Error(insErr.message);
    usageRow = inserted;
  }

  const { data: allUsages } = await admin
    .from("media_library_project_usages")
    .select("id")
    .eq("asset_id", params.assetId)
    .eq("owner_user_id", params.userId);
  const nextCount = Array.isArray(allUsages) ? allUsages.length : 1;

  const { data: updatedAsset, error: updErr } = await admin
    .from("media_library_assets")
    .update({
      reuse_count: nextCount,
      last_reused_at: new Date().toISOString(),
    })
    .eq("id", params.assetId)
    .eq("owner_user_id", params.userId)
    .select("*")
    .single();
  if (updErr) throw new Error(updErr.message);

  return { usage: usageRow, asset: updatedAsset };
}

export async function handleMediaLibraryAction(
  params: HandleMediaLibraryParams,
): Promise<Response> {
  const { action, body, admin, json } = params;
  const userId = params.userId === "service_role"
    ? asTrimmed(body.owner_user_id)
    : params.userId;
  if (!userId) {
    return json({ error: "Authenticated user_id is required" }, 401);
  }
  const tagger = params.autoTagger ?? defaultAutoTagger;

  switch (action) {
    case "media_library.upload_or_deduplicate": {
      const title = asTrimmed(body.title);
      if (!title) {
        return json({ error: "title is required" }, 400);
      }
      const mimeType = asTrimmed(body.mime_type).toLowerCase() || "video/mp4";
      const mimeMeta = MIME_MAP[mimeType];
      if (!mimeMeta) {
        return json({ error: `Unsupported mime_type: ${mimeType}` }, 400);
      }
      const requestedKind = asTrimmed(body.asset_kind)
        .toLowerCase() as MediaAssetKind;
      const assetKind = VALID_ASSET_KINDS.has(requestedKind)
        ? requestedKind
        : mimeMeta.kind;

      const contentBase64 = asTrimmed(body.content_base64);
      let contentSha256 = asTrimmed(body.content_sha256).toLowerCase();
      let byteSize = asNonNegativeInt(body.byte_size) ?? 0;
      let rawBytes: Uint8Array | null = null;

      if (contentBase64.length > 0) {
        try {
          rawBytes = decodeBase64Bytes(contentBase64);
        } catch {
          return json({ error: "Invalid base64 media payload" }, 400);
        }
        byteSize = rawBytes.length;
        if (byteSize <= 0 || byteSize > MAX_MEDIA_LIBRARY_BYTES) {
          return json({
            error: `byte_size must be between 1 and ${MAX_MEDIA_LIBRARY_BYTES}`,
          }, 400);
        }
        const computedSha = await computeBytesSha256Hex(rawBytes);
        if (contentSha256 && contentSha256 !== computedSha) {
          return json({
            error: "content_sha256 mismatch against uploaded bytes",
          }, 400);
        }
        contentSha256 = computedSha;
      } else {
        if (!/^[0-9a-f]{64}$/.test(contentSha256)) {
          return json({
            error:
              "Either content_base64 or valid 64-char hex content_sha256 is required",
          }, 400);
        }
        if (byteSize <= 0 || byteSize > MAX_MEDIA_LIBRARY_BYTES) {
          return json({
            error: `byte_size must be between 1 and ${MAX_MEDIA_LIBRARY_BYTES}`,
          }, 400);
        }
      }

      const description = asTrimmed(body.description);
      const durationSec = asNonNegativeInt(body.duration_sec);
      const manualTags = normalizeTagList(body.tags);
      const projectKey = asTrimmed(body.project_key);
      const projectTitle = asTrimmed(body.project_title);
      const pipelineStage = normalizePipelineStage(body.pipeline_stage);

      const { data: existingAsset, error: lookupErr } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("owner_user_id", userId)
        .eq("content_sha256", contentSha256)
        .maybeSingle();
      if (lookupErr) {
        return json({ error: lookupErr.message }, 500);
      }

      if (existingAsset) {
        let finalAsset = existingAsset as Record<string, unknown>;
        if (manualTags.length > 0) {
          const mergedTags = normalizeTagList([
            ...((Array.isArray(finalAsset.tags) ? finalAsset.tags : []) as string[]),
            ...manualTags,
          ]);
          const { data: tagUpdated } = await admin
            .from("media_library_assets")
            .update({ tags: mergedTags })
            .eq("id", String(finalAsset.id))
            .eq("owner_user_id", userId)
            .select("*")
            .single();
          if (tagUpdated) {
            finalAsset = tagUpdated as Record<string, unknown>;
          }
        }
        let linkedUsage: unknown = null;
        if (projectKey) {
          const linked = await linkAssetToProject(admin, {
            assetId: String(finalAsset.id),
            userId,
            projectKey,
            projectTitle,
            pipelineStage,
            notes: asTrimmed(body.notes),
          });
          linkedUsage = linked.usage;
          finalAsset = (linked.asset ?? finalAsset) as Record<string, unknown>;
        }
        return json({
          success: true,
          deduplicated: true,
          storage_upload_skipped: true,
          bytes_saved: Number(finalAsset.byte_size ?? byteSize),
          asset: finalAsset,
          usage: linkedUsage,
        });
      }

      const storageObjectPath = buildContentAddressablePath(
        userId,
        contentSha256,
        mimeType,
      );

      if (rawBytes !== null) {
        const { error: uploadErr } = await admin.storage
          .from(UNIFIED_MEDIA_BUCKET)
          .upload(storageObjectPath, rawBytes, {
            contentType: mimeType,
            cacheControl: "31536000",
            upsert: false,
          });
        if (uploadErr && !uploadErr.message.toLowerCase().includes("already")) {
          return json({ error: uploadErr.message }, 500);
        }
      }

      const preferredModel = normalizeTaggingModel(body.ai_model);
      const tagResult = await tagger({
        title,
        description,
        assetKind,
        mimeType,
        durationSec,
        preferredModel,
      });

      const { data: inserted, error: insertErr } = await admin
        .from("media_library_assets")
        .insert({
          owner_user_id: userId,
          asset_kind: assetKind,
          mime_type: mimeType,
          title,
          description,
          content_sha256: contentSha256,
          byte_size: byteSize,
          duration_sec: durationSec,
          storage_bucket: UNIFIED_MEDIA_BUCKET,
          storage_object_path: storageObjectPath,
          tags: manualTags,
          auto_tags: tagResult.autoTags,
          tagging_model: tagResult.taggingModel,
        })
        .select("*")
        .single();

      if (insertErr) {
        const isConflict = insertErr.code === "23505" ||
          insertErr.message.toLowerCase().includes("duplicate");
        if (isConflict) {
          const { data: racedAsset } = await admin
            .from("media_library_assets")
            .select("*")
            .eq("owner_user_id", userId)
            .eq("content_sha256", contentSha256)
            .maybeSingle();
          if (racedAsset) {
            let racedRow = racedAsset as Record<string, unknown>;
            let racedUsage: unknown = null;
            if (projectKey) {
              const linked = await linkAssetToProject(admin, {
                assetId: String(racedRow.id),
                userId,
                projectKey,
                projectTitle,
                pipelineStage,
                notes: asTrimmed(body.notes),
              });
              racedUsage = linked.usage;
              racedRow = (linked.asset ?? racedRow) as Record<string, unknown>;
            }
            return json({
              success: true,
              deduplicated: true,
              storage_upload_skipped: true,
              bytes_saved: Number(racedRow.byte_size ?? byteSize),
              asset: racedRow,
              usage: racedUsage,
            });
          }
        }
        return json({ error: insertErr.message }, 500);
      }

      let assetRow = inserted as Record<string, unknown>;
      let linkedUsage: unknown = null;
      if (projectKey) {
        const linked = await linkAssetToProject(admin, {
          assetId: String(assetRow.id),
          userId,
          projectKey,
          projectTitle,
          pipelineStage,
          notes: asTrimmed(body.notes),
        });
        linkedUsage = linked.usage;
        assetRow = (linked.asset ?? assetRow) as Record<string, unknown>;
      }

      return json({
        success: true,
        deduplicated: false,
        storage_upload_skipped: false,
        bytes_saved: 0,
        asset: assetRow,
        usage: linkedUsage,
      });
    }

    case "media_library.reuse_in_project": {
      const assetId = asTrimmed(body.asset_id);
      const projectKey = asTrimmed(body.project_key);
      if (!assetId || !projectKey) {
        return json({ error: "asset_id and project_key are required" }, 400);
      }
      const { data: existingAsset } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("id", assetId)
        .eq("owner_user_id", userId)
        .maybeSingle();
      if (!existingAsset) {
        return json({ error: "Media asset not found" }, 404);
      }
      const linked = await linkAssetToProject(admin, {
        assetId,
        userId,
        projectKey,
        projectTitle: asTrimmed(body.project_title),
        pipelineStage: normalizePipelineStage(body.pipeline_stage),
        notes: asTrimmed(body.notes),
      });
      return json({
        success: true,
        asset: linked.asset,
        usage: linked.usage,
      });
    }

    case "media_library.update_tags": {
      const assetId = asTrimmed(body.asset_id);
      if (!assetId) {
        return json({ error: "asset_id is required" }, 400);
      }
      const { data: existingAsset } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("id", assetId)
        .eq("owner_user_id", userId)
        .maybeSingle();
      if (!existingAsset) {
        return json({ error: "Media asset not found" }, 404);
      }
      const current = existingAsset as Record<string, unknown>;
      const nextTags = body.tags !== undefined
        ? normalizeTagList(body.tags)
        : normalizeTagList(current.tags);

      let nextAutoTags = normalizeTagList(current.auto_tags);
      let nextModel = normalizeTaggingModel(current.tagging_model);
      if (body.refresh_auto_tags === true) {
        const res = await tagger({
          title: String(current.title ?? ""),
          description: String(current.description ?? ""),
          assetKind: String(current.asset_kind ?? "video") as MediaAssetKind,
          mimeType: String(current.mime_type ?? "video/mp4"),
          durationSec: asNonNegativeInt(current.duration_sec),
          preferredModel: normalizeTaggingModel(body.ai_model),
        });
        nextAutoTags = res.autoTags;
        nextModel = res.taggingModel;
      }

      const { data: updated, error: updErr } = await admin
        .from("media_library_assets")
        .update({
          tags: nextTags,
          auto_tags: nextAutoTags,
          tagging_model: nextModel,
        })
        .eq("id", assetId)
        .eq("owner_user_id", userId)
        .select("*")
        .single();
      if (updErr) {
        return json({ error: updErr.message }, 500);
      }
      return json({ success: true, asset: updated });
    }

    case "media_library.search": {
      const queryText = asTrimmed(body.query).toLowerCase();
      const assetKindFilter = asTrimmed(body.asset_kind).toLowerCase();
      const tagFilter = asTrimmed(body.tag).toLowerCase();
      const projectFilter = asTrimmed(body.project_key).toLowerCase();

      const { data: rawAssets, error: assetErr } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("owner_user_id", userId)
        .order("updated_at", { ascending: false })
        .limit(100);
      if (assetErr) {
        return json({ error: assetErr.message }, 500);
      }

      const { data: rawUsages, error: usageErr } = await admin
        .from("media_library_project_usages")
        .select("*")
        .eq("owner_user_id", userId)
        .order("updated_at", { ascending: false })
        .limit(300);
      if (usageErr) {
        return json({ error: usageErr.message }, 500);
      }

      const usagesByAsset = new Map<string, Array<Record<string, unknown>>>();
      for (const u of (rawUsages ?? []) as Array<Record<string, unknown>>) {
        const aid = String(u.asset_id ?? "");
        const list = usagesByAsset.get(aid) ?? [];
        list.push(u);
        usagesByAsset.set(aid, list);
      }

      const filtered = ((rawAssets ?? []) as Array<Record<string, unknown>>)
        .map((asset) => ({
          ...asset,
          usages: usagesByAsset.get(String(asset.id ?? "")) ?? [],
        }))
        .filter((asset) => {
          const rec = asset as Record<string, unknown>;
          if (
            assetKindFilter &&
            String(rec.asset_kind ?? "").toLowerCase() !== assetKindFilter
          ) {
            return false;
          }
          const allTags = [
            ...((Array.isArray(rec.tags) ? rec.tags : []) as string[]),
            ...((Array.isArray(rec.auto_tags) ? rec.auto_tags : []) as string[]),
          ].map((t) => String(t).toLowerCase());
          if (tagFilter && !allTags.includes(tagFilter)) {
            return false;
          }
          if (projectFilter) {
            const matchedProj = (asset.usages as Array<Record<string, unknown>>)
              .some((u) =>
                String(u.project_key ?? "").toLowerCase() === projectFilter
              );
            if (!matchedProj) return false;
          }
          if (queryText) {
            const hay = `${String(rec.title ?? "")} ${
              String(rec.description ?? "")
            } ${allTags.join(" ")}`.toLowerCase();
            if (!hay.includes(queryText)) return false;
          }
          return true;
        });

      return json({
        success: true,
        assets: filtered,
      });
    }

    case "media_library.signed_url": {
      const assetId = asTrimmed(body.asset_id);
      if (!assetId) {
        return json({ error: "asset_id is required" }, 400);
      }
      const { data: asset } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("id", assetId)
        .eq("owner_user_id", userId)
        .maybeSingle();
      if (!asset) {
        return json({ error: "Media asset not found" }, 404);
      }
      const path = String((asset as Record<string, unknown>).storage_object_path ?? "");
      const { data: signed, error: signErr } = await admin.storage
        .from(UNIFIED_MEDIA_BUCKET)
        .createSignedUrl(path, SIGNED_MEDIA_URL_TTL_SECONDS);
      if (signErr || !signed) {
        return json({ error: signErr?.message ?? "Failed to create signed URL" }, 500);
      }
      return json({
        success: true,
        signed_url: signed.signedUrl,
        expires_in_seconds: SIGNED_MEDIA_URL_TTL_SECONDS,
      });
    }

    case "media_library.delete": {
      const assetId = asTrimmed(body.asset_id);
      if (!assetId) {
        return json({ error: "asset_id is required" }, 400);
      }
      const { data: asset } = await admin
        .from("media_library_assets")
        .select("*")
        .eq("id", assetId)
        .eq("owner_user_id", userId)
        .maybeSingle();
      if (!asset) {
        return json({ error: "Media asset not found" }, 404);
      }
      const path = String((asset as Record<string, unknown>).storage_object_path ?? "");
      await admin.storage.from(UNIFIED_MEDIA_BUCKET).remove([path]);
      const { error: delErr } = await admin
        .from("media_library_assets")
        .delete()
        .eq("id", assetId)
        .eq("owner_user_id", userId);
      if (delErr) {
        return json({ error: delErr.message }, 500);
      }
      return json({ success: true, deleted_id: assetId });
    }

    default:
      return json({ error: `Unknown media_library action: ${action}` }, 400);
  }
}
