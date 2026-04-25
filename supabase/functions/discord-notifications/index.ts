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

interface DiscordConfig {
  webhook_url: string;
  triggers: string[];
}

interface AnalyticsRow {
  metadata: Record<string, unknown>;
  created_at: string;
  source: string;
}

function maskWebhookUrl(url: string): string {
  if (!url) return "";
  try {
    const u = new URL(url);
    const path = u.pathname;
    const parts = path.split("/");
    if (parts.length >= 2) {
      const last = parts[parts.length - 1];
      parts[parts.length - 1] =
        last.slice(0, 4) + "****" + last.slice(-4);
    }
    return u.origin + parts.join("/");
  } catch {
    return url.slice(0, 8) + "****";
  }
}

async function getDiscordConfig(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<DiscordConfig | null> {
  const { data } = await supabase
    .from("app_analytics")
    .select("metadata")
    .eq("source", "discord_config")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  if (!data) return null;
  const meta = data.metadata as Record<string, unknown>;
  return {
    webhook_url: (meta.webhook_url as string) ?? "",
    triggers: (meta.triggers as string[]) ?? [],
  };
}

async function sendDiscordMessage(
  webhookUrl: string,
  message: string,
): Promise<{ ok: boolean; status: number }> {
  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: message }),
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
      const config = await getDiscordConfig(supabaseClient, user.id);

      const { data: history } = await supabaseClient
        .from("app_analytics")
        .select("metadata, created_at, source")
        .eq("source", "discord_notification")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(10);

      return new Response(
        JSON.stringify({
          webhook_url_masked: config ? maskWebhookUrl(config.webhook_url) : "",
          webhook_configured: !!config?.webhook_url,
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
      const webhookUrl: string = body.webhook_url ?? "";
      const triggers: string[] = body.triggers ?? [];

      if (!webhookUrl) {
        return new Response(
          JSON.stringify({ error: "webhook_url is required" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const existing = await getDiscordConfig(supabaseClient, user.id);

      if (existing) {
        await supabaseClient
          .from("app_analytics")
          .update({
            metadata: { webhook_url: webhookUrl, triggers },
            updated_at: new Date().toISOString(),
          })
          .eq("source", "discord_config")
          .eq("user_id", user.id);
      } else {
        await supabaseClient.from("app_analytics").insert({
          user_id: user.id,
          source: "discord_config",
          metadata: { webhook_url: webhookUrl, triggers },
          created_at: new Date().toISOString(),
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          webhook_url_masked: maskWebhookUrl(webhookUrl),
          triggers,
        }),
        { headers: corsHeaders },
      );
    }

    if (action === "test") {
      const config = await getDiscordConfig(supabaseClient, user.id);

      if (!config?.webhook_url) {
        return new Response(
          JSON.stringify({ error: "Discord webhook not configured" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const testMessage =
        "自分株式会社 Discord通知テスト: 接続に成功しました！ ✅";
      const result = await sendDiscordMessage(config.webhook_url, testMessage);

      await supabaseClient.from("app_analytics").insert({
        user_id: user.id,
        source: "discord_notification",
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
            error: `Discord webhook returned ${result.status}`,
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
