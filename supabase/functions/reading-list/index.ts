// Reading List Edge Function
// 読書管理 (Amazon/Evernote競合)
// - 書籍登録 (読みたい/読書中/読了)
// - メモ・ハイライト
// - 読書統計
//
// GET  → 書籍一覧 / 統計 / メモ
// POST → 書籍追加 / ステータス更新 / メモ追加

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
      const view = url.searchParams.get("view"); // 'stats' | 'notes' | 'list'
      const status = url.searchParams.get("status"); // 'want_to_read' | 'reading' | 'completed'
      const bookId = url.searchParams.get("book_id");

      if (view === "notes" && bookId) {
        const { data: notes } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "reading_note")
          .eq("metadata->>book_id", bookId)
          .order("created_at", { ascending: true });

        return new Response(
          JSON.stringify({
            success: true,
            notes: (notes ?? []).map((n) => ({
              ...(n.metadata as Record<string, unknown>),
              createdAt: n.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { data: books } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "reading_book")
        .order("created_at", { ascending: false });

      let bookList = (books ?? []).map((b) => ({
        ...(b.metadata as Record<string, unknown>),
        addedAt: b.created_at,
      }));

      if (status) {
        bookList = bookList.filter((b) => b.status === status);
      }

      if (view === "stats") {
        const completed = bookList.filter((b) => b.status === "completed").length;
        const reading = bookList.filter((b) => b.status === "reading").length;
        const wantToRead = bookList.filter((b) => b.status === "want_to_read").length;

        // Pages read
        let totalPages = 0;
        for (const b of bookList.filter((b) => b.status === "completed")) {
          totalPages += (b.pages as number) ?? 0;
        }

        return new Response(
          JSON.stringify({
            success: true,
            stats: { totalBooks: bookList.length, completed, reading, wantToRead, totalPages },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: true, books: bookList }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "add") {
        const { title, author, pages, genre, isbn } = body;
        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const bookId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "reading_book",
          metadata: {
            book_id: bookId,
            title,
            author: author ?? "",
            pages: pages ?? 0,
            genre: genre ?? "",
            isbn: isbn ?? "",
            status: "want_to_read",
            rating: null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, bookId, book: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_status") {
        const { book_id, status: newStatus, rating } = body;
        if (!book_id || !newStatus) {
          return new Response(
            JSON.stringify({ success: false, error: "book_id and status required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "reading_book")
          .eq("metadata->>book_id", book_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Book not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updatedMeta: Record<string, unknown> = {
          ...(existing.metadata as Record<string, unknown>),
          status: newStatus,
        };
        if (newStatus === "completed") {
          updatedMeta.completed_date = new Date().toISOString().slice(0, 10);
        }
        if (rating !== undefined) {
          updatedMeta.rating = rating;
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: updatedMeta })
          .eq("user_id", user.id)
          .eq("source", "reading_book")
          .eq("metadata->>book_id", book_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "add_note") {
        const { book_id, content, page, type } = body;
        if (!book_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "book_id and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "reading_note",
          metadata: {
            book_id,
            content,
            page: page ?? null,
            type: type ?? "note", // 'note' | 'highlight' | 'quote'
          },
          created_at: new Date().toISOString(),
        });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, added: true }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("reading-list error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
