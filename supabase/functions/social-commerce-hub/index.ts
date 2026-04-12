// social-commerce-hub — ソーシャル・EC・コマース統合EF
// Merges (26 EFs): social-feed, social-stories, social-media-scheduler,
//   social-proof-generator, marketplace, marketplace-reviews, auction-marketplace,
//   donation-crowdfunding, gift-registry, loyalty-points, digital-wallet,
//   payment-processor, financial-report, budget-financial-planner, invoice-generator,
//   affiliate-marketing, order-tracker, event-ticketing, appointment-scheduler,
//   customer-feedback, elearning-course-manager, language-learning,
//   horse-racing-predictor, real-estate-tracker, inventory-manager, inventory-barcode
//
// GET/POST ?action=<action> or body { action: "..." }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ?? "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Social Feed ──────────────────────────────────────────────────────────
      case "feed.timeline": return json({ success: true, posts: await listItems(admin, "social_post", userId) });
      case "feed.post": {
        const item = await addItem(admin, "social_post", userId, {
          content: body.content, images: body.images ?? [], hashtags: body.hashtags ?? [],
          visibility: body.visibility ?? "public", likes: 0, comments: 0,
        });
        return json({ success: true, post: item });
      }
      case "feed.like": {
        const item = await addItem(admin, "social_like", userId, {
          post_id: body.post_id, created_at: new Date().toISOString(),
        });
        return json({ success: true, like: item });
      }
      case "feed.follow": {
        const item = await addItem(admin, "social_follow", userId, {
          followee_id: body.followee_id, created_at: new Date().toISOString(),
        });
        return json({ success: true, follow: item });
      }
      case "feed.delete": {
        await deleteItem(admin, "social_post", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Social Stories ───────────────────────────────────────────────────────
      case "story.list": return json({ success: true, stories: await listItems(admin, "social_story", userId, 20) });
      case "story.create": {
        const expiresAt = new Date(Date.now() + 24 * 3600000).toISOString();
        const item = await addItem(admin, "social_story", userId, {
          media_url: body.media_url, type: body.type ?? "image",
          text: body.text, expires_at: expiresAt,
        });
        return json({ success: true, story: item });
      }

      // ── Social Media Scheduler ───────────────────────────────────────────────
      case "schedule.list": return json({ success: true, posts: await listItems(admin, "scheduled_post", userId) });
      case "schedule.create": {
        const item = await addItem(admin, "scheduled_post", userId, {
          content: body.content, platforms: body.platforms ?? ["x"],
          scheduled_at: body.scheduled_at, status: "pending",
        });
        return json({ success: true, post: item });
      }
      case "schedule.cancel": {
        await deleteItem(admin, "scheduled_post", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Social Proof Generator ───────────────────────────────────────────────
      case "social_proof.generate": {
        const { data } = await admin.from("hub_data")
          .select("metadata->user_id, created_at")
          .eq("source", "social_post")
          .order("created_at", { ascending: false })
          .limit(10);
        const count = data?.length ?? 0;
        return json({ success: true, message: `${count}人のユーザーが最近投稿しました`, count });
      }

      // ── Marketplace ──────────────────────────────────────────────────────────
      case "market.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "marketplace_item")
          .filter("metadata->>status", "eq", "active")
          .order("created_at", { ascending: false }).limit(50);
        return json({ success: true, items: data ?? [] });
      }
      case "market.list_mine": return json({ success: true, items: await listItems(admin, "marketplace_item", userId) });
      case "market.create": {
        const item = await addItem(admin, "marketplace_item", userId, {
          title: body.title, description: body.description, price: body.price,
          currency: body.currency ?? "JPY", category: body.category,
          images: body.images ?? [], status: "active",
        });
        return json({ success: true, item });
      }
      case "market.review": {
        const item = await addItem(admin, "marketplace_review", userId, {
          item_id: body.item_id, rating: body.rating, comment: body.comment,
        });
        return json({ success: true, review: item });
      }
      case "market.delete": {
        await deleteItem(admin, "marketplace_item", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Auction ───────────────────────────────────────────────────────────────
      case "auction.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "auction_item")
          .filter("metadata->>status", "eq", "active")
          .order("created_at", { ascending: false }).limit(20);
        return json({ success: true, auctions: data ?? [] });
      }
      case "auction.create": {
        const item = await addItem(admin, "auction_item", userId, {
          title: body.title, start_price: body.start_price, current_bid: body.start_price,
          ends_at: body.ends_at, status: "active",
        });
        return json({ success: true, auction: item });
      }
      case "auction.bid": {
        const item = await addItem(admin, "auction_bid", userId, {
          auction_id: body.auction_id, amount: body.amount, bid_at: new Date().toISOString(),
        });
        return json({ success: true, bid: item });
      }

      // ── Crowdfunding ──────────────────────────────────────────────────────────
      case "crowdfund.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "crowdfund_campaign")
          .order("created_at", { ascending: false }).limit(20);
        return json({ success: true, campaigns: data ?? [] });
      }
      case "crowdfund.create": {
        const item = await addItem(admin, "crowdfund_campaign", userId, {
          title: body.title, description: body.description, goal: body.goal,
          current: 0, currency: body.currency ?? "JPY", ends_at: body.ends_at,
        });
        return json({ success: true, campaign: item });
      }
      case "crowdfund.donate": {
        const item = await addItem(admin, "crowdfund_donation", userId, {
          campaign_id: body.campaign_id, amount: body.amount, message: body.message,
        });
        return json({ success: true, donation: item });
      }

      // ── Gift Registry ──────────────────────────────────────────────────────────
      case "gift.list": return json({ success: true, items: await listItems(admin, "gift_item", userId) });
      case "gift.add": {
        const item = await addItem(admin, "gift_item", userId, {
          name: body.name, url: body.url, price: body.price, priority: body.priority ?? "medium",
          purchased: false,
        });
        return json({ success: true, item });
      }
      case "gift.mark_purchased": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, purchased: true, purchased_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "gift_item");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Loyalty Points ────────────────────────────────────────────────────────
      case "loyalty.balance": {
        const points = await listItems(admin, "loyalty_point", userId, 500);
        const total = points.reduce((sum, p) => sum + Number((p.metadata as Record<string, unknown>)?.amount ?? 0), 0);
        return json({ success: true, balance: total, history: points.slice(0, 20) });
      }
      case "loyalty.earn": {
        const item = await addItem(admin, "loyalty_point", userId, {
          amount: body.amount, reason: body.reason, earned_at: new Date().toISOString(),
        });
        return json({ success: true, point: item });
      }
      case "loyalty.redeem": {
        const item = await addItem(admin, "loyalty_point", userId, {
          amount: -(Number(body.amount ?? 0)), reason: body.reason ?? "redeem",
          redeemed_at: new Date().toISOString(),
        });
        return json({ success: true, redeemed: item });
      }

      // ── Digital Wallet ────────────────────────────────────────────────────────
      case "wallet.balance": {
        const txns = await listItems(admin, "wallet_txn", userId, 500);
        const balance = txns.reduce((sum, t) => sum + Number((t.metadata as Record<string, unknown>)?.amount ?? 0), 0);
        return json({ success: true, balance, currency: "JPY", transactions: txns.slice(0, 20) });
      }
      case "wallet.deposit": {
        const item = await addItem(admin, "wallet_txn", userId, {
          amount: Number(body.amount ?? 0), type: "deposit", method: body.method, currency: "JPY",
        });
        return json({ success: true, transaction: item });
      }
      case "wallet.pay": {
        const item = await addItem(admin, "wallet_txn", userId, {
          amount: -(Number(body.amount ?? 0)), type: "payment", to: body.to, currency: "JPY",
        });
        return json({ success: true, transaction: item });
      }

      // ── Payment Processor ─────────────────────────────────────────────────────
      case "payment.record": {
        const item = await addItem(admin, "payment", userId, {
          amount: body.amount, currency: body.currency ?? "JPY", method: body.method ?? "card",
          status: body.status ?? "completed", reference: body.reference, description: body.description,
        });
        return json({ success: true, payment: item });
      }
      case "payment.history": return json({ success: true, payments: await listItems(admin, "payment", userId) });
      case "payment.report": {
        const payments = await listItems(admin, "payment", userId, 500);
        const total = payments.reduce((sum, p) => sum + Number((p.metadata as Record<string, unknown>)?.amount ?? 0), 0);
        return json({ success: true, total, count: payments.length, currency: "JPY" });
      }

      // ── Financial Report ──────────────────────────────────────────────────────
      case "finance.report": {
        const income = await listItems(admin, "income_entry", userId, 500);
        const expenses = await listItems(admin, "expense_entry", userId, 500);
        const totalIncome = income.reduce((s, i) => s + Number((i.metadata as Record<string, unknown>)?.amount ?? 0), 0);
        const totalExpense = expenses.reduce((s, e) => s + Number((e.metadata as Record<string, unknown>)?.amount ?? 0), 0);
        return json({ success: true, income: totalIncome, expenses: totalExpense, net: totalIncome - totalExpense });
      }
      case "budget.set": {
        const item = await addItem(admin, "budget_entry", userId, {
          category: body.category, amount: body.amount, period: body.period ?? "monthly",
        });
        return json({ success: true, budget: item });
      }
      case "budget.list": return json({ success: true, budgets: await listItems(admin, "budget_entry", userId) });

      // ── Invoice Generator ─────────────────────────────────────────────────────
      case "invoice.create": {
        const invoiceNum = `INV-${Date.now().toString().slice(-8)}`;
        const item = await addItem(admin, "invoice", userId, {
          number: invoiceNum, client: body.client, items: body.items ?? [],
          total: body.total, due_date: body.due_date, status: "draft",
        });
        return json({ success: true, invoice: item, number: invoiceNum });
      }
      case "invoice.list": return json({ success: true, invoices: await listItems(admin, "invoice", userId) });
      case "invoice.mark_paid": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "paid", paid_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "invoice");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Affiliate Marketing ────────────────────────────────────────────────────
      case "affiliate.list_links": return json({ success: true, links: await listItems(admin, "affiliate_link", userId) });
      case "affiliate.create_link": {
        const code = crypto.randomUUID().slice(0, 8);
        const item = await addItem(admin, "affiliate_link", userId, {
          code, url: body.url, title: body.title, commission_pct: body.commission_pct ?? 10,
          clicks: 0, conversions: 0,
        });
        return json({ success: true, link: item, code });
      }
      case "affiliate.record_click": {
        const item = await addItem(admin, "affiliate_event", userId, {
          code: body.code, type: "click", ip: req.headers.get("x-forwarded-for") ?? "unknown",
        });
        return json({ success: true, event: item });
      }

      // ── Order Tracker ─────────────────────────────────────────────────────────
      case "order.list": return json({ success: true, orders: await listItems(admin, "order", userId) });
      case "order.create": {
        const orderId = `ORD-${Date.now().toString().slice(-8)}`;
        const item = await addItem(admin, "order", userId, {
          order_id: orderId, items: body.items ?? [], total: body.total,
          status: "pending", shipping_address: body.shipping_address,
        });
        return json({ success: true, order: item, order_id: orderId });
      }
      case "order.update_status": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: body.status, updated_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "order");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Event Ticketing ───────────────────────────────────────────────────────
      case "event.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "event")
          .order("created_at", { ascending: false }).limit(20);
        return json({ success: true, events: data ?? [] });
      }
      case "event.create": {
        const item = await addItem(admin, "event", userId, {
          title: body.title, date: body.date, venue: body.venue,
          capacity: body.capacity, ticket_price: body.ticket_price, sold: 0,
        });
        return json({ success: true, event: item });
      }
      case "event.buy_ticket": {
        const ticket = await addItem(admin, "ticket", userId, {
          event_id: body.event_id, quantity: body.quantity ?? 1, total: body.total,
          ticket_code: crypto.randomUUID().slice(0, 10).toUpperCase(),
        });
        return json({ success: true, ticket });
      }

      // ── Appointment Scheduler ─────────────────────────────────────────────────
      case "appointment.list": return json({ success: true, appointments: await listItems(admin, "appointment", userId) });
      case "appointment.book": {
        const item = await addItem(admin, "appointment", userId, {
          title: body.title, date: body.date, time: body.time,
          provider_id: body.provider_id, notes: body.notes, status: "confirmed",
        });
        return json({ success: true, appointment: item });
      }
      case "appointment.cancel": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "cancelled", cancelled_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "appointment");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Customer Feedback ─────────────────────────────────────────────────────
      case "feedback.list": return json({ success: true, feedbacks: await listItems(admin, "customer_feedback", userId) });
      case "feedback.submit": {
        const item = await addItem(admin, "customer_feedback", userId, {
          type: body.type ?? "general", rating: body.rating, comment: body.comment,
          feature: body.feature, status: "open",
        });
        return json({ success: true, feedback: item });
      }

      // ── E-Learning ────────────────────────────────────────────────────────────
      case "course.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "course")
          .order("created_at", { ascending: false }).limit(20);
        return json({ success: true, courses: data ?? [] });
      }
      case "course.create": {
        const item = await addItem(admin, "course", userId, {
          title: body.title, description: body.description, modules: body.modules ?? [],
          level: body.level ?? "beginner", language: body.language ?? "ja",
        });
        return json({ success: true, course: item });
      }
      case "course.enroll": {
        const item = await addItem(admin, "enrollment", userId, {
          course_id: body.course_id, enrolled_at: new Date().toISOString(), progress: 0,
        });
        return json({ success: true, enrollment: item });
      }
      case "course.progress": {
        const enrollments = await listItems(admin, "enrollment", userId);
        return json({ success: true, enrollments });
      }

      // ── Language Learning ─────────────────────────────────────────────────────
      case "lang.list_cards": return json({ success: true, cards: await listItems(admin, "flashcard", userId) });
      case "lang.add_card": {
        const item = await addItem(admin, "flashcard", userId, {
          front: body.front, back: body.back, language: body.language ?? "en",
          deck: body.deck ?? "default", ease_factor: 2.5, next_review: new Date().toISOString(),
        });
        return json({ success: true, card: item });
      }
      case "lang.review_card": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, last_reviewed: new Date().toISOString(), result: body.result } })
          .eq("id", String(body.id ?? "")).eq("source", "flashcard");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Horse Racing ──────────────────────────────────────────────────────────
      case "racing.list_races": return json({ success: true, races: await listItems(admin, "race_analysis", userId, 20) });
      case "racing.analyze": {
        const item = await addItem(admin, "race_analysis", userId, {
          race_name: body.race_name, date: body.date, horses: body.horses ?? [],
          prediction: body.prediction, confidence: body.confidence ?? 0.5,
        });
        return json({ success: true, analysis: item });
      }

      // ── Real Estate ───────────────────────────────────────────────────────────
      case "realestate.list": return json({ success: true, properties: await listItems(admin, "property", userId) });
      case "realestate.add": {
        const item = await addItem(admin, "property", userId, {
          address: body.address, type: body.type ?? "apartment", price: body.price,
          area_sqm: body.area_sqm, status: body.status ?? "tracking",
          notes: body.notes,
        });
        return json({ success: true, property: item });
      }

      // ── Inventory ─────────────────────────────────────────────────────────────
      case "inventory.list": return json({ success: true, items: await listItems(admin, "inventory_item", userId) });
      case "inventory.add": {
        const item = await addItem(admin, "inventory_item", userId, {
          name: body.name, sku: body.sku, quantity: body.quantity ?? 0,
          price: body.price, category: body.category, location: body.location,
        });
        return json({ success: true, item });
      }
      case "inventory.update_qty": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, quantity: body.quantity, updated_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "inventory_item");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "barcode.scan": {
        const item = await addItem(admin, "barcode_scan", userId, {
          barcode: body.barcode, format: body.format ?? "QR", scanned_at: new Date().toISOString(),
          product_info: body.product_info,
        });
        return json({ success: true, scan: item });
      }
      case "barcode.list": return json({ success: true, scans: await listItems(admin, "barcode_scan", userId) });

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
