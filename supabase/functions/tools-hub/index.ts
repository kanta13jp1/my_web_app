// tools-hub — 個人生産性ツール統合EF
// Merges (30 EFs): password-generator, password-vault, currency-converter,
//   weather-widget, qr-code-generator, markdown-renderer, pomodoro-timer,
//   focus-timer, clipboard-history, quick-note, goal-tracker, contact-manager,
//   reading-list, bookmark-manager, bookmark-sync, tag-manager, template-library,
//   address-book, emergency-contacts, news-rss-aggregator, changelog-manager,
//   multi-language, habit-tracker, habit-gamification, virtual-pet, poll-survey,
//   form-builder, note-sharing-enhanced, content-versioning, mindmap-diagram
//
// GET/POST ?action=<action> or body { action: "..." }
// All data stored in app_analytics table (source column = feature name)

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

// Generic CRUD on app_analytics by source
async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("app_analytics")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("app_analytics")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("app_analytics")
    .delete()
    .eq("id", id)
    .eq("source", source)
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

    // ── Stateless utilities (no auth needed) ────────────────────────────────
    if (action === "generate_password") {
      const length = Number(body.length ?? 16);
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-_";
      const arr = new Uint8Array(length);
      crypto.getRandomValues(arr);
      const password = Array.from(arr, (b) => chars[b % chars.length]).join("");
      return json({ success: true, password });
    }

    if (action === "generate_qr") {
      const text = String(body.text ?? "");
      const size = Number(body.size ?? 200);
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
      return json({ success: true, qr_url: qrUrl, text });
    }

    if (action === "convert_currency") {
      const from = String(body.from ?? "USD").toUpperCase();
      const to = String(body.to ?? "JPY").toUpperCase();
      const amount = Number(body.amount ?? 1);
      const res = await fetch(`https://open.er-api.com/v6/latest/${from}`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Exchange rate API unavailable" }, 502);
      const rates = (await res.json() as { rates: Record<string, number> }).rates;
      const rate = rates[to];
      if (!rate) return json({ error: `Unknown currency: ${to}` }, 400);
      return json({ success: true, from, to, amount, rate, result: amount * rate });
    }

    if (action === "get_weather") {
      const city = String(body.city ?? "Tokyo");
      const res = await fetch(`https://wttr.in/${encodeURIComponent(city)}?format=j1`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Weather API unavailable" }, 502);
      const data = await res.json() as Record<string, unknown>;
      return json({ success: true, city, weather: data });
    }

    if (action === "render_markdown") {
      // Client-side rendering preferred; return raw markdown with metadata
      const markdown = String(body.markdown ?? "");
      return json({ success: true, markdown, length: markdown.length });
    }

    if (action === "translate") {
      const text = String(body.text ?? "");
      const target = String(body.target ?? "ja");
      const source = String(body.source ?? "auto");
      const res = await fetch(
        `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${source}|${target}`
      ).catch(() => null);
      if (!res || !res.ok) return json({ error: "Translation API unavailable" }, 502);
      const result = await res.json() as { responseData?: { translatedText?: string } };
      return json({ success: true, original: text, translated: result.responseData?.translatedText ?? text, target });
    }

    // ── Authenticated CRUD operations ────────────────────────────────────────
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Bookmarks ───────────────────────────────────────────────────────────
      case "bookmark.list": return json({ success: true, bookmarks: await listItems(admin, "bookmark", userId) });
      case "bookmark.add": {
        const item = await addItem(admin, "bookmark", userId, {
          url: body.url, title: body.title, tags: body.tags ?? [],
        });
        return json({ success: true, bookmark: item });
      }
      case "bookmark.delete": {
        await deleteItem(admin, "bookmark", userId, String(body.id ?? ""));
        return json({ success: true });
      }
      case "bookmark.sync": {
        const bookmarks = body.bookmarks as unknown[] ?? [];
        for (const bm of bookmarks) {
          await addItem(admin, "bookmark_sync", userId, bm as Record<string, unknown>);
        }
        return json({ success: true, synced: bookmarks.length });
      }

      // ── Quick Notes ─────────────────────────────────────────────────────────
      case "note.list": return json({ success: true, notes: await listItems(admin, "quick_note", userId) });
      case "note.add": {
        const item = await addItem(admin, "quick_note", userId, {
          content: body.content, title: body.title ?? "", tags: body.tags ?? [],
        });
        return json({ success: true, note: item });
      }
      case "note.delete": {
        await deleteItem(admin, "quick_note", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Goals ───────────────────────────────────────────────────────────────
      case "goal.list": return json({ success: true, goals: await listItems(admin, "goal", userId) });
      case "goal.add": {
        const item = await addItem(admin, "goal", userId, {
          title: body.title, description: body.description, deadline: body.deadline,
          status: "active", milestones: body.milestones ?? [],
        });
        return json({ success: true, goal: item });
      }
      case "goal.update": {
        const { error } = await admin.from("app_analytics")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "goal");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "goal.delete": {
        await deleteItem(admin, "goal", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Contacts ────────────────────────────────────────────────────────────
      case "contact.list": return json({ success: true, contacts: await listItems(admin, "contact", userId) });
      case "contact.add": {
        const item = await addItem(admin, "contact", userId, {
          name: body.name, email: body.email, phone: body.phone,
          company: body.company, notes: body.notes,
        });
        return json({ success: true, contact: item });
      }
      case "contact.delete": {
        await deleteItem(admin, "contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Reading List ────────────────────────────────────────────────────────
      case "reading.list": return json({ success: true, items: await listItems(admin, "reading", userId) });
      case "reading.add": {
        const item = await addItem(admin, "reading", userId, {
          url: body.url, title: body.title, status: "unread",
        });
        return json({ success: true, item });
      }
      case "reading.mark_read": {
        const { error } = await admin.from("app_analytics")
          .update({ metadata: { user_id: userId, status: "read", read_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "reading");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Tags ────────────────────────────────────────────────────────────────
      case "tag.list": return json({ success: true, tags: await listItems(admin, "tag", userId) });
      case "tag.create": {
        const item = await addItem(admin, "tag", userId, { name: body.name, color: body.color });
        return json({ success: true, tag: item });
      }
      case "tag.delete": {
        await deleteItem(admin, "tag", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Templates ───────────────────────────────────────────────────────────
      case "template.list": return json({ success: true, templates: await listItems(admin, "template", userId) });
      case "template.create": {
        const item = await addItem(admin, "template", userId, {
          name: body.name, content: body.content, category: body.category,
        });
        return json({ success: true, template: item });
      }
      case "template.use": {
        const templates = await listItems(admin, "template", userId);
        const found = templates.find((t) => (t.metadata as Record<string, unknown>)?.id === body.id);
        return json({ success: true, content: (found?.metadata as Record<string, unknown>)?.content ?? "" });
      }
      case "template.delete": {
        await deleteItem(admin, "template", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Address Book ─────────────────────────────────────────────────────────
      case "address.list": return json({ success: true, addresses: await listItems(admin, "address", userId) });
      case "address.add": {
        const item = await addItem(admin, "address", userId, {
          name: body.name, street: body.street, city: body.city,
          country: body.country, type: body.type ?? "home",
        });
        return json({ success: true, address: item });
      }
      case "address.delete": {
        await deleteItem(admin, "address", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Emergency Contacts ──────────────────────────────────────────────────
      case "emergency.list": return json({ success: true, contacts: await listItems(admin, "emergency_contact", userId) });
      case "emergency.add": {
        const item = await addItem(admin, "emergency_contact", userId, {
          name: body.name, phone: body.phone, relation: body.relation,
        });
        return json({ success: true, contact: item });
      }
      case "emergency.delete": {
        await deleteItem(admin, "emergency_contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Habits ──────────────────────────────────────────────────────────────
      case "habit.list": return json({ success: true, habits: await listItems(admin, "habit_definition", userId) });
      case "habit.create": {
        const item = await addItem(admin, "habit_definition", userId, {
          name: body.name, frequency: body.frequency ?? "daily",
          target: body.target ?? 1, points: body.points ?? 10,
        });
        return json({ success: true, habit: item });
      }
      case "habit.checkin": {
        const item = await addItem(admin, "habit_checkin", userId, {
          habit_id: body.habit_id, note: body.note ?? "", date: new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, checkin: item });
      }
      case "habit.stats": {
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        return json({ success: true, total_checkins: checkins.length, checkins: checkins.slice(0, 30) });
      }

      // ── Habit Gamification (merged from habit-gamification EF) ───────────────
      case "habit.gamification.profile": {
        const habits = await listItems(admin, "habit_definition", userId, 20);
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        const points = checkins.length * 10;
        const level = Math.floor(points / 100) + 1;
        return json({ success: true, profile: { user_id: userId, points, level, habit_count: habits.length, checkin_count: checkins.length } });
      }
      case "habit.gamification.badges": {
        const badges = await listItems(admin, "habit_badge", userId);
        return json({ success: true, badges });
      }
      case "habit.gamification.challenges": {
        const challenges = await listItems(admin, "habit_challenge", userId, 10);
        return json({ success: true, challenges });
      }
      case "habit.gamification.leaderboard": {
        const { data, error: lbErr } = await admin.from("app_analytics")
          .select("metadata")
          .eq("source", "habit_checkin")
          .order("created_at", { ascending: false })
          .limit(100);
        if (lbErr) throw new Error(lbErr.message);
        const counts: Record<string, number> = {};
        for (const row of data ?? []) {
          const uid = (row.metadata as Record<string, unknown>)?.user_id as string;
          if (uid) counts[uid] = (counts[uid] ?? 0) + 1;
        }
        const leaderboard = Object.entries(counts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 20)
          .map(([uid, count], i) => ({ rank: i + 1, user_id: uid, checkins: count }));
        return json({ success: true, leaderboard });
      }
      case "habit.gamification.award": {
        const badge = await addItem(admin, "habit_badge", userId, {
          badge_type: body.badge_type ?? "streak", title: body.title ?? "バッジ", earned_at: new Date().toISOString(),
        });
        return json({ success: true, badge });
      }

      // ── Pomodoro / Focus Timer ───────────────────────────────────────────────
      case "pomodoro.start": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, started_at: new Date().toISOString(), status: "running",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.complete": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, completed_at: new Date().toISOString(), status: "done",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.history": return json({ success: true, sessions: await listItems(admin, "pomodoro", userId) });

      case "focus.start": {
        const item = await addItem(admin, "focus_timer", userId, {
          task: body.task ?? "", started_at: new Date().toISOString(),
        });
        return json({ success: true, session: item });
      }

      // ── Clipboard History ────────────────────────────────────────────────────
      case "clipboard.list": return json({ success: true, items: await listItems(admin, "clipboard", userId, 30) });
      case "clipboard.add": {
        const item = await addItem(admin, "clipboard", userId, { text: body.text, source: body.source ?? "manual" });
        return json({ success: true, item });
      }
      case "clipboard.clear": {
        await admin.from("app_analytics")
          .delete().eq("source", "clipboard").filter("metadata->>user_id", "eq", userId);
        return json({ success: true });
      }

      // ── News / RSS ───────────────────────────────────────────────────────────
      case "rss.list_feeds": return json({ success: true, feeds: await listItems(admin, "rss_feed", userId) });
      case "rss.add_feed": {
        const item = await addItem(admin, "rss_feed", userId, { url: body.url, title: body.title });
        return json({ success: true, feed: item });
      }
      case "rss.fetch": {
        const feedUrl = String(body.url ?? "");
        const res = await fetch(feedUrl).catch(() => null);
        if (!res || !res.ok) return json({ error: "Cannot fetch feed" }, 502);
        const text = await res.text();
        return json({ success: true, content: text.slice(0, 5000) });
      }

      // ── Changelog ────────────────────────────────────────────────────────────
      case "changelog.list": return json({ success: true, entries: await listItems(admin, "changelog", userId) });
      case "changelog.create": {
        const item = await addItem(admin, "changelog", userId, {
          version: body.version, title: body.title, changes: body.changes ?? [],
        });
        return json({ success: true, entry: item });
      }

      // ── Mindmap ──────────────────────────────────────────────────────────────
      case "mindmap.list": return json({ success: true, maps: await listItems(admin, "mindmap", userId) });
      case "mindmap.create": {
        const item = await addItem(admin, "mindmap", userId, {
          title: body.title, nodes: body.nodes ?? [], edges: body.edges ?? [],
        });
        return json({ success: true, map: item });
      }
      case "mindmap.update": {
        const { error } = await admin.from("app_analytics")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "mindmap");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "mindmap.delete": {
        await deleteItem(admin, "mindmap", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Polls & Forms ────────────────────────────────────────────────────────
      case "poll.create": {
        const item = await addItem(admin, "poll", userId, {
          question: body.question, options: body.options ?? [], votes: {},
        });
        return json({ success: true, poll: item });
      }
      case "poll.vote": {
        const polls = await listItems(admin, "poll", userId, 100);
        const poll = polls.find((p) => p.id === body.poll_id);
        if (!poll) return json({ error: "Poll not found" }, 404);
        const meta = poll.metadata as Record<string, unknown>;
        const votes = (meta.votes as Record<string, number>) ?? {};
        votes[String(body.option ?? "")] = (votes[String(body.option ?? "")] ?? 0) + 1;
        await admin.from("app_analytics").update({ metadata: { ...meta, votes } }).eq("id", poll.id);
        return json({ success: true, votes });
      }
      case "form.create": {
        const item = await addItem(admin, "form", userId, {
          title: body.title, fields: body.fields ?? [], responses: [],
        });
        return json({ success: true, form: item });
      }
      case "form.submit": {
        const item = await addItem(admin, "form_response", userId, {
          form_id: body.form_id, responses: body.responses ?? {},
        });
        return json({ success: true, response: item });
      }

      // ── Note Sharing ─────────────────────────────────────────────────────────
      case "note_share.create": {
        const shareId = crypto.randomUUID();
        const item = await addItem(admin, "note_share", userId, {
          share_id: shareId, content: body.content, title: body.title,
          expires_at: body.expires_at, is_public: body.is_public ?? true,
        });
        return json({ success: true, share_id: shareId, share: item });
      }
      case "note_share.get": {
        const { data } = await admin.from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "note_share")
          .filter("metadata->>share_id", "eq", String(body.share_id ?? ""))
          .single();
        return json({ success: true, note: data });
      }

      // ── Content Versioning ───────────────────────────────────────────────────
      case "version.list": return json({ success: true, versions: await listItems(admin, "content_version", userId) });
      case "version.create": {
        const item = await addItem(admin, "content_version", userId, {
          document_id: body.document_id, content: body.content, version: body.version ?? 1,
        });
        return json({ success: true, version: item });
      }

      // ── Password Vault ───────────────────────────────────────────────────────
      case "vault.list": return json({ success: true, entries: await listItems(admin, "password_vault", userId) });
      case "vault.add": {
        const item = await addItem(admin, "password_vault", userId, {
          site: body.site, username: body.username, encrypted_password: body.encrypted_password,
          notes: body.notes,
        });
        return json({ success: true, entry: item });
      }
      case "vault.delete": {
        await deleteItem(admin, "password_vault", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Virtual Pet ──────────────────────────────────────────────────────────
      case "pet.status": {
        const pets = await listItems(admin, "virtual_pet", userId, 1);
        if (pets.length === 0) {
          const pet = await addItem(admin, "virtual_pet", userId, {
            name: "たま", hunger: 50, happiness: 50, age_days: 0, last_fed: new Date().toISOString(),
          });
          return json({ success: true, pet });
        }
        return json({ success: true, pet: pets[0] });
      }
      case "pet.feed": {
        const { data: latest } = await admin.from("app_analytics")
          .select("id, metadata").eq("source", "virtual_pet")
          .filter("metadata->>user_id", "eq", userId).order("created_at", { ascending: false }).limit(1).single();
        if (!latest) return json({ error: "No pet found" }, 404);
        const meta = latest.metadata as Record<string, unknown>;
        await admin.from("app_analytics").update({
          metadata: { ...meta, hunger: Math.min(100, Number(meta.hunger ?? 50) + 20), last_fed: new Date().toISOString() },
        }).eq("id", latest.id);
        return json({ success: true, message: "Pet fed!" });
      }

      default:
        return json({
          error: `Unknown action: ${action}`,
          available_actions: [
            "generate_password", "generate_qr", "convert_currency", "get_weather", "render_markdown", "translate",
            "bookmark.list", "bookmark.add", "bookmark.delete", "bookmark.sync",
            "note.list", "note.add", "note.delete",
            "goal.list", "goal.add", "goal.update", "goal.delete",
            "contact.list", "contact.add", "contact.delete",
            "reading.list", "reading.add", "reading.mark_read",
            "tag.list", "tag.create", "tag.delete",
            "template.list", "template.create", "template.use", "template.delete",
            "address.list", "address.add", "address.delete",
            "emergency.list", "emergency.add", "emergency.delete",
            "habit.list", "habit.create", "habit.checkin", "habit.stats",
            "pomodoro.start", "pomodoro.complete", "pomodoro.history",
            "focus.start",
            "clipboard.list", "clipboard.add", "clipboard.clear",
            "rss.list_feeds", "rss.add_feed", "rss.fetch",
            "changelog.list", "changelog.create",
            "mindmap.list", "mindmap.create", "mindmap.update", "mindmap.delete",
            "poll.create", "poll.vote", "form.create", "form.submit",
            "note_share.create", "note_share.get",
            "version.list", "version.create",
            "vault.list", "vault.add", "vault.delete",
            "pet.status", "pet.feed",
          ],
        }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
