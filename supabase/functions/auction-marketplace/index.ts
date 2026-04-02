// Auction & Marketplace Edge Function
// オークション・マーケットプレイス (Amazon/メルカリ競合)
// - 出品管理
// - 入札・即決
// - 取引メッセージ
// - 評価・レビュー
// - 売上統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const LISTING_CATEGORIES = [
  "electronics", "fashion", "books", "home", "sports",
  "toys", "automotive", "collectibles", "handmade", "other",
];

const CONDITION_TYPES = ["new", "like_new", "good", "fair", "poor"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const listingId = url.searchParams.get("listing_id");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: LISTING_CATEGORIES, conditions: CONDITION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "bids" && listingId) {
        const { data: bids } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "auction_bid").eq("metadata->>listing_id", listingId)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, bids: (bids ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "messages" && listingId) {
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "auction_message").eq("metadata->>listing_id", listingId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({ success: true, messages: (msgs ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "my_listings") {
        const { data: listings } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "auction_listing")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, listings: (listings ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "browse") {
        const category = url.searchParams.get("category");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "auction_listing").eq("metadata->>status", "active")
          .order("created_at", { ascending: false }).limit(50);
        if (category) query = query.eq("metadata->>category", category);
        const { data: listings } = await query;
        return new Response(JSON.stringify({ success: true, listings: (listings ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: myListings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "auction_listing");
        const sold = (myListings ?? []).filter((l) => (l.metadata as Record<string, unknown>).status === "sold");
        let totalRevenue = 0;
        for (const s of sold) totalRevenue += ((s.metadata as Record<string, unknown>).sold_price as number) ?? 0;
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "auction_review").eq("metadata->>seller_id", user.id);
        const avgRating = (reviews ?? []).length > 0
          ? (reviews ?? []).reduce((sum, r) => sum + (((r.metadata as Record<string, unknown>).rating as number) ?? 0), 0) / (reviews ?? []).length
          : 0;
        return new Response(JSON.stringify({
          success: true, stats: {
            totalListings: (myListings ?? []).length, soldCount: sold.length,
            totalRevenue, avgRating: Math.round(avgRating * 10) / 10,
            activeCount: (myListings ?? []).filter((l) => (l.metadata as Record<string, unknown>).status === "active").length,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: all active listings
      const { data: listings } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "auction_listing").eq("metadata->>status", "active")
        .order("created_at", { ascending: false }).limit(20);
      return new Response(JSON.stringify({ success: true, listings: (listings ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_listing") {
        const { title, description, category, condition, start_price, buy_now_price, auction_end } = body;
        if (!title || !start_price) return new Response(JSON.stringify({ success: false, error: "title and start_price required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const listingId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auction_listing",
          metadata: {
            listing_id: listingId, title, description: description ?? "",
            category: category ?? "other", condition: condition ?? "good",
            start_price, buy_now_price: buy_now_price ?? null, current_price: start_price,
            auction_end: auction_end ?? new Date(Date.now() + 7 * 86400000).toISOString(),
            status: "active", bid_count: 0, highest_bidder: null, sold_price: null,
            seller_id: user.id, seller_email: user.email,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, listingId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "place_bid") {
        const { listing_id, amount } = body;
        if (!listing_id || !amount) return new Response(JSON.stringify({ success: false, error: "listing_id and amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get current listing
        const { data: listing } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "auction_listing").eq("metadata->>listing_id", listing_id).eq("metadata->>status", "active").maybeSingle();
        if (!listing) return new Response(JSON.stringify({ success: false, error: "Listing not found or not active" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = listing.metadata as Record<string, unknown>;
        if (amount <= ((meta.current_price as number) ?? 0)) {
          return new Response(JSON.stringify({ success: false, error: "Bid must be higher than current price" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const bidId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auction_bid",
          metadata: { bid_id: bidId, listing_id, amount, bidder_id: user.id, bidder_email: user.email },
          created_at: new Date().toISOString(),
        });
        // Update listing current price
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, current_price: amount, highest_bidder: user.id, bid_count: ((meta.bid_count as number) ?? 0) + 1 },
        }).eq("source", "auction_listing").eq("metadata->>listing_id", listing_id);
        // Check buy_now_price
        if (meta.buy_now_price && amount >= (meta.buy_now_price as number)) {
          await adminClient.from("app_analytics").update({
            metadata: { ...meta, current_price: amount, highest_bidder: user.id, bid_count: ((meta.bid_count as number) ?? 0) + 1, status: "sold", sold_price: amount },
          }).eq("source", "auction_listing").eq("metadata->>listing_id", listing_id);
        }
        return new Response(JSON.stringify({ success: true, bidId, newPrice: amount }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "send_message") {
        const { listing_id, message } = body;
        if (!listing_id || !message) return new Response(JSON.stringify({ success: false, error: "listing_id and message required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const msgId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auction_message",
          metadata: { message_id: msgId, listing_id, sender_id: user.id, sender_email: user.email, message },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, messageId: msgId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "leave_review") {
        const { listing_id, seller_id, rating, comment } = body;
        if (!listing_id || !seller_id || !rating) return new Response(JSON.stringify({ success: false, error: "listing_id, seller_id, and rating required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const reviewId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auction_review",
          metadata: { review_id: reviewId, listing_id, seller_id, reviewer_id: user.id, rating: Math.min(5, Math.max(1, rating)), comment: comment ?? "" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, reviewId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
