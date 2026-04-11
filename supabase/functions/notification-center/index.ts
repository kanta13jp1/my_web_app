// Notification Center Edge Function
// 通知センター — アプリ内通知の管理
// - 新機能通知 / CS チケット更新 / 開発実績 / システム通知
// - 既読管理 / 通知設定
// - AI大学 学習リマインダー (3日未学習者への復帰促進)
//
// GET  → 通知一覧 (未読/既読/全件)
// POST → 通知作成 / 既読マーク / 学習リマインダー送信
//
// 追加 action: send_study_reminders (service_role only)
//   AI大学 3日以上未学習のユーザーに `app_notifications` を一括作成する。
//   直近3日以内に同種のリマインダーを送信済みのユーザーはスキップ (スパム防止)。
//   Schedule/Cron から 1日1回呼び出すことを想定。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 通知カテゴリ
const NOTIFICATION_TYPES = [
  "feature_update",   // 新機能
  "achievement",      // 開発実績
  "cs_reply",         // CS 返信
  "system",           // システム通知
  "marketing",        // マーケティング
  "blog_published",   // ブログ投稿
  "agent_report",     // エージェント報告
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Flutter の functions.invoke() はデフォルトで POST を送るが、
    // query params 付きの場合は GET と同じ処理を行う
    const url = new URL(req.url);
    const mode = url.searchParams.get("mode"); // 'user' | 'admin'
    const filter = url.searchParams.get("filter"); // 'unread' | 'read' | 'all'
    const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);

    const isQueryMode = mode !== null; // query params がある場合は一覧取得

    if (req.method === "GET" || (req.method === "POST" && isQueryMode)) {

      if (mode === "admin") {
        // 管理者: 全通知 (service_role)
        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { data, error, count } = await adminClient
          .from("app_notifications")
          .select("*", { count: "exact" })
          .order("created_at", { ascending: false })
          .limit(limit);

        if (error) throw error;

        return new Response(
          JSON.stringify({
            success: true,
            notifications: data ?? [],
            total: count ?? 0,
            types: NOTIFICATION_TYPES,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // ユーザー自身の通知
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        return new Response(
          JSON.stringify({ success: false, error: "Authorization required" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: { user } } = await userClient.auth.getUser();
      if (!user) {
        return new Response(
          JSON.stringify({ success: false, error: "Unauthorized" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      let query = adminClient
        .from("app_notifications")
        .select("*")
        .or(`user_id.eq.${user.id},user_id.is.null`) // ユーザー向け or 全体通知
        .order("created_at", { ascending: false })
        .limit(limit);

      if (filter === "unread") query = query.eq("is_read", false);
      if (filter === "read") query = query.eq("is_read", true);

      // 通知一覧と未読数を並列取得
      const [{ data, error }, { count: unreadCount }] = await Promise.all([
        query,
        adminClient
          .from("app_notifications")
          .select("*", { count: "exact", head: true })
          .or(`user_id.eq.${user.id},user_id.is.null`)
          .eq("is_read", false),
      ]);
      if (error) throw error;

      return new Response(
        JSON.stringify({
          success: true,
          notifications: data ?? [],
          unreadCount: unreadCount ?? 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST" && !isQueryMode) {
      let body: Record<string, unknown> = {};
      try {
        body = await req.json().catch(() => ({}));
      } catch {
        return new Response(
          JSON.stringify({ success: false, error: "Invalid or empty JSON body" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      const { action } = body;

      if (action === "create") {
        // service_role のみ通知作成を許可
        const authHeader = req.headers.get("Authorization");
        const token = authHeader?.replace("Bearer ", "") ?? "";
        if (token !== SERVICE_ROLE_KEY) {
          return new Response(
            JSON.stringify({ success: false, error: "Service role required" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 通知を作成 (service_role)
        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { title, message, type, user_id, link } = body;

        if (!title || !message) {
          return new Response(
            JSON.stringify({ success: false, error: "title and message are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("app_notifications")
          .insert({
            title,
            message,
            type: type ?? "system",
            user_id: user_id ?? null, // null = 全員向け
            link: link ?? null,
            is_read: false,
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, notification: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "mark_read") {
        // 既読マーク
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return new Response(
            JSON.stringify({ success: false, error: "Authorization required" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { notification_id, mark_all } = body;

        if (mark_all) {
          const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            global: { headers: { Authorization: authHeader } },
          });
          const { data: { user } } = await userClient.auth.getUser();
          if (!user) {
            return new Response(
              JSON.stringify({ success: false, error: "Unauthorized" }),
              { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
          }

          const { error } = await adminClient
            .from("app_notifications")
            .update({ is_read: true })
            .or(`user_id.eq.${user.id},user_id.is.null`)
            .eq("is_read", false);

          if (error) throw error;

          return new Response(
            JSON.stringify({ success: true, message: "全通知を既読にしました" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        if (!notification_id) {
          return new Response(
            JSON.stringify({ success: false, error: "notification_id or mark_all is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 所有者確認: 自分の通知のみ既読にできる
        const userClientSingle = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user: singleUser } } = await userClientSingle.auth.getUser();
        if (!singleUser) {
          return new Response(
            JSON.stringify({ success: false, error: "Unauthorized" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_notifications")
          .update({ is_read: true })
          .eq("id", notification_id)
          .eq("user_id", singleUser.id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "send_study_reminders") {
        // service_role のみ (Schedule/Cron からの一括送信専用)
        const authHeader = req.headers.get("Authorization");
        const token = authHeader?.replace("Bearer ", "") ?? "";
        if (token !== SERVICE_ROLE_KEY) {
          return new Response(
            JSON.stringify({ success: false, error: "Service role required" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        // パラメータ: 何日間未学習でリマインドするか (既定 3)
        // dry_run: true なら DB 書き込みせず対象のみ返却
        const minIdleDays = typeof body.min_idle_days === "number"
          ? Math.max(1, Math.min(30, body.min_idle_days as number))
          : 3;
        const maxIdleDays = typeof body.max_idle_days === "number"
          ? Math.max(minIdleDays, Math.min(90, body.max_idle_days as number))
          : 30; // 30日以上未学習は諦めて対象外 (完全離脱とみなす)
        const dryRun = Boolean(body.dry_run);

        // JST ベースで last_studied_date を比較するため、日付を直接計算
        const nowJst = new Date(Date.now() + 9 * 60 * 60 * 1000); // +9h for JST
        const today = nowJst.toISOString().slice(0, 10);
        const minDate = new Date(nowJst.getTime() - maxIdleDays * 86_400_000)
          .toISOString().slice(0, 10);
        const maxDate = new Date(nowJst.getTime() - minIdleDays * 86_400_000)
          .toISOString().slice(0, 10);

        // 対象ユーザー取得: last_studied_date が [minDate, maxDate] の範囲
        // = 3日以上 30日未満の未学習ユーザー
        const { data: streakRows, error: streakErr } = await adminClient
          .from("ai_university_streaks")
          .select("user_id, current_streak, longest_streak, last_studied_date")
          .gte("last_studied_date", minDate)
          .lte("last_studied_date", maxDate);

        if (streakErr) throw streakErr;

        const candidates = streakRows ?? [];
        if (candidates.length === 0) {
          return new Response(
            JSON.stringify({
              success: true,
              eligible: 0,
              sent: 0,
              skipped_recently_reminded: 0,
              dry_run: dryRun,
              today,
              window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // スパム防止: 直近 minIdleDays 日以内に同種のリマインダーを受け取っている
        // ユーザーをスキップする。type='system' + title が既定の prefix で判定
        const REMINDER_TITLE_PREFIX = "[AI大学] 学習リマインダー";
        const reminderSinceIso = new Date(
          Date.now() - minIdleDays * 86_400_000,
        ).toISOString();

        const userIds = candidates.map((row) =>
          (row as { user_id: string }).user_id
        );

        const { data: recentRows, error: recentErr } = await adminClient
          .from("app_notifications")
          .select("user_id")
          .in("user_id", userIds)
          .eq("type", "system")
          .ilike("title", `${REMINDER_TITLE_PREFIX}%`)
          .gte("created_at", reminderSinceIso);

        if (recentErr) throw recentErr;

        const recentlyReminded = new Set<string>();
        for (const row of recentRows ?? []) {
          const uid = (row as { user_id: string | null }).user_id;
          if (typeof uid === "string") recentlyReminded.add(uid);
        }

        // 未リマインド対象だけ抽出
        const targets = candidates.filter((row) => {
          const uid = (row as { user_id: string }).user_id;
          return !recentlyReminded.has(uid);
        });

        if (targets.length === 0 || dryRun) {
          return new Response(
            JSON.stringify({
              success: true,
              eligible: candidates.length,
              sent: 0,
              skipped_recently_reminded: recentlyReminded.size,
              targets: dryRun ? targets.length : undefined,
              dry_run: dryRun,
              today,
              window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // INSERT ペイロード: 復帰促進メッセージをユーザーごとに生成
        const createdAt = new Date().toISOString();
        const payload = targets.map((row) => {
          const r = row as {
            user_id: string;
            current_streak: number;
            longest_streak: number;
            last_studied_date: string;
          };
          const idleDays = Math.max(
            0,
            Math.floor(
              (Date.parse(today) - Date.parse(r.last_studied_date)) / 86_400_000,
            ),
          );
          const bestStreak = Math.max(r.current_streak, r.longest_streak);
          const title = `${REMINDER_TITLE_PREFIX} — ${idleDays}日ぶりにAIを学ぼう`;
          const message = bestStreak > 1
            ? `前回の学習から${idleDays}日経過。過去最長 ${bestStreak} 日連続を更新しよう！1分クイズでストリーク復活。`
            : `前回の学習から${idleDays}日経過。AI大学で1分クイズに挑戦して知識をアップデート。`;
          return {
            user_id: r.user_id,
            title,
            message,
            type: "system",
            link: "/ai-university",
            is_read: false,
            created_at: createdAt,
          };
        });

        const { error: insertErr } = await adminClient
          .from("app_notifications")
          .insert(payload);

        if (insertErr) throw insertErr;

        return new Response(
          JSON.stringify({
            success: true,
            eligible: candidates.length,
            sent: payload.length,
            skipped_recently_reminded: recentlyReminded.size,
            dry_run: false,
            today,
            window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("notification-center error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
