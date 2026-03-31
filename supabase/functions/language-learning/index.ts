// Language Learning Edge Function
// 語学学習 (Duolingo競合)
// - 単語帳管理
// - フラッシュカード (間隔反復)
// - クイズ・テスト
// - 学習ストリーク
// - 進捗統計
//
// GET  → 単語帳一覧 / カード / クイズ / ストリーク / 統計
// POST → 単語帳作成 / カード追加 / 回答記録 / ストリーク更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const LANGUAGES = ["en", "ja", "zh", "ko", "fr", "de", "es", "pt", "it", "ru", "ar", "hi"];

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
      const deckId = url.searchParams.get("deck_id");

      if (view === "languages") {
        return new Response(JSON.stringify({ success: true, languages: LANGUAGES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "cards" && deckId) {
        const { data: cards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "vocab_card").eq("metadata->>deck_id", deckId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          cards: (cards ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "review" && deckId) {
        // Get cards due for review (spaced repetition)
        const now = new Date().toISOString();
        const { data: cards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "vocab_card").eq("metadata->>deck_id", deckId);
        const dueCards = (cards ?? []).filter((c) => {
          const meta = c.metadata as Record<string, unknown>;
          const nextReview = meta.next_review as string | undefined;
          return !nextReview || nextReview <= now;
        }).slice(0, 20);
        return new Response(JSON.stringify({
          success: true,
          dueCards: dueCards.map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
          totalDue: dueCards.length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "streak") {
        const { data: streakData } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_streak").maybeSingle();
        const streak = streakData ? (streakData.metadata as Record<string, unknown>) : { current: 0, longest: 0, last_date: null };
        return new Response(JSON.stringify({ success: true, streak }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: decks } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_deck");
        const { data: cards } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_card");
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_review");
        let correct = 0;
        for (const r of reviews ?? []) {
          if ((r.metadata as Record<string, unknown>).correct) correct++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalDecks: (decks ?? []).length, totalCards: (cards ?? []).length, totalReviews: (reviews ?? []).length, correctRate: (reviews ?? []).length > 0 ? Math.round(correct / (reviews ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: deck list
      const { data: decks } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "vocab_deck")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        decks: (decks ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_deck") {
        const { title, language_from, language_to, description } = body;
        if (!title || !language_from || !language_to) {
          return new Response(JSON.stringify({ success: false, error: "title, language_from, language_to required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const deckId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vocab_deck",
          metadata: { deck_id: deckId, title, language_from, language_to, description: description ?? null, card_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, deckId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_card") {
        const { deck_id, front, back, example, pronunciation } = body;
        if (!deck_id || !front || !back) {
          return new Response(JSON.stringify({ success: false, error: "deck_id, front, back required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const cardId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vocab_card",
          metadata: { card_id: cardId, deck_id, front, back, example: example ?? null, pronunciation: pronunciation ?? null, interval_days: 1, ease_factor: 2.5, next_review: new Date().toISOString(), review_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, cardId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "review_card") {
        const { card_id, correct, quality } = body;
        if (!card_id || correct === undefined) {
          return new Response(JSON.stringify({ success: false, error: "card_id and correct required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Record review
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vocab_review",
          metadata: { card_id, correct, quality: quality ?? (correct ? 4 : 1) },
          created_at: new Date().toISOString(),
        });
        // Update card with SM-2 algorithm
        const { data: card } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_card").eq("metadata->>card_id", card_id).maybeSingle();
        if (card) {
          const meta = card.metadata as Record<string, unknown>;
          let interval = (meta.interval_days as number) ?? 1;
          let ease = (meta.ease_factor as number) ?? 2.5;
          const q = quality ?? (correct ? 4 : 1);
          if (correct) {
            if (interval === 1) interval = 6;
            else interval = Math.round(interval * ease);
            ease = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
            if (ease < 1.3) ease = 1.3;
          } else {
            interval = 1;
          }
          const nextReview = new Date(Date.now() + interval * 86400000).toISOString();
          await adminClient.from("app_analytics").update({
            metadata: { ...meta, interval_days: interval, ease_factor: Math.round(ease * 100) / 100, next_review: nextReview, review_count: ((meta.review_count as number) ?? 0) + 1 },
          }).eq("user_id", user.id).eq("source", "vocab_card").eq("metadata->>card_id", card_id);
        }
        // Update streak
        const today = new Date().toISOString().substring(0, 10);
        const { data: streakData } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vocab_streak").maybeSingle();
        if (streakData) {
          const sm = streakData.metadata as Record<string, unknown>;
          const lastDate = sm.last_date as string | null;
          const yesterday = new Date(Date.now() - 86400000).toISOString().substring(0, 10);
          let current = (sm.current as number) ?? 0;
          if (lastDate === today) { /* already counted */ }
          else if (lastDate === yesterday) current++;
          else current = 1;
          const longest = Math.max(current, (sm.longest as number) ?? 0);
          await adminClient.from("app_analytics").update({ metadata: { current, longest, last_date: today } })
            .eq("user_id", user.id).eq("source", "vocab_streak");
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "vocab_streak",
            metadata: { current: 1, longest: 1, last_date: today },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, reviewed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
