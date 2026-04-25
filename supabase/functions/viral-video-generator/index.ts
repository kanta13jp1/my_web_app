import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  authorizeAutomationActor,
  type AutomationActor,
} from "../_shared/automation-auth.ts";
import {
  asRecord,
  asString,
  asStringArray,
  corsHeaders,
  jsonResponse,
  requireEnv,
} from "../_shared/edge.ts";
import {
  generateViralBrief,
  queueViralVideoRender,
  type ViralCampaignBrief,
  type ViralCampaignInput,
} from "../_shared/viral-growth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const VIDEO_PROVIDER_URL = Deno.env.get("VIRAL_VIDEO_PROVIDER_URL") ?? "";
const VIDEO_PROVIDER_NAME = Deno.env.get("VIRAL_VIDEO_PROVIDER_NAME") ??
  "generic-video-provider";
// deno-lint-ignore no-explicit-any
type AdminClient = any;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    requireEnv("SUPABASE_URL");
    requireEnv("SERVICE_ROLE_KEY");

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const actor = await authorizeAutomationActor(admin, req);

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view") ?? "config";
      if (view === "recent_briefs") {
        return jsonResponse({
          success: true,
          briefs: await listEntries(admin, "viral_video_brief"),
        });
      }
      if (view === "jobs") {
        return jsonResponse({
          success: true,
          jobs: await listEntries(admin, "viral_video_job"),
        });
      }
      if (view === "assets") {
        return jsonResponse({
          success: true,
          assets: await listEntries(admin, "viral_video_asset"),
        });
      }
      return jsonResponse({
        success: true,
        providerConfigured: VIDEO_PROVIDER_URL !== "",
        providerName: VIDEO_PROVIDER_NAME,
        supportedActions: [
          "generate_brief",
          "queue_render",
          "complete_render",
        ],
      });
    }

    if (req.method !== "POST") {
      throw new Error("Method not allowed.");
    }

    const body = asRecord(await req.json().catch(() => ({})));
    const action = asString(body.action) || "generate_brief";

    if (action === "generate_brief") {
      const input = parseCampaignInput(body);
      const brief = await generateViralBrief(input);
      await insertLog(admin, actor, "viral_video_brief", {
        campaign_id: brief.campaignId,
        brief,
      });
      return jsonResponse({ success: true, brief });
    }

    if (action === "queue_render") {
      const brief = await resolveBrief(body);
      const job = await queueViralVideoRender(brief, {
        aspectRatio: asString(body.aspectRatio) || "9:16",
        dryRun: body.dryRun === true,
        callbackUrl: asString(body.callbackUrl),
        providerPayload: asRecord(body.providerPayload),
      });
      await insertLog(admin, actor, "viral_video_job", {
        campaign_id: brief.campaignId,
        brief,
        job,
      });
      return jsonResponse({ success: true, brief, job });
    }

    if (action === "complete_render") {
      const campaignId = asString(body.campaignId);
      const videoUrl = asString(body.videoUrl);
      if (campaignId === "" || videoUrl === "") {
        throw new Error("campaignId and videoUrl are required.");
      }
      const asset = {
        campaign_id: campaignId,
        job_id: asString(body.jobId),
        video_url: videoUrl,
        thumbnail_url: asString(body.thumbnailUrl) || null,
        status: asString(body.status) || "completed",
      };
      await insertLog(admin, actor, "viral_video_asset", asset);
      return jsonResponse({ success: true, asset });
    }

    throw new Error(`Unknown action: ${action}`);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

async function listEntries(
  admin: AdminClient,
  source: string,
): Promise<Record<string, unknown>[]> {
  const { data, error } = await admin
    .from("app_analytics")
    .select("metadata, created_at")
    .eq("source", source)
    .order("created_at", { ascending: false })
    .limit(20);
  if (error) {
    throw error;
  }
  const rows = (data ?? []) as Array<Record<string, unknown>>;
  return rows.map((row) => ({
    ...asRecord(row.metadata),
    createdAt: row.created_at,
  }));
}

async function resolveBrief(
  body: Record<string, unknown>,
): Promise<ViralCampaignBrief> {
  const briefRecord = asRecord(body.brief);
  if (asString(briefRecord.campaignId) !== "") {
    return {
      campaignId: asString(briefRecord.campaignId),
      conceptName: asString(briefRecord.conceptName),
      audience: asString(briefRecord.audience),
      primaryHook: asString(briefRecord.primaryHook),
      secondaryHooks: asStringArray(briefRecord.secondaryHooks, 4),
      cta: asString(briefRecord.cta),
      xPostText: asString(briefRecord.xPostText),
      hashtags: asStringArray(briefRecord.hashtags, 8),
      overlayLines: asStringArray(briefRecord.overlayLines, 6),
      shareAngles: asStringArray(briefRecord.shareAngles, 6),
      complianceNotes: asStringArray(briefRecord.complianceNotes, 6),
      renderPrompt: asString(briefRecord.renderPrompt),
      desiredDurationSec: Number(briefRecord.desiredDurationSec ?? 20),
      viralScore: Number(briefRecord.viralScore ?? 70),
      landingUrl: asString(briefRecord.landingUrl),
      scenes: (Array.isArray(briefRecord.scenes) ? briefRecord.scenes : []).map(
        (scene, index) => {
          const record = asRecord(scene);
          return {
            sceneNo: Number(record.sceneNo ?? index + 1),
            durationSec: Number(record.durationSec ?? 4),
            visual: asString(record.visual),
            overlayText: asString(record.overlayText),
            voiceover: asString(record.voiceover),
            motion: asString(record.motion),
          };
        },
      ),
    };
  }
  return await generateViralBrief(parseCampaignInput(body));
}

function parseCampaignInput(body: Record<string, unknown>): ViralCampaignInput {
  return {
    appName: asString(body.appName) || "My Web App",
    productSummary: asString(body.productSummary),
    landingUrl: asString(body.landingUrl),
    targetAudience: asString(body.targetAudience),
    valueProposition: asString(body.valueProposition),
    painPoint: asString(body.painPoint),
    differentiators: asStringArray(body.differentiators, 6),
    seedHooks: asStringArray(body.seedHooks, 6),
    constraints: asStringArray(body.constraints, 6),
    tone: asString(body.tone),
    adStyle: asString(body.adStyle),
    desiredDurationSec: Number(body.desiredDurationSec ?? 20),
  };
}

async function insertLog(
  admin: AdminClient,
  actor: AutomationActor,
  source: string,
  metadata: Record<string, unknown>,
) {
  const { error } = await admin.from("app_analytics").insert({
    ...(actor.userId ? { user_id: actor.userId } : {}),
    source,
    metadata: {
      ...metadata,
      actor_mode: actor.mode,
      actor_email: actor.email ?? null,
    },
    created_at: new Date().toISOString(),
  });
  if (error) {
    throw error;
  }
}
