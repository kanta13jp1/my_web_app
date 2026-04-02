// OCR Document Scanner Edge Function
// OCR文書スキャン (Evernote/MoneyForward/Google競合)
// - 画像・PDFからテキスト抽出
// - レシートスキャン → 経費登録
// - 名刺スキャン → 連絡先登録
// - スキャン履歴管理
//
// GET  → スキャン履歴 / 詳細
// POST → スキャン登録 / 経費変換 / 連絡先変換

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SCAN_TYPES = [
  { key: "receipt", name: "レシート", icon: "🧾", description: "レシート → 経費自動登録" },
  { key: "business_card", name: "名刺", icon: "💳", description: "名刺 → 連絡先自動登録" },
  { key: "document", name: "ドキュメント", icon: "📄", description: "文書テキスト抽出" },
  { key: "handwriting", name: "手書き", icon: "✍️", description: "手書きメモのデジタル化" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const scanId = url.searchParams.get("scan_id");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, types: SCAN_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "detail" && scanId) {
        const { data: scan } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scanId).maybeSingle();
        if (!scan) {
          return new Response(JSON.stringify({ success: false, error: "Scan not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({ success: true, scan: { ...(scan.metadata as Record<string, unknown>), createdAt: scan.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: history
      const scanType = url.searchParams.get("type");
      let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "ocr_scan").order("created_at", { ascending: false });
      if (scanType) {
        query = query.eq("metadata->>scan_type", scanType);
      }
      const { data: scans } = await query.limit(50);

      return new Response(JSON.stringify({
        success: true,
        scans: (scans ?? []).map((s) => {
          const meta = s.metadata as Record<string, unknown>;
          return {
            scan_id: meta.scan_id,
            scan_type: meta.scan_type,
            title: meta.title,
            status: meta.status,
            extracted_text_preview: ((meta.extracted_text as string) ?? "").slice(0, 100),
            createdAt: s.created_at,
          };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "scan") {
        const { scan_type, title, file_url, extracted_text } = body;
        if (!scan_type) {
          return new Response(JSON.stringify({ success: false, error: "scan_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const valid = SCAN_TYPES.find((t) => t.key === scan_type);
        if (!valid) {
          return new Response(JSON.stringify({ success: false, error: "Invalid scan_type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const scanId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ocr_scan",
          metadata: {
            scan_id: scanId,
            scan_type,
            title: title ?? `${valid.name}スキャン`,
            file_url: file_url ?? null,
            extracted_text: extracted_text ?? null,
            status: extracted_text ? "completed" : "pending",
            converted_to: null,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, scanId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete_ocr") {
        const { scan_id, extracted_text } = body;
        if (!scan_id || !extracted_text) {
          return new Response(JSON.stringify({ success: false, error: "scan_id and extracted_text required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Scan not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").update({
          metadata: { ...(existing.metadata as Record<string, unknown>), extracted_text, status: "completed" },
        }).eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id);

        return new Response(JSON.stringify({ success: true, completed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "convert_to_expense") {
        const { scan_id, amount, category, description } = body;
        if (!scan_id) {
          return new Response(JSON.stringify({ success: false, error: "scan_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: scan } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id).maybeSingle();
        if (!scan) {
          return new Response(JSON.stringify({ success: false, error: "Scan not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const scanMeta = scan.metadata as Record<string, unknown>;

        // Create expense entry via app_analytics
        const expenseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "expense",
          metadata: {
            expense_id: expenseId,
            type: "expense",
            amount: amount ?? 0,
            category: category ?? "その他",
            description: description ?? scanMeta.title,
            from_scan: scan_id,
          },
          created_at: new Date().toISOString(),
        });

        // Update scan
        await adminClient.from("app_analytics").update({
          metadata: { ...scanMeta, converted_to: `expense:${expenseId}` },
        }).eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id);

        return new Response(JSON.stringify({ success: true, expenseId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "convert_to_contact") {
        const { scan_id, name, email, phone, company } = body;
        if (!scan_id) {
          return new Response(JSON.stringify({ success: false, error: "scan_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: scan } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id).maybeSingle();
        if (!scan) {
          return new Response(JSON.stringify({ success: false, error: "Scan not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const scanMeta = scan.metadata as Record<string, unknown>;
        const contactId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "contact",
          metadata: {
            contact_id: contactId,
            name: name ?? "Unknown",
            email: email ?? null,
            phone: phone ?? null,
            company: company ?? null,
            from_scan: scan_id,
          },
          created_at: new Date().toISOString(),
        });

        await adminClient.from("app_analytics").update({
          metadata: { ...scanMeta, converted_to: `contact:${contactId}` },
        }).eq("user_id", user.id).eq("source", "ocr_scan").eq("metadata->>scan_id", scan_id);

        return new Response(JSON.stringify({ success: true, contactId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
