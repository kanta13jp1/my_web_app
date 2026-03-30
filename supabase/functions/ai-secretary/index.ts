// AI Secretary Edge Function
// AI 秘書: ユーザーの活動データを分析し、次にすべきことを提案
// - 未完了タスクの優先度提案
// - プロフィール完成促進
// - 機能リクエストへの対応提案
// - 競合分析に基づく開発優先度
// - 性格・行動パターン記憶
//
// POST → AI 秘書に質問 / 提案リクエスト

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      // ダッシュボード用: 今日の提案を取得
      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      // データ収集
      const [usersRes, requestsRes, achievementsRes, ticketsRes] = await Promise.all([
        adminClient.from("user_profiles").select("*", { count: "exact", head: true }),
        adminClient.from("feature_requests").select("id, title, votes, status").eq("status", "open").order("votes", { ascending: false }).limit(5),
        adminClient.from("development_achievements").select("id, title, completed_at").order("completed_at", { ascending: false }).limit(5),
        adminClient.from("support_tickets").select("id, title, status").eq("status", "new").limit(5),
      ]);

      const totalUsers = usersRes.count ?? 0;
      const topRequests = requestsRes.data ?? [];
      const recentAchievements = achievementsRes.data ?? [];
      const openTickets = ticketsRes.data ?? [];

      // AI 秘書の提案を生成 (ルールベース)
      const suggestions: Array<{ priority: string; category: string; title: string; description: string; action: string }> = [];

      // ユーザー数に基づく提案
      if (totalUsers < 10) {
        suggestions.push({
          priority: "high",
          category: "growth",
          title: "ユーザー獲得を加速",
          description: `現在 ${totalUsers} 人。SNS 投稿・技術ブログ・リファラル施策で 10 人突破を目指しましょう`,
          action: "SNS 投稿ドラフトを作成 → X に投稿",
        });
      }

      // 未対応チケット
      if (openTickets.length > 0) {
        suggestions.push({
          priority: "high",
          category: "cs",
          title: `未対応 CS チケット ${openTickets.length} 件`,
          description: openTickets.map((t) => t.title).join(", "),
          action: "CS チケット一覧を確認して返信",
        });
      }

      // 機能リクエスト
      if (topRequests.length > 0) {
        const top = topRequests[0];
        suggestions.push({
          priority: "medium",
          category: "development",
          title: `投票数トップの機能リクエスト: ${top.title}`,
          description: `${top.votes ?? 0} 票。ユーザーの期待に応えましょう`,
          action: "機能リクエストを実装開始",
        });
      }

      // ブログ投稿チェック
      const today = new Date().toISOString().slice(0, 10);
      const { count: blogCount } = await adminClient
        .from("blog_posts")
        .select("*", { count: "exact", head: true })
        .eq("status", "posted")
        .gte("posted_at", `${today}T00:00:00`);

      if ((blogCount ?? 0) === 0) {
        suggestions.push({
          priority: "medium",
          category: "marketing",
          title: "今日の技術ブログ未投稿",
          description: "毎日の技術ブログ投稿で認知度を上げましょう",
          action: "ブログ下書きを確認して投稿",
        });
      }

      // 開発実績の連続記録
      suggestions.push({
        priority: "low",
        category: "motivation",
        title: `直近の開発実績: ${recentAchievements.length} 件`,
        description: recentAchievements.map((a) => a.title).join(" / "),
        action: "次の実装タスクに取り掛かる",
      });

      return new Response(
        JSON.stringify({
          success: true,
          suggestions,
          context: {
            totalUsers,
            openTickets: openTickets.length,
            topFeatureRequests: topRequests.length,
            todayBlogPosts: blogCount ?? 0,
            recentAchievements: recentAchievements.length,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      // AI 秘書への質問
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

      const body = await req.json();
      const { message, context } = body;

      if (!message) {
        return new Response(
          JSON.stringify({ success: false, error: "message is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // 会話ログを記録
      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      await adminClient.from("ai_secretary_logs").insert({
        user_id: user.id,
        message,
        context: context ?? {},
        created_at: new Date().toISOString(),
      });

      // ルールベースの回答生成
      const lowerMsg = message.toLowerCase();
      let reply = "";

      if (lowerMsg.includes("今日") && lowerMsg.includes("やる")) {
        reply = "今日のおすすめタスク:\n1. 未対応 CS チケットの確認・返信\n2. 技術ブログの投稿\n3. 機能リクエストのトップ投票項目の実装\n4. SNS での進捗共有";
      } else if (lowerMsg.includes("ユーザー") && lowerMsg.includes("増")) {
        reply = "ユーザー獲得のための施策:\n1. 技術ブログを毎日投稿 (Zenn, Qiita 等)\n2. X で #buildinpublic タグで進捗共有\n3. リファラルプログラムの活用\n4. SEO 最適化 (メタタグ、サイトマップ)\n5. Product Hunt への掲載";
      } else if (lowerMsg.includes("競合")) {
        reply = "競合分析のポイント:\n21 社の競合に対し、AI 統合が最大の差別化要因です。\n特に Notion / Evernote ユーザーのインポート機能と、\nAI 秘書による自動化が他社にない価値を提供します。";
      } else {
        reply = `承知しました。「${message}」について調査・検討します。\n管理ダッシュボードで詳細な分析結果を確認できます。`;
      }

      return new Response(
        JSON.stringify({ success: true, reply, timestamp: new Date().toISOString() }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-secretary error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
