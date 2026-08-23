import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import { fetchLocalBusinessReferences } from "../_shared/local_business_reference.ts";

export async function handleLocalBusinessReferenceRequest(
  req: Request,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET" && req.method !== "POST") {
    return jsonResponse({ success: false, error: "method_not_allowed" }, 405);
  }

  try {
    const url = new URL(req.url);
    const body = req.method === "POST"
      ? await req.json().catch(() => ({})) as Record<string, unknown>
      : {};
    const targetId = String(
      body.target_id ?? url.searchParams.get("target_id") ??
        "fuchu-honmachi-1",
    );
    if (targetId !== "fuchu-honmachi-1") {
      return jsonResponse({ success: false, error: "unsupported_target" }, 400);
    }
    const payload = await fetchLocalBusinessReferences({
      limit: body.limit ?? url.searchParams.get("limit") ?? 30,
    });
    return jsonResponse(payload);
  } catch (error) {
    console.error("local-business-reference failed", error);
    return jsonResponse({
      success: false,
      error: "public_reference_unavailable",
    }, 502);
  }
}

if (import.meta.main) {
  serve(handleLocalBusinessReferenceRequest);
}
