import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Notification severity levels
const SEVERITY = {
  critical: { priority: 1, label: "緊急", color: "#dc2626" },
  warning: { priority: 2, label: "警告", color: "#f59e0b" },
  info: { priority: 3, label: "情報", color: "#3b82f6" },
  success: { priority: 4, label: "成功", color: "#10b981" },
} as const;

type SeverityKey = keyof typeof SEVERITY;

// Notification categories
const CATEGORIES = [
  "schedule_failure",    // Schedule task failed
  "health_check",        // Infra health issue
  "security_alert",      // Security concern
  "user_milestone",      // User registration milestone
  "deploy_status",       // CI/CD deploy result
  "edge_function_error", // Edge Function error
  "support_escalation",  // CS escalation
  "growth_alert",        // Growth metric alert
  "review_needed",       // PR or code review needed
  "system_update",       // System maintenance/update
] as const;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "list";

    // POST: Create a new notification
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const postAction = body.action ?? "create";

      if (postAction === "create") {
        const { title, message, severity, category, metadata } = body;

        if (!title || !severity || !category) {
          return new Response(
            JSON.stringify({ error: "title, severity, and category are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        if (!(severity in SEVERITY)) {
          return new Response(
            JSON.stringify({ error: `Invalid severity. Valid: ${Object.keys(SEVERITY).join(", ")}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const notification = {
          source: "admin-notification-hub",
          metadata: {
            event_type: "notification_created",
            id: crypto.randomUUID(),
            title,
            message: message ?? "",
            severity,
            severityLabel: SEVERITY[severity as SeverityKey].label,
            severityColor: SEVERITY[severity as SeverityKey].color,
            priority: SEVERITY[severity as SeverityKey].priority,
            category,
            isRead: false,
            isDismissed: false,
            metadata: metadata ?? {},
            createdAt: new Date().toISOString(),
          },
        };

        const { error: insertError } = await supabase
          .from("app_analytics")
          .insert(notification);

        if (insertError) {
          return new Response(
            JSON.stringify({ error: insertError.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true, notification: notification.metadata }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Mark notification as read
      if (postAction === "mark_read") {
        const { notificationId } = body;
        if (!notificationId) {
          return new Response(
            JSON.stringify({ error: "notificationId is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // We can't update app_analytics metadata directly, so log a read event
        await supabase.from("app_analytics").insert({
          source: "admin-notification-hub",
          metadata: { event_type: "notification_read", notificationId, readAt: new Date().toISOString() },
        });

        return new Response(
          JSON.stringify({ success: true, notificationId, status: "read" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Dismiss notification
      if (postAction === "dismiss") {
        const { notificationId } = body;
        await supabase.from("app_analytics").insert({
          source: "admin-notification-hub",
          metadata: { event_type: "notification_dismissed", notificationId, dismissedAt: new Date().toISOString() },
        });

        return new Response(
          JSON.stringify({ success: true, notificationId, status: "dismissed" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ error: "Unknown POST action", validActions: ["create", "mark_read", "dismiss"] }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: List notifications
    if (action === "list") {
      const severityFilter = url.searchParams.get("severity");
      const categoryFilter = url.searchParams.get("category");
      const limit = parseInt(url.searchParams.get("limit") ?? "50");

      let query = supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "admin-notification-hub")
        .like("event_type", "notification_%")
        .not("event_type", "in", '("notification_read","notification_dismissed")')
        .order("created_at", { ascending: false })
        .limit(limit);

      if (severityFilter) {
        query = query.eq("metadata->>event_type", `notification_${categoryFilter}`);
      }

      const { data: notifications, error } = await query;

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Get read/dismissed IDs
      const { data: readEvents } = await supabase
        .from("app_analytics")
        .select("metadata")
        .eq("source", "admin-notification-hub")
        .in("metadata->>event_type", ["notification_read", "notification_dismissed"])
        .order("created_at", { ascending: false })
        .limit(500);

      const readIds = new Set(
        (readEvents ?? [])
          .filter((e: Record<string, unknown>) => {
            const ed = e.metadata as Record<string, unknown> | null;
            return ed?.notificationId;
          })
          .map((e: Record<string, unknown>) => (e.metadata as Record<string, unknown>).notificationId)
      );
      const dismissedIds = new Set(
        (readEvents ?? [])
          .filter((e: Record<string, unknown>) => {
            const ed = e.metadata as Record<string, unknown> | null;
            return ed?.dismissedAt;
          })
          .map((e: Record<string, unknown>) => (e.metadata as Record<string, unknown>).notificationId)
      );

      const enrichedNotifications = (notifications ?? [])
        .map((n: Record<string, unknown>) => {
          const ed = n.metadata as Record<string, unknown>;
          return {
            ...ed,
            isRead: readIds.has(ed.id),
            isDismissed: dismissedIds.has(ed.id),
            dbCreatedAt: n.created_at,
          };
        })
        .filter((n: Record<string, unknown>) => {
          if (severityFilter && n.severity !== severityFilter) return false;
          if (categoryFilter && n.category !== categoryFilter) return false;
          return true;
        });

      const unreadCount = enrichedNotifications.filter(
        (n: Record<string, unknown>) => !n.isRead && !n.isDismissed
      ).length;

      const criticalCount = enrichedNotifications.filter(
        (n: Record<string, unknown>) => n.severity === "critical" && !n.isDismissed
      ).length;

      return new Response(
        JSON.stringify({
          totalCount: enrichedNotifications.length,
          unreadCount,
          criticalCount,
          notifications: enrichedNotifications,
          categories: CATEGORIES,
          severityLevels: SEVERITY,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=summary — quick badge counts for dashboard
    if (action === "summary") {
      const { data: recent } = await supabase
        .from("app_analytics")
        .select("metadata")
        .eq("source", "admin-notification-hub")
        .like("event_type", "notification_%")
        .not("event_type", "in", '("notification_read","notification_dismissed")')
        .gte("created_at", new Date(Date.now() - 24 * 3600000).toISOString())
        .order("created_at", { ascending: false })
        .limit(100);

      const bySeverity: Record<string, number> = { critical: 0, warning: 0, info: 0, success: 0 };
      for (const r of (recent ?? [])) {
        const ed = r.metadata as Record<string, unknown>;
        const sev = ed.severity as string;
        if (sev in bySeverity) bySeverity[sev]++;
      }

      return new Response(
        JSON.stringify({
          last24h: (recent ?? []).length,
          bySeverity,
          needsAttention: bySeverity.critical + bySeverity.warning,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action", validActions: ["list", "summary"] }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
