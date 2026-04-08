import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authorizeAutomationActor } from "../_shared/automation-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

// -----------------------------------------------------------------------
// get-support-tickets
//
// Returns open feature requests that have NOT yet received an admin reply.
// Called by Claude Code Schedule (cs-check task) every hour to determine
// which tickets need a response.
//
// Auth: Bearer SERVICE_ROLE_KEY
// -----------------------------------------------------------------------

const FAQ: Array<{ q: string; a: string }> = [
  {
    q: "Notionからインポートする方法",
    a: "Notion のワークスペース設定 → 設定とメンバー → 設定 → コンテンツのエクスポート → 「すべてのワークスペースコンテンツ」を選択し「Markdown & CSV」形式でエクスポートしてください。ZIPを展開後、自分株式会社のインポート画面からMarkdownファイルをアップロードできます。",
  },
  {
    q: "Evernoteからインポートする方法",
    a: "Evernote でノートを選択 → ファイル → ノートのエクスポート → ENEX形式で保存し、自分株式会社のインポート画面からアップロードしてください。",
  },
  {
    q: "パスワードを忘れた / ログインできない",
    a: "ログイン画面の「パスワードを忘れた場合」からメールアドレスを入力すると、パスワード再設定メールが届きます。",
  },
  {
    q: "プロフィールを変更したい",
    a: "右上のアイコン → プロフィール設定 から表示名・自己紹介・アイコン画像を変更できます。",
  },
  {
    q: "データを削除したい / 退会したい",
    a: "アカウント削除は現在サポートへのお問い合わせが必要です。削除希望の旨をご連絡ください。対応いたします。",
  },
  {
    q: "AIタスク提案が表示されない",
    a: "ホーム画面を下に引っ張って更新するか、一度ログアウトして再ログインをお試しください。それでも解決しない場合はバグとして調査します。",
  },
  {
    q: "競合アプリとの違いを教えてほしい",
    a: "Notion・Evernote・MoneyForward・Slack・Amazon・Google・Microsoft・Discord・LINE・Facebook など21の競合SaaSの機能を1つに統合したAI統合プラットフォームです。https://my-web-app-b67f4.web.app/vs-notion などの比較ページもご覧ください。",
  },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET" && req.method !== "POST") {
      throw new Error("Method not allowed. Use GET or POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await authorizeAutomationActor(admin, req);

    // Open tickets with no admin reply yet
    const { data: tickets, error } = await admin
      .from("feature_requests")
      .select(
        "id, title, description, email, votes, status, created_at, admin_reply",
      )
      .eq("status", "open")
      .is("admin_replied_at", null)
      .order("votes", { ascending: false })
      .limit(20);

    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        tickets: tickets ?? [],
        faq: FAQ,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
