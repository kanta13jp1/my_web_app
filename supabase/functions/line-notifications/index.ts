import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const LINE_NOTIFY_API = "https://notify-api.line.me/api/notify";

interface LineConfig {
  notify_token: string;
  triggers: string[];
}

interface AnalyticsRow {
  metadata: Record<string, unknown>;
  created_at: string;
}

function maskToken(token: string): string {
  if (!token) return "";
  if (token.length <= 8) return "****";
  return token.slice(0, 4) + "****" + token.slice(-4);
}

async function getLineConfig(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<LineConfig | null> {
  const { data } = await supabase
    .from("app_analytics")
    .select("metadata")
    .eq("source", "line_config")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  if (!data) return null;
  const meta = data.metadata as Record<string, unknown>;
  return {
    notify_token: (meta.notify_token as string) ?? "",
    triggers: (meta.triggers as string[]) ?? [],
  };
}

async function sendLineMessage(
  token: string,
  message: string,
): Promise<{ ok: boolean; status: number }> {
  const params = new URLSearchParams();
  params.append("message", message);

  const res = await fetch(LINE_NOTIFY_API, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });
  return { ok: res.ok, status: res.status };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: corsHeaders },
      );
    }

    const supabaseClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } =
      await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const action: string = body.action ?? "get_config";

    if (action === "get_config") {
      const config = await getLineConfig(supabaseClient, user.id);

      const { data: history } = await supabaseClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "line_notification")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(10);

      return new Response(
        JSON.stringify({
          token_masked: config ? maskToken(config.notify_token) : "",
          token_configured: !!config?.notify_token,
          triggers: config?.triggers ?? [],
          history: (history as AnalyticsRow[] | null)?.map((h) => ({
            message: (h.metadata as Record<string, unknown>).message,
            sent_at: h.created_at,
          })) ?? [],
        }),
        { headers: corsHeaders },
      );
    }

    if (action === "configure") {
      const notifyToken: string = body.notify_token ?? "";
      const triggers: string[] = body.triggers ?? [];

      if (!notifyToken) {
        return new Response(
          JSON.stringify({ error: "notify_token is required" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const existing = await getLineConfig(supabaseClient, user.id);

      if (existing) {
        await supabaseClient
          .from("app_analytics")
          .update({
            metadata: { notify_token: notifyToken, triggers },
            updated_at: new Date().toISOString(),
          })
          .eq("source", "line_config")
          .eq("user_id", user.id);
      } else {
        await supabaseClient.from("app_analytics").insert({
          user_id: user.id,
          source: "line_config",
          metadata: { notify_token: notifyToken, triggers },
          created_at: new Date().toISOString(),
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          token_masked: maskToken(notifyToken),
          triggers,
        }),
        { headers: corsHeaders },
      );
    }

    if (action === "test") {
      const config = await getLineConfig(supabaseClient, user.id);

      if (!config?.notify_token) {
        return new Response(
          JSON.stringify({ error: "LINE Notify token not configured" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const testMessage =
        "\n自分株式会社 LINE通知テスト: 接続に成功しました！ ✅";
      const result = await sendLineMessage(config.notify_token, testMessage);

      await supabaseClient.from("app_analytics").insert({
        user_id: user.id,
        source: "line_notification",
        metadata: {
          message: testMessage,
          status: result.status,
          ok: result.ok,
        },
        created_at: new Date().toISOString(),
      });

      if (!result.ok) {
        return new Response(
          JSON.stringify({
            success: false,
            error: `LINE Notify API returned ${result.status}`,
          }),
          { status: 502, headers: corsHeaders },
        );
      }

      return new Response(
        JSON.stringify({ success: true, message: testMessage }),
        { headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: corsHeaders },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
