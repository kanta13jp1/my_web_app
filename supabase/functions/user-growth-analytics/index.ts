import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "overview";

    // GET: User growth overview
    if (action === "overview") {
      // Get total user count from auth.users via get-admin-users pattern
      const { data: { users }, error: usersError } = await supabase.auth.admin.listUsers({
        perPage: 1000,
      });

      if (usersError) {
        return new Response(
          JSON.stringify({ error: usersError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const totalUsers = users?.length ?? 0;
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      const weekStart = new Date(now.getTime() - 7 * 86400000).toISOString();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

      const usersToday = users?.filter(u => u.created_at >= todayStart).length ?? 0;
      const usersThisWeek = users?.filter(u => u.created_at >= weekStart).length ?? 0;
      const usersThisMonth = users?.filter(u => u.created_at >= monthStart).length ?? 0;

      // Daily registration trend (last 30 days)
      const dailyTrend: Array<{ date: string; registrations: number; cumulative: number }> = [];
      for (let i = 29; i >= 0; i--) {
        const dayStart = new Date(now.getTime() - i * 86400000);
        const dayStr = dayStart.toISOString().split("T")[0];
        const dayEnd = new Date(dayStart.getTime() + 86400000);
        const count = users?.filter(u =>
          u.created_at >= dayStart.toISOString() && u.created_at < dayEnd.toISOString()
        ).length ?? 0;

        const cumulative = users?.filter(u =>
          u.created_at < dayEnd.toISOString()
        ).length ?? 0;

        dailyTrend.push({ date: dayStr, registrations: count, cumulative });
      }

      // Registration source analysis from app_analytics
      const { data: signupEvents } = await supabase
        .from("app_analytics")
        .select("metadata")
        .eq("metadata->>event_type", "user_signup")
        .gte("created_at", monthStart)
        .limit(500);

      const sourceBreakdown: Record<string, number> = {};
      for (const event of (signupEvents ?? [])) {
        const ed = event.metadata as Record<string, unknown>;
        const source = (ed?.source as string) ?? "direct";
        sourceBreakdown[source] = (sourceBreakdown[source] ?? 0) + 1;
      }

      // Growth rate calculation
      const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString();
      const prevMonthEnd = monthStart;
      const usersPrevMonth = users?.filter(u =>
        u.created_at >= prevMonthStart && u.created_at < prevMonthEnd
      ).length ?? 0;

      const monthlyGrowthRate = usersPrevMonth > 0
        ? Math.round(((usersThisMonth - usersPrevMonth) / usersPrevMonth) * 100)
        : usersThisMonth > 0 ? 100 : 0;

      // Projected users (linear extrapolation)
      const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
      const dayOfMonth = now.getDate();
      const projectedMonthly = dayOfMonth > 0
        ? Math.round((usersThisMonth / dayOfMonth) * daysInMonth)
        : 0;

      // Viral coefficient (k-factor) from referrals
      const { data: referralEvents } = await supabase
        .from("app_analytics")
        .select("metadata")
        .eq("source", "growth-referral")
        .gte("created_at", monthStart)
        .limit(500);

      const totalReferrals = referralEvents?.length ?? 0;
      const kFactor = totalUsers > 0 ? Math.round((totalReferrals / totalUsers) * 100) / 100 : 0;

      return new Response(
        JSON.stringify({
          overview: {
            totalUsers,
            usersToday,
            usersThisWeek,
            usersThisMonth,
            monthlyGrowthRate,
            projectedMonthlyRegistrations: projectedMonthly,
            kFactor,
          },
          dailyTrend,
          sourceBreakdown,
          milestones: {
            current: totalUsers,
            next: totalUsers < 10 ? 10 : totalUsers < 50 ? 50 : totalUsers < 100 ? 100 : totalUsers < 500 ? 500 : 1000,
            progress: totalUsers < 10 ? Math.round((totalUsers / 10) * 100) :
              totalUsers < 50 ? Math.round((totalUsers / 50) * 100) :
              totalUsers < 100 ? Math.round((totalUsers / 100) * 100) :
              totalUsers < 500 ? Math.round((totalUsers / 500) * 100) :
              Math.round((totalUsers / 1000) * 100),
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=funnel — Registration funnel analysis
    if (action === "funnel") {
      const { data: funnelEvents } = await supabase
        .from("app_analytics")
        .select("event_type, source")
        .in("metadata->>event_type", [
          "page_view", "landing_view", "signup_started", "signup_completed",
          "onboarding_started", "onboarding_completed", "first_action",
        ])
        .gte("created_at", new Date(Date.now() - 30 * 86400000).toISOString())
        .limit(5000);

      const funnelCounts: Record<string, number> = {};
      for (const event of (funnelEvents ?? [])) {
        const et = event.event_type as string;
        funnelCounts[et] = (funnelCounts[et] ?? 0) + 1;
      }

      const steps = [
        { name: "ランディングページ閲覧", key: "landing_view", count: funnelCounts["landing_view"] ?? 0 },
        { name: "会員登録開始", key: "signup_started", count: funnelCounts["signup_started"] ?? 0 },
        { name: "会員登録完了", key: "signup_completed", count: funnelCounts["signup_completed"] ?? 0 },
        { name: "オンボーディング開始", key: "onboarding_started", count: funnelCounts["onboarding_started"] ?? 0 },
        { name: "オンボーディング完了", key: "onboarding_completed", count: funnelCounts["onboarding_completed"] ?? 0 },
        { name: "初回アクション", key: "first_action", count: funnelCounts["first_action"] ?? 0 },
      ];

      // Calculate conversion rates between steps
      const funnelWithRates = steps.map((step, i) => ({
        ...step,
        conversionFromPrevious: i > 0 && steps[i - 1].count > 0
          ? Math.round((step.count / steps[i - 1].count) * 100)
          : 100,
        conversionFromTop: steps[0].count > 0
          ? Math.round((step.count / steps[0].count) * 100)
          : 0,
      }));

      return new Response(
        JSON.stringify({
          period: "30 days",
          funnel: funnelWithRates,
          bottleneck: funnelWithRates.reduce((worst, step) =>
            step.conversionFromPrevious < worst.conversionFromPrevious ? step : worst
          ),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=retention — User retention analysis
    if (action === "retention") {
      const { data: { users } } = await supabase.auth.admin.listUsers({ perPage: 1000 });

      // Get activity logs per user
      const { data: activities } = await supabase
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("metadata->>event_type", "user_activity")
        .gte("created_at", new Date(Date.now() - 30 * 86400000).toISOString())
        .limit(5000);

      const weeklyActiveUsers = new Set<string>();
      const dailyActiveUsers = new Set<string>();
      const now = new Date();
      const weekAgo = new Date(now.getTime() - 7 * 86400000).toISOString();
      const dayAgo = new Date(now.getTime() - 86400000).toISOString();

      for (const activity of (activities ?? [])) {
        const ed = activity.metadata as Record<string, unknown>;
        const userId = ed?.userId as string;
        if (!userId) continue;
        if (activity.created_at >= weekAgo) weeklyActiveUsers.add(userId);
        if (activity.created_at >= dayAgo) dailyActiveUsers.add(userId);
      }

      const totalUsers = users?.length ?? 0;

      return new Response(
        JSON.stringify({
          totalUsers,
          dau: dailyActiveUsers.size,
          wau: weeklyActiveUsers.size,
          dauRate: totalUsers > 0 ? Math.round((dailyActiveUsers.size / totalUsers) * 100) : 0,
          wauRate: totalUsers > 0 ? Math.round((weeklyActiveUsers.size / totalUsers) * 100) : 0,
          stickiness: weeklyActiveUsers.size > 0
            ? Math.round((dailyActiveUsers.size / weeklyActiveUsers.size) * 100)
            : 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=cohort — Weekly cohort retention
    if (action === "cohort") {
      const { data: { users } } = await supabase.auth.admin.listUsers({ perPage: 1000 });
      const now = new Date();

      // Group users by registration week
      const cohorts: Array<{
        weekStart: string;
        usersRegistered: number;
        retainedWeek1: number;
        retainedWeek2: number;
        retainedWeek3: number;
        retainedWeek4: number;
      }> = [];

      for (let w = 7; w >= 0; w--) {
        const weekStart = new Date(now.getTime() - (w + 1) * 7 * 86400000);
        const weekEnd = new Date(now.getTime() - w * 7 * 86400000);
        const weekStr = weekStart.toISOString().split("T")[0];

        const cohortUsers = (users ?? []).filter(u =>
          u.created_at >= weekStart.toISOString() && u.created_at < weekEnd.toISOString()
        );

        // For retention we'd need activity data; using last_sign_in_at as proxy
        const retained = (week: number) => {
          const checkStart = new Date(weekStart.getTime() + week * 7 * 86400000);
          const checkEnd = new Date(checkStart.getTime() + 7 * 86400000);
          if (checkEnd > now) return -1; // Future, unknown
          return cohortUsers.filter(u =>
            u.last_sign_in_at &&
            u.last_sign_in_at >= checkStart.toISOString() &&
            u.last_sign_in_at < checkEnd.toISOString()
          ).length;
        };

        cohorts.push({
          weekStart: weekStr,
          usersRegistered: cohortUsers.length,
          retainedWeek1: retained(1),
          retainedWeek2: retained(2),
          retainedWeek3: retained(3),
          retainedWeek4: retained(4),
        });
      }

      return new Response(
        JSON.stringify({ cohorts }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unknown action",
        validActions: ["overview", "funnel", "retention", "cohort"],
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
