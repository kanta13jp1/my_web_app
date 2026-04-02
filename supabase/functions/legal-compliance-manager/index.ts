// Legal Compliance Manager Edge Function
// 法務・コンプライアンス管理 (Microsoft/Google/エンタープライズ競合)
// - 契約テンプレート管理
// - コンプライアンスチェックリスト
// - 個人情報保護法/GDPR同意管理
// - 契約ステータス追跡
//
// GET  → テンプレート / チェックリスト / 契約一覧 / 同意管理
// POST → 契約作成 / チェック完了 / 同意記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CONTRACT_TEMPLATES = [
  { key: "nda", name: "秘密保持契約 (NDA)", category: "基本" },
  { key: "service", name: "業務委託契約", category: "取引" },
  { key: "employment", name: "雇用契約", category: "人事" },
  { key: "license", name: "ライセンス契約", category: "知財" },
  { key: "terms", name: "利用規約", category: "サービス" },
  { key: "privacy", name: "プライバシーポリシー", category: "コンプライアンス" },
  { key: "partnership", name: "パートナーシップ契約", category: "取引" },
  { key: "saas", name: "SaaS利用契約", category: "サービス" },
];

const COMPLIANCE_CHECKLISTS = [
  { key: "gdpr", name: "GDPR対応", items: ["データ処理同意", "データポータビリティ", "忘れられる権利", "DPO設置", "データ影響評価"] },
  { key: "pipa", name: "個人情報保護法", items: ["利用目的の特定", "安全管理措置", "第三者提供制限", "開示請求対応", "漏洩報告体制"] },
  { key: "security", name: "情報セキュリティ", items: ["アクセス制御", "暗号化", "ログ管理", "脆弱性対応", "インシデント対応"] },
  { key: "sox", name: "内部統制(SOX法)", items: ["承認ワークフロー", "職務分離", "監査証跡", "定期レビュー", "リスク評価"] },
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

      if (view === "templates") {
        return new Response(JSON.stringify({ success: true, templates: CONTRACT_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "checklists") {
        // Get user completion status
        const { data: completions } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "compliance_check");
        const completionMap = new Map<string, string[]>();
        for (const c of completions ?? []) {
          const meta = c.metadata as Record<string, unknown>;
          const key = meta.checklist_key as string;
          const items = (meta.completed_items as string[]) ?? [];
          completionMap.set(key, items);
        }
        return new Response(JSON.stringify({
          success: true,
          checklists: COMPLIANCE_CHECKLISTS.map((cl) => ({
            ...cl,
            completedItems: completionMap.get(cl.key) ?? [],
            progress: Math.round(((completionMap.get(cl.key) ?? []).length / cl.items.length) * 100),
          })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "contracts") {
        const status = url.searchParams.get("status");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "contract")
          .order("created_at", { ascending: false });
        if (status) query = query.eq("metadata->>status", status);
        const { data: contracts } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          contracts: (contracts ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "consents") {
        const { data: consents } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "consent_record")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          consents: (consents ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), recordedAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, views: ["templates", "checklists", "contracts", "consents"] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_contract") {
        const { template_key, title, counterparty, start_date, end_date, content } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const contractId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "contract",
          metadata: {
            contract_id: contractId, template_key: template_key ?? null, title,
            counterparty: counterparty ?? null, start_date: start_date ?? null,
            end_date: end_date ?? null, content: content ?? null,
            status: "draft", signatures: [],
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, contractId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete_check") {
        const { checklist_key, item } = body;
        if (!checklist_key || !item) {
          return new Response(JSON.stringify({ success: false, error: "checklist_key and item required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "compliance_check").eq("metadata->>checklist_key", checklist_key).maybeSingle();
        if (existing) {
          const meta = existing.metadata as Record<string, unknown>;
          const items = (meta.completed_items as string[]) ?? [];
          if (!items.includes(item)) items.push(item);
          await adminClient.from("app_analytics").update({
            metadata: { ...meta, completed_items: items },
          }).eq("user_id", user.id).eq("source", "compliance_check").eq("metadata->>checklist_key", checklist_key);
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "compliance_check",
            metadata: { checklist_key, completed_items: [item] },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, completed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_consent") {
        const { subject, purpose, consent_given, data_types } = body;
        if (!subject || !purpose) {
          return new Response(JSON.stringify({ success: false, error: "subject and purpose required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const consentId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "consent_record",
          metadata: { consent_id: consentId, subject, purpose, consent_given: consent_given ?? true, data_types: data_types ?? [], recorded_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, consentId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
