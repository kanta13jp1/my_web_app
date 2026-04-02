// Invoice Generator Edge Function
// 請求書生成 (MoneyForward/freee競合)
// - 請求書作成・一覧
// - クライアント管理
// - ステータス管理 (下書き/送信済み/支払済み)
// - 月次売上集計
//
// GET  → 請求書一覧 / クライアント / 月次サマリー
// POST → 請求書作成 / ステータス更新

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
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'clients' | 'summary' | 'detail'
      const invoiceId = url.searchParams.get("invoice_id");
      const status = url.searchParams.get("status");

      if (view === "detail" && invoiceId) {
        const { data: invoice } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "invoice")
          .eq("metadata->>invoice_id", invoiceId)
          .maybeSingle();

        if (!invoice) {
          return new Response(
            JSON.stringify({ success: false, error: "Invoice not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        return new Response(
          JSON.stringify({ success: true, invoice: { ...(invoice.metadata as Record<string, unknown>), createdAt: invoice.created_at } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "clients") {
        const { data: invoices } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "invoice");

        const clients = new Map<string, { count: number; totalAmount: number }>();
        for (const inv of invoices ?? []) {
          const meta = inv.metadata as Record<string, unknown>;
          const client = (meta?.client_name as string) ?? "不明";
          const amount = (meta?.total_amount as number) ?? 0;
          const curr = clients.get(client) ?? { count: 0, totalAmount: 0 };
          curr.count++;
          curr.totalAmount += amount;
          clients.set(client, curr);
        }

        return new Response(
          JSON.stringify({
            success: true,
            clients: [...clients.entries()].map(([name, data]) => ({ name, ...data })).sort((a, b) => b.totalAmount - a.totalAmount),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "summary") {
        const yearParam = url.searchParams.get("year");
        const year = yearParam ? parseInt(yearParam) : new Date().getFullYear();
        const since = new Date(year, 0, 1).toISOString();
        const until = new Date(year + 1, 0, 1).toISOString();

        const { data: invoices } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "invoice")
          .gte("created_at", since)
          .lt("created_at", until);

        const monthlyRevenue: number[] = new Array(12).fill(0);
        let totalPaid = 0;
        let totalUnpaid = 0;

        for (const inv of invoices ?? []) {
          const meta = inv.metadata as Record<string, unknown>;
          const amount = (meta?.total_amount as number) ?? 0;
          const s = (meta?.status as string) ?? "draft";
          const m = new Date(inv.created_at).getMonth();
          monthlyRevenue[m] += amount;

          if (s === "paid") totalPaid += amount;
          else totalUnpaid += amount;
        }

        return new Response(
          JSON.stringify({
            success: true,
            year,
            monthlyRevenue,
            totalPaid: Math.round(totalPaid),
            totalUnpaid: Math.round(totalUnpaid),
            totalInvoices: (invoices ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default: invoice list
      let query = adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "invoice")
        .order("created_at", { ascending: false })
        .limit(50);

      if (status) {
        query = query.eq("metadata->>status", status);
      }

      const { data: invoices } = await query;

      return new Response(
        JSON.stringify({
          success: true,
          invoices: (invoices ?? []).map((i) => ({
            ...(i.metadata as Record<string, unknown>),
            createdAt: i.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { client_name, items, due_date, notes, tax_rate } = body;
        if (!client_name || !items || !Array.isArray(items) || items.length === 0) {
          return new Response(
            JSON.stringify({ success: false, error: "client_name and items[] required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const subtotal = items.reduce((s: number, item: { quantity: number; unit_price: number }) =>
          s + (item.quantity ?? 1) * (item.unit_price ?? 0), 0);
        const tax = Math.round(subtotal * ((tax_rate ?? 10) / 100));
        const totalAmount = subtotal + tax;

        const invoiceId = crypto.randomUUID();
        const invoiceNumber = `INV-${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, "0")}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "invoice",
          metadata: {
            invoice_id: invoiceId,
            invoice_number: invoiceNumber,
            client_name,
            items,
            subtotal,
            tax_rate: tax_rate ?? 10,
            tax,
            total_amount: totalAmount,
            status: "draft",
            due_date: due_date ?? null,
            notes: notes ?? "",
            issued_date: new Date().toISOString().slice(0, 10),
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, invoiceId, invoiceNumber, invoice: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_status") {
        const { invoice_id, status: newStatus } = body;
        if (!invoice_id || !newStatus) {
          return new Response(
            JSON.stringify({ success: false, error: "invoice_id and status required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const validStatuses = ["draft", "sent", "paid", "overdue", "cancelled"];
        if (!validStatuses.includes(newStatus)) {
          return new Response(
            JSON.stringify({ success: false, error: `status must be one of: ${validStatuses.join(", ")}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "invoice")
          .eq("metadata->>invoice_id", invoice_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Invoice not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updatedMeta = { ...(existing.metadata as Record<string, unknown>), status: newStatus };
        if (newStatus === "paid") {
          updatedMeta.paid_date = new Date().toISOString().slice(0, 10);
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: updatedMeta })
          .eq("user_id", user.id)
          .eq("source", "invoice")
          .eq("metadata->>invoice_id", invoice_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true, status: newStatus }),
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
    console.error("invoice-generator error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
