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

      // 部署別タスク状況
      const { data: agentTasks } = await adminClient
        .from("agent_tasks")
        .select("department, status")
        .in("status", ["pending", "in_progress"]);

      const deptTaskCounts: Record<string, number> = {};
      for (const t of agentTasks ?? []) {
        const dept = (t.department as string) ?? "未所属";
        deptTaskCounts[dept] = (deptTaskCounts[dept] ?? 0) + 1;
      }

      // Schedule ヘルス
      const oneDayAgo = new Date(Date.now() - 86400000).toISOString();
      const { data: scheduleRuns } = await adminClient
        .from("schedule_task_runs")
        .select("task_name, status")
        .gte("started_at", oneDayAgo);

      const failedSchedules = (scheduleRuns ?? []).filter((r) => r.status === "failure");

      // AI 秘書の提案を生成 (ルールベース — 12部署対応)
      const suggestions: Array<{ priority: string; category: string; title: string; description: string; action: string; department?: string }> = [];

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

      // Schedule 失敗タスク
      if (failedSchedules.length > 0) {
        const uniqueFailed = [...new Set(failedSchedules.map((r) => r.task_name))];
        suggestions.push({
          priority: "high",
          category: "infrastructure",
          title: `Schedule 失敗タスク: ${uniqueFailed.length} 種`,
          description: `失敗: ${uniqueFailed.join(", ")}`,
          action: "Schedule ヘルスチェック画面で詳細を確認し修正",
          department: "インフラ・運用",
        });
      }

      // 部署別タスク負荷
      const highLoadDepts = Object.entries(deptTaskCounts)
        .filter(([, count]) => count >= 5)
        .sort(([, a], [, b]) => b - a);

      if (highLoadDepts.length > 0) {
        suggestions.push({
          priority: "medium",
          category: "organization",
          title: `高負荷部署: ${highLoadDepts.map(([d]) => d).join(", ")}`,
          description: highLoadDepts.map(([d, c]) => `${d}: ${c}件`).join(" / "),
          action: "タスクの優先度を見直し、エージェントの再アサインを検討",
          department: "経営企画",
        });
      }

      // 開発実績の連続記録
      suggestions.push({
        priority: "low",
        category: "motivation",
        title: `直近の開発実績: ${recentAchievements.length} 件`,
        description: recentAchievements.map((a) => a.title).join(" / "),
        action: "次の実装タスクに取り掛かる",
        department: "開発",
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
            failedScheduleTasks: failedSchedules.length,
            activeDepartmentTasks: deptTaskCounts,
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

      // データ収集 (回答の精度向上のため)
      const [usersCountRes, ticketsCountRes, requestsCountRes, blogCountRes, schedFailRes] = await Promise.all([
        adminClient.from("user_profiles").select("*", { count: "exact", head: true }),
        adminClient.from("support_tickets").select("*", { count: "exact", head: true }).eq("status", "new"),
        adminClient.from("feature_requests").select("*", { count: "exact", head: true }).eq("status", "open"),
        adminClient.from("blog_posts").select("*", { count: "exact", head: true }).eq("status", "posted").gte("posted_at", `${new Date().toISOString().slice(0, 10)}T00:00:00`),
        adminClient.from("schedule_task_runs").select("*", { count: "exact", head: true }).eq("status", "failure").gte("started_at", new Date(Date.now() - 86400000).toISOString()),
      ]);

      const stats = {
        users: usersCountRes.count ?? 0,
        tickets: ticketsCountRes.count ?? 0,
        requests: requestsCountRes.count ?? 0,
        todayBlogs: blogCountRes.count ?? 0,
        failedSchedules: schedFailRes.count ?? 0,
      };

      // ルールベースの回答生成 (12部署対応 + 詳細な知識)
      const lowerMsg = message.toLowerCase();
      let reply = "";
      let department = "";

      // 今日やること / タスク関連
      if (lowerMsg.includes("今日") && (lowerMsg.includes("やる") || lowerMsg.includes("タスク") || lowerMsg.includes("何"))) {
        const tasks: string[] = [];
        if (stats.tickets > 0) tasks.push(`CS チケット ${stats.tickets} 件に返信 (CS部)`);
        if (stats.todayBlogs === 0) tasks.push("技術ブログを投稿 (広報部)");
        if (stats.requests > 0) tasks.push(`機能リクエスト ${stats.requests} 件を確認・優先順位付け (企画部)`);
        if (stats.failedSchedules > 0) tasks.push(`Schedule 失敗 ${stats.failedSchedules} 件を修正 (開発部)`);
        tasks.push("SNS で進捗共有 — X に #buildinpublic 投稿 (CMO室)");
        tasks.push("競合動向チェック — 21社のアップデート確認 (企画部)");
        reply = `今日のおすすめタスク (${tasks.length} 件):\n` + tasks.map((t, i) => `${i + 1}. ${t}`).join("\n");
        department = "CEO室";
      }
      // ユーザー獲得
      else if (lowerMsg.includes("ユーザー") && (lowerMsg.includes("増") || lowerMsg.includes("獲得"))) {
        reply = `現在のユーザー数: ${stats.users} 人\n\nユーザー獲得の施策 (営業部・CMO室):\n` +
          "1. 技術ブログを毎日投稿 — Zenn, Qiita, note, はてな, Medium, dev.to (11プラットフォーム)\n" +
          "2. X で #buildinpublic タグで毎日進捗共有 (@kanta13jp1)\n" +
          "3. リファラルプログラムの活用 — 既存ユーザーに紹介を依頼\n" +
          "4. SEO 最適化 — メタタグ、サイトマップ (43 URL)\n" +
          "5. Product Hunt への掲載申請\n" +
          "6. ウェイトリスト通知 — 登録者への機能更新通知メール\n" +
          "7. 競合サービスからのインポート機能で乗り換えを促進";
        department = "CMO室";
      }
      // 競合分析
      else if (lowerMsg.includes("競合")) {
        reply = "競合分析 (企画部):\n" +
          "21社の競合に対し、AI統合が最大の差別化要因です。\n\n" +
          "【重点攻略先】\n" +
          "- Notion/Evernote: ノートインポート機能で乗り換え促進\n" +
          "- MoneyForward: 家計管理 + AI 分析で差別化\n" +
          "- Slack/Chatwork: AI エージェントによるチーム管理\n" +
          "- X: コンテンツ配信 + 自動投稿機能\n\n" +
          "【技術的優位性】\n" +
          "- 52 Edge Functions による豊富なバックエンド API\n" +
          "- 12部署20人の仮想AI組織による運営自動化\n" +
          "- Claude Code Schedule による完全自動化開発";
        department = "企画部";
      }
      // 部署・組織
      else if (lowerMsg.includes("部署") || lowerMsg.includes("組織") || lowerMsg.includes("エージェント")) {
        reply = "仮想AI組織 (CHRO室):\n" +
          "12部署20人体制で運営中。各部署の役割:\n\n" +
          "1. CEO室 — 全社戦略・意思決定\n" +
          "2. CFO室 — 財務・予算・経理\n" +
          "3. CMO室 — マーケティング・広告・宣伝\n" +
          "4. CHO室 — 健康・ウェルネス管理\n" +
          "5. CHRO室 — 人事・採用・組織開発\n" +
          "6. 企画部 — 企画立案・プロダクト管理\n" +
          "7. 開発部 — 技術開発・実装\n" +
          "8. 営業部 — 顧客獲得・営業活動\n" +
          "9. CS部 — カスタマーサポート\n" +
          "10. 法務部 — 法務・コンプライアンス\n" +
          "11. 広報部 — 広報・PR・ブログ\n" +
          "12. 調達部 — 調達・ベンダー管理\n\n" +
          "各部署のタスク状況は AI 組織 OS で確認できます。";
        department = "CHRO室";
      }
      // ブログ
      else if (lowerMsg.includes("ブログ") || lowerMsg.includes("記事")) {
        reply = `技術ブログ状況 (広報部):\n` +
          `今日の投稿数: ${stats.todayBlogs} 件\n\n` +
          "投稿先 (11プラットフォーム):\n" +
          "Zenn, Qiita, はてなブログ, note, Medium, dev.to, Hashnode, Substack, GitHub Pages, Notion, X Article\n\n" +
          "おすすめネタ:\n" +
          "1. 「Claude Code で 52 Edge Functions を自動生成した話」\n" +
          "2. 「12部署20人の仮想AI組織でプロダクト開発」\n" +
          "3. 「Flutter Web + Supabase で21競合を超えるアプリを作る」";
        department = "広報部";
      }
      // 事業計画
      else if (lowerMsg.includes("事業") || lowerMsg.includes("計画") || lowerMsg.includes("戦略")) {
        reply = "事業計画概要 (CEO室):\n\n" +
          "【短期 (〜2026/06)】ユーザー100人突破・MVP強化\n" +
          "【中期 (〜2027/03)】ユーザー10,000人・機能充実\n" +
          "【長期 (〜2028/12)】エンタープライズ対応・グローバル展開\n\n" +
          "全21競合を上回る機能を実装し、AI統合による差別化で\n" +
          "知的生産・資産管理・SNS統合プラットフォームのNo.1を目指します。";
        department = "CEO室";
      }
      // デフォルト
      else {
        reply = `承知しました。「${message}」について各部署に指示を出します。\n\n` +
          "関連する部署:\n" +
          "- 開発部: 技術的な実装・修正\n" +
          "- 企画部: 機能の企画・優先順位\n" +
          "- CS部: ユーザー対応\n\n" +
          "管理ダッシュボードで詳細な分析結果を確認できます。";
        department = "CEO室";
      }

      // 会話ログに回答も記録
      await adminClient.from("ai_secretary_logs").update({
        reply,
        context: { ...((context ?? {}) as Record<string, unknown>), department, stats },
      }).eq("user_id", user.id).order("created_at", { ascending: false }).limit(1);

      return new Response(
        JSON.stringify({
          success: true,
          reply,
          department,
          stats,
          timestamp: new Date().toISOString(),
        }),
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
