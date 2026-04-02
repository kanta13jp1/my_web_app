// Import From Competitors Edge Function
// 競合製品からのデータインポート
// - Notion (JSON/Markdown)
// - Evernote (ENEX/HTML)
// - MoneyForward (CSV)
// - Google Keep (JSON)
// - Apple Notes (HTML)
// - 汎用 Markdown/CSV/JSON
//
// GET  → インポート履歴 / サポート形式一覧
// POST → インポート実行 / プレビュー

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

// サポートするインポート形式
const IMPORT_FORMATS = [
  {
    key: "notion_json",
    label: "Notion (JSON/Markdown)",
    source: "notion",
    description: "NotionのエクスポートZIPからページをインポート。Settings > Workspace > Export Content > JSON形式で出力",
    fileTypes: [".json", ".md", ".zip"],
  },
  {
    key: "evernote_enex",
    label: "Evernote (ENEX)",
    source: "evernote",
    description: "EvernoteのENEXファイルからノートをインポート。Evernote > ノートブック右クリック > エクスポート > ENEX形式",
    fileTypes: [".enex"],
  },
  {
    key: "moneyforward_csv",
    label: "MoneyForward (CSV)",
    source: "moneyforward",
    description: "MoneyForwardの家計簿CSVをインポート。設定 > データ出力 > CSV出力",
    fileTypes: [".csv"],
  },
  {
    key: "google_keep_json",
    label: "Google Keep (JSON)",
    source: "google",
    description: "Google Takeoutからのメモデータ。takeout.google.com > Keep を選択 > エクスポート",
    fileTypes: [".json"],
  },
  {
    key: "markdown",
    label: "Markdown (汎用)",
    source: "generic",
    description: "汎用Markdownファイルをノートとしてインポート",
    fileTypes: [".md", ".markdown", ".txt"],
  },
  {
    key: "csv_generic",
    label: "CSV (汎用)",
    source: "generic",
    description: "title,content,tags のCSV形式をノートとしてインポート",
    fileTypes: [".csv"],
  },
  {
    key: "slack_export",
    label: "Slack (JSON)",
    source: "slack",
    description: "Slackワークスペースエクスポートからチャンネルメッセージをインポート。管理者 > エクスポート",
    fileTypes: [".json", ".zip"],
  },
  {
    key: "chatwork_csv",
    label: "Chatwork (CSV)",
    source: "chatwork",
    description: "Chatworkのチャットログをインポート。管理者 > メッセージエクスポート",
    fileTypes: [".csv"],
  },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'formats' | 'history' | 'guide'
      const source = url.searchParams.get("source");

      if (view === "formats") {
        const formats = source
          ? IMPORT_FORMATS.filter((f) => f.source === source)
          : [...IMPORT_FORMATS];

        return new Response(
          JSON.stringify({ success: true, formats, totalFormats: formats.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "guide") {
        // 特定ソースのインポートガイド
        if (!source) {
          return new Response(
            JSON.stringify({ success: false, error: "source parameter required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const format = IMPORT_FORMATS.find((f) => f.source === source);
        if (!format) {
          return new Response(
            JSON.stringify({ success: false, error: "Unsupported source" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const guides: Record<string, string[]> = {
          notion: [
            "1. Notion にログインし、Settings & Members を開く",
            "2. Workspace > Settings > Export Content をクリック",
            "3. 形式: Markdown & CSV を選択、Include subpages にチェック",
            "4. Export をクリックしてZIPをダウンロード",
            "5. このサイトの「インポート」ページでZIPをアップロード",
          ],
          evernote: [
            "1. Evernote デスクトップアプリを開く",
            "2. インポートしたいノートブックを右クリック",
            "3. 「ノートをエクスポート...」を選択",
            "4. 形式: ENEX (.enex) を選択して保存",
            "5. このサイトの「インポート」ページでENEXファイルをアップロード",
          ],
          moneyforward: [
            "1. MoneyForward ME にログイン",
            "2. 設定 > データ出力 を開く",
            "3. 出力期間を選択し、CSV出力 をクリック",
            "4. ダウンロードしたCSVファイルを保存",
            "5. このサイトの「インポート」ページでCSVをアップロード",
          ],
          google: [
            "1. takeout.google.com にアクセス",
            "2. 「選択をすべて解除」→「Keep」のみチェック",
            "3. 「次のステップ」→ エクスポートを作成",
            "4. ダウンロードしたZIPを展開",
            "5. このサイトの「インポート」ページでJSONファイルをアップロード",
          ],
          slack: [
            "1. Slack ワークスペースの管理画面を開く",
            "2. 設定と管理 > ワークスペースの設定 > データのインポート/エクスポート",
            "3. 「エクスポート」タブを選択",
            "4. 期間を選択して「エクスポートを開始する」",
            "5. ダウンロードしたZIPをこのサイトの「インポート」ページでアップロード",
          ],
          chatwork: [
            "1. Chatwork 管理者アカウントでログイン",
            "2. 管理者設定 > エクスポート",
            "3. 対象チャットルームと期間を選択",
            "4. CSV形式でエクスポート",
            "5. このサイトの「インポート」ページでCSVをアップロード",
          ],
          generic: [
            "1. テキストファイル (.md, .txt) またはCSV (.csv) を用意",
            "2. CSVの場合: title, content, tags の列ヘッダーを含める",
            "3. このサイトの「インポート」ページでファイルをアップロード",
          ],
        };

        return new Response(
          JSON.stringify({
            success: true,
            source,
            format: format.label,
            description: format.description,
            steps: guides[source] ?? guides.generic,
            fileTypes: format.fileTypes,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: インポート履歴
      const authHeader = req.headers.get("Authorization");
      let userId = null;
      if (authHeader) {
        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) userId = user.id;
      }

      let query = adminClient
        .from("app_analytics")
        .select("metadata, created_at, user_id")
        .eq("source", "import")
        .order("created_at", { ascending: false })
        .limit(50);

      if (userId) query = query.eq("user_id", userId);

      const { data: history } = await query;

      return new Response(
        JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({
            ...(h.metadata as Record<string, unknown>),
            importedAt: h.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

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

      if (action === "import") {
        // ノートデータのインポート
        const { format, notes } = body;

        if (!format || !notes || !Array.isArray(notes)) {
          return new Response(
            JSON.stringify({ success: false, error: "format and notes array are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // ノート挿入
        const insertData = notes.map((n: { title?: string; content?: string; tags?: string[] }) => ({
          user_id: user.id,
          title: n.title ?? "Imported Note",
          content: n.content ?? "",
          tags: n.tags ?? [],
          source: format,
          created_at: new Date().toISOString(),
        }));

        const { data: imported, error } = await adminClient
          .from("notes")
          .insert(insertData)
          .select("id");

        if (error) throw error;

        // インポートログ
        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "import",
          metadata: {
            format,
            count: (imported ?? []).length,
            importedAt: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, imported: (imported ?? []).length }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "preview") {
        // インポートプレビュー (実際にはDBに書き込まない)
        const { format, notes } = body;

        if (!notes || !Array.isArray(notes)) {
          return new Response(
            JSON.stringify({ success: false, error: "notes array required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        return new Response(
          JSON.stringify({
            success: true,
            preview: {
              format: format ?? "unknown",
              totalNotes: notes.length,
              sample: notes.slice(0, 5).map((n: { title?: string; content?: string }) => ({
                title: n.title ?? "Untitled",
                contentLength: (n.content ?? "").length,
              })),
            },
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
    console.error("import-from-competitors error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
