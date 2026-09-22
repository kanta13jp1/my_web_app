// app-hub — コアアプリ機能統合EF
// Merges (17 EFs): subscription-management, subscription-billing,
//   email-service, gamification-engine, calendar-events, kanban-board,
//   chat-messaging, team-task-manager, team-collaboration-sync,
//   file-storage-manager, expense-tracker, time-tracker,
//   automation-workflows, data-export-manager, webhook-manager,
//   api-rate-limiter, music-collaboration

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { AgentGpaActionError, handleAgentGpaAction } from "./agent_gpa.ts";
import {
  calendarIcsUidFromMetadata,
  normalizeCalendarIcsUid,
  prepareCalendarBulkCreateCandidates,
} from "./calendar_bulk_create.ts";
import {
  GaReadinessActionError,
  handleGaReadinessAction,
} from "./ga_readiness.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
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
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data").select(
    "id, metadata, created_at",
  )
    .eq("source", source).filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false }).limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source).filter(
      "metadata->>user_id",
      "eq",
      userId,
    );
  if (error) throw new Error(error.message);
}

async function updateItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
  patch: Record<string, unknown>,
) {
  const { data: existing, error: readError } = await admin.from("hub_data")
    .select("metadata")
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!existing) return null;

  const previous = (existing.metadata ?? {}) as Record<string, unknown>;
  const next = {
    ...previous,
    ...patch,
    user_id: userId,
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await admin.from("hub_data")
    .update({ metadata: next })
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .select("id, metadata, created_at")
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

const CALENDAR_REMINDER_MINUTES = new Set([0, 5, 10, 15, 30, 60]);
const DEFAULT_CALENDAR_ID = "default";
const DEFAULT_CALENDAR_NAME = "Default";
const DEFAULT_CALENDAR_COLOR = "#4285f4";
const CALENDAR_TIMEZONE_PATTERN = /^(UTC|[A-Za-z_]+\/[A-Za-z0-9_+\-\/]+)$/;

type CalendarListResponseItem = {
  calendar_id: string;
  calendar_name: string;
  color: string;
  is_default: boolean;
  id?: string;
  created_at?: string;
};

function normalizeCalendarReminderMinutes(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const minutes = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(minutes)) return null;
  return CALENDAR_REMINDER_MINUTES.has(minutes) ? minutes : null;
}

function normalizeCalendarRRule(value: unknown): string | null {
  const rrule = value?.toString().trim() ?? "";
  return rrule.length === 0 || rrule === "null" || rrule === "undefined"
    ? null
    : rrule;
}

function normalizeCalendarTimezone(value: unknown): string | null {
  const timezone = value?.toString().trim() ?? "";
  return CALENDAR_TIMEZONE_PATTERN.test(timezone) ? timezone : null;
}

function normalizeCalendarId(value: unknown): string {
  const id = value?.toString().trim() ?? "";
  return id.length === 0 || id === "null" || id === "undefined"
    ? DEFAULT_CALENDAR_ID
    : id;
}

function normalizeCalendarName(
  value: unknown,
  fallback = DEFAULT_CALENDAR_NAME,
): string {
  const name = value?.toString().trim() ?? "";
  return name || fallback;
}

function normalizeCalendarColor(value: unknown): string {
  const raw = value?.toString().trim() ?? "";
  const normalized = raw.startsWith("#") ? raw : `#${raw}`;
  return /^#[0-9a-fA-F]{6}$/.test(normalized)
    ? normalized.toLowerCase()
    : DEFAULT_CALENDAR_COLOR;
}

async function listCalendars(admin: SupabaseClient, userId: string) {
  const items = await listItems(admin, "calendar_calendar", userId, 100);
  const seen = new Set([DEFAULT_CALENDAR_ID]);
  const calendars: CalendarListResponseItem[] = [
    {
      calendar_id: DEFAULT_CALENDAR_ID,
      calendar_name: DEFAULT_CALENDAR_NAME,
      color: DEFAULT_CALENDAR_COLOR,
      is_default: true,
    },
  ];

  for (const item of items.reverse()) {
    const meta = (item.metadata ?? {}) as Record<string, unknown>;
    const calendarId = normalizeCalendarId(meta.calendar_id ?? item.id);
    if (calendarId === DEFAULT_CALENDAR_ID || seen.has(calendarId)) continue;
    seen.add(calendarId);
    calendars.push({
      calendar_id: calendarId,
      calendar_name: normalizeCalendarName(meta.calendar_name ?? meta.name),
      color: normalizeCalendarColor(meta.color),
      is_default: false,
      id: item.id,
      created_at: item.created_at,
    });
  }
  return calendars;
}

async function calendarNameById(
  admin: SupabaseClient,
  userId: string,
  calendarId: string,
) {
  if (calendarId === DEFAULT_CALENDAR_ID) return DEFAULT_CALENDAR_NAME;
  const calendars = await listCalendars(admin, userId);
  return calendars.find((calendar) => calendar.calendar_id === calendarId)
    ?.calendar_name ?? DEFAULT_CALENDAR_NAME;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = req.method === "POST"
      ? await req.json() as Record<string, unknown>
      : {};
    const action = String(
      body.action ?? new URL(req.url).searchParams.get("action") ?? "",
    );
    const userId = await getUserId(req);

    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // --- Subscription ---
      case "subscription.list": {
        const items = await listItems(admin, "subscription", userId);
        return json({ success: true, subscriptions: items });
      }

      case "subscription.create": {
        const item = await addItem(admin, "subscription", userId, {
          plan: body.plan ?? "free",
          status: "active",
          started_at: new Date().toISOString(),
        });
        return json({ success: true, subscription: item });
      }

      case "subscription.cancel": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "cancelled",
              cancelled_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "subscription");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // --- Billing ---
      case "billing.status": {
        const subs = await listItems(admin, "subscription", userId, 1);
        return json({
          success: true,
          subscription: subs[0] ?? null,
          plan: (subs[0]?.metadata as Record<string, unknown>)?.plan ?? "free",
        });
      }

      case "billing.invoice": {
        const invoices = await listItems(admin, "invoice", userId);
        return json({ success: true, invoices });
      }
      case "billing.create_invoice": {
        const item = await addItem(admin, "invoice", userId, {
          client_name: body.client_name,
          amount: body.amount ?? 0,
          description: body.description ?? "",
          status: "draft",
        });
        return json({ success: true, invoice: item });
      }

      // --- Email ---
      case "email.send": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (!resendKey) {
          return json({ error: "RESEND_API_KEY not configured" }, 503);
        }
        const r = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: body.from ?? "noreply@jibun.app",
            to: body.to,
            subject: body.subject,
            html: body.html ?? `<p>${body.text}</p>`,
          }),
        });
        return json({ success: r.ok, status: r.status });
      }

      // --- Gamification ---
      case "gamification.status": {
        const points = await listItems(
          admin,
          "gamification_event",
          userId,
          100,
        );
        const total = points.reduce(
          (sum, p) =>
            sum +
            (Number((p.metadata as Record<string, unknown>)?.points ?? 0)),
          0,
        );
        return json({
          success: true,
          total_points: total,
          events: points.slice(0, 10),
        });
      }

      case "gamification.award": {
        const item = await addItem(admin, "gamification_event", userId, {
          event: body.event,
          points: body.points ?? 10,
          reason: body.reason ?? "",
        });
        return json({ success: true, item });
      }

      // --- Calendar ---
      case "calendar.list_calendars": {
        const calendars = await listCalendars(admin, userId);
        return json({ success: true, calendars });
      }

      case "calendar.create_calendar": {
        const calendarId = crypto.randomUUID();
        const calendarName = normalizeCalendarName(body.calendar_name);
        const color = normalizeCalendarColor(body.color);
        const item = await addItem(admin, "calendar_calendar", userId, {
          calendar_id: calendarId,
          calendar_name: calendarName,
          color,
        });
        const meta = (item.metadata ?? {}) as Record<string, unknown>;
        return json({
          success: true,
          calendar: {
            ...meta,
            id: item.id,
            created_at: item.created_at,
            is_default: false,
          },
        });
      }

      case "calendar.delete_calendar": {
        const calendarId = normalizeCalendarId(body.calendar_id ?? body.id);
        if (calendarId === DEFAULT_CALENDAR_ID) {
          return json({ error: "Default calendar cannot be deleted" }, 400);
        }

        const calendars = await listItems(
          admin,
          "calendar_calendar",
          userId,
          100,
        );
        const calendar = calendars.find((item) => {
          const meta = (item.metadata ?? {}) as Record<string, unknown>;
          return normalizeCalendarId(meta.calendar_id ?? item.id) ===
            calendarId;
        });
        if (!calendar) return json({ error: "Calendar not found" }, 404);

        await deleteItem(
          admin,
          "calendar_calendar",
          userId,
          String(calendar.id),
        );

        const events = await listItems(admin, "calendar_event", userId, 500);
        for (const event of events) {
          const meta = (event.metadata ?? {}) as Record<string, unknown>;
          if (normalizeCalendarId(meta.calendar_id) !== calendarId) continue;
          await updateItem(admin, "calendar_event", userId, String(event.id), {
            calendar_id: DEFAULT_CALENDAR_ID,
            calendar_name: DEFAULT_CALENDAR_NAME,
          });
        }
        return json({ success: true });
      }

      case "calendar.list": {
        const requestedIds = Array.isArray(body.calendar_ids)
          ? new Set(body.calendar_ids.map(normalizeCalendarId))
          : null;
        const calendars = await listCalendars(admin, userId);
        const names = new Map(
          calendars.map((calendar) => [
            calendar.calendar_id,
            calendar.calendar_name,
          ]),
        );
        const items = await listItems(admin, "calendar_event", userId);
        const events = items.flatMap((it) => {
          const meta = (it.metadata ?? {}) as Record<string, unknown>;
          const calendarId = normalizeCalendarId(meta.calendar_id);
          if (requestedIds && !requestedIds.has(calendarId)) return [];
          return [{
            ...meta,
            calendar_id: calendarId,
            calendar_name: normalizeCalendarName(
              meta.calendar_name,
              names.get(calendarId) ?? DEFAULT_CALENDAR_NAME,
            ),
            event_id: it.id,
            created_at: it.created_at,
          }];
        });
        return json({ success: true, events });
      }

      case "calendar.create": {
        const calendarId = normalizeCalendarId(body.calendar_id);
        const calendarName = await calendarNameById(admin, userId, calendarId);
        const icalUid = normalizeCalendarIcsUid(body.ical_uid ?? body.uid);
        const item = await addItem(admin, "calendar_event", userId, {
          title: body.title,
          start_at: body.start_at,
          end_at: body.end_at,
          description: body.description ?? "",
          all_day: body.all_day ?? false,
          color: body.color ?? "#4285f4",
          reminder_min: normalizeCalendarReminderMinutes(body.reminder_min),
          calendar_id: calendarId,
          calendar_name: calendarName,
          rrule: normalizeCalendarRRule(body.rrule),
          timezone: normalizeCalendarTimezone(body.timezone),
          ...(icalUid ? { ical_uid: icalUid, uid: icalUid } : {}),
        });
        const meta = (item.metadata ?? {}) as Record<string, unknown>;
        return json({
          success: true,
          event: { ...meta, event_id: item.id, created_at: item.created_at },
        });
      }

      case "calendar.bulk_create": {
        const existingItems = await listItems(
          admin,
          "calendar_event",
          userId,
          1000,
        );
        const existingUids = new Set(
          existingItems.map((item) =>
            calendarIcsUidFromMetadata(
              (item.metadata ?? {}) as Record<string, unknown>,
            )
          ).filter(Boolean),
        );
        const prepared = prepareCalendarBulkCreateCandidates(
          body.events,
          existingUids,
        );
        const created: Record<string, unknown>[] = [];

        for (const event of prepared.candidates) {
          const calendarId = normalizeCalendarId(event.calendar_id);
          const calendarName = await calendarNameById(
            admin,
            userId,
            calendarId,
          );
          const item = await addItem(admin, "calendar_event", userId, {
            title: event.title ?? "Untitled",
            start_at: event.start_at,
            end_at: event.end_at ?? event.start_at,
            description: event.description ?? "",
            all_day: event.all_day ?? false,
            color: event.color ?? "#4285f4",
            reminder_min: normalizeCalendarReminderMinutes(event.reminder_min),
            calendar_id: calendarId,
            calendar_name: calendarName,
            rrule: normalizeCalendarRRule(event.rrule),
            timezone: normalizeCalendarTimezone(event.timezone),
            ical_uid: event.ical_uid,
            uid: event.ical_uid,
          });
          const meta = (item.metadata ?? {}) as Record<string, unknown>;
          created.push({
            ...meta,
            event_id: item.id,
            created_at: item.created_at,
          });
        }

        return json({
          success: true,
          created_count: created.length,
          skipped_duplicate_count: prepared.skippedDuplicates,
          invalid_count: prepared.invalidCount,
          events: created,
        });
      }

      case "calendar.update": {
        const id = String(body.id ?? "");
        if (!id) return json({ error: "id is required" }, 400);
        const patch: Record<string, unknown> = {};
        if (Object.hasOwn(body, "title")) patch.title = body.title;
        if (Object.hasOwn(body, "start_at")) patch.start_at = body.start_at;
        if (Object.hasOwn(body, "end_at")) patch.end_at = body.end_at;
        if (Object.hasOwn(body, "description")) {
          patch.description = body.description ?? "";
        }
        if (Object.hasOwn(body, "all_day")) {
          patch.all_day = body.all_day ?? false;
        }
        if (Object.hasOwn(body, "color")) patch.color = body.color ?? "#4285f4";
        if (Object.hasOwn(body, "reminder_min")) {
          patch.reminder_min = normalizeCalendarReminderMinutes(
            body.reminder_min,
          );
        }
        if (Object.hasOwn(body, "rrule")) {
          patch.rrule = normalizeCalendarRRule(body.rrule);
        }
        if (Object.hasOwn(body, "timezone")) {
          patch.timezone = normalizeCalendarTimezone(body.timezone);
        }
        if (Object.hasOwn(body, "calendar_id")) {
          const calendarId = normalizeCalendarId(body.calendar_id);
          patch.calendar_id = calendarId;
          patch.calendar_name = await calendarNameById(
            admin,
            userId,
            calendarId,
          );
        }
        const item = await updateItem(
          admin,
          "calendar_event",
          userId,
          id,
          patch,
        );
        if (!item) return json({ error: "Event not found" }, 404);
        const meta = (item.metadata ?? {}) as Record<string, unknown>;
        return json({
          success: true,
          event: { ...meta, event_id: item.id, created_at: item.created_at },
        });
      }

      case "calendar.delete": {
        await deleteItem(admin, "calendar_event", userId, String(body.id));
        return json({ success: true });
      }

      // --- Kanban ---
      case "kanban.list": {
        const { data: boards } = await admin.from("hub_data")
          .select("id,metadata,created_at")
          .eq("source", "kanban_board")
          .filter("metadata->>user_id", "eq", userId)
          .order("created_at", { ascending: false })
          .limit(10);
        return json({ success: true, boards: boards ?? [] });
      }

      case "kanban.create": {
        const board = await addItem(admin, "kanban_board", userId, {
          title: body.title,
          columns: body.columns ?? ["Todo", "In Progress", "Done"],
          cards: [],
        });
        return json({ success: true, board });
      }

      case "kanban.card_add": {
        const boards2 = await listItems(admin, "kanban_board", userId, 100);
        const board = boards2.find((b) => b.id === body.board_id);
        if (!board) return json({ error: "Board not found" }, 404);
        const meta = board.metadata as Record<string, unknown>;
        const cards = (meta.cards as unknown[]) ?? [];
        cards.push({
          id: crypto.randomUUID(),
          title: body.title,
          column: body.column ?? "Todo",
          created_at: new Date().toISOString(),
        });
        await admin.from("hub_data").update({ metadata: { ...meta, cards } })
          .eq("id", board.id);
        return json({ success: true, card_count: cards.length });
      }

      // --- Chat ---
      case "chat.list_channels": {
        const { data, error: cerr } = await admin.from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "chat_channel")
          .order("created_at", { ascending: false })
          .limit(50);
        if (cerr) throw new Error(cerr.message);
        const channels = (data ?? []).map((c) => ({
          id: c.id,
          ...(c.metadata as Record<string, unknown>),
          createdAt: c.created_at,
        }));
        return json({ success: true, channels });
      }

      case "chat.create_channel": {
        const name = String(body.name ?? "").trim();
        if (!name) return json({ success: false, error: "name required" }, 400);
        const channel = await addItem(admin, "chat_channel", userId, {
          name,
          description: body.description ?? "",
          is_public: body.is_public ?? true,
          creator_id: userId,
        });
        return json({ success: true, channelId: channel.id, channel });
      }

      case "chat.get_messages": {
        const channelId = String(body.channel_id ?? "");
        if (!channelId) {
          return json({ success: false, error: "channel_id required" }, 400);
        }
        const limit = Number(body.limit ?? 50);
        const { data, error: merr } = await admin.from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "chat_message")
          .filter("metadata->>channel_id", "eq", channelId)
          .order("created_at", { ascending: false })
          .limit(limit);
        if (merr) throw new Error(merr.message);
        const messages = (data ?? []).reverse().map((m) => ({
          id: m.id,
          ...(m.metadata as Record<string, unknown>),
          sentAt: m.created_at,
        }));
        return json({ success: true, messages });
      }

      case "chat.list": {
        const items = await listItems(admin, "chat_message", userId);
        return json({ success: true, messages: items });
      }

      case "chat.send": {
        const channelId = String(body.channel_id ?? body.room_id ?? "general");
        const content = String(body.content ?? body.text ?? "").trim();
        if (!content) {
          return json({ success: false, error: "content required" }, 400);
        }
        const message = await addItem(admin, "chat_message", userId, {
          channel_id: channelId,
          content,
          thread_id: body.thread_id ?? null,
          attachments: body.attachments ?? [],
        });
        return json({ success: true, messageId: message.id, message });
      }

      // --- Team Tasks ---
      case "team.tasks": {
        const items = await listItems(admin, "team_task", userId);
        return json({ success: true, tasks: items });
      }

      case "team.task_create": {
        const task = await addItem(admin, "team_task", userId, {
          title: body.title,
          assignee: body.assignee ?? userId,
          due_date: body.due_date,
          status: "pending",
          priority: body.priority ?? "medium",
        });
        return json({ success: true, task });
      }

      case "team.task_update": {
        const { error: te } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id))
          .eq("source", "team_task");
        if (te) throw new Error(te.message);
        return json({ success: true });
      }

      // --- Collaboration ---
      case "collab.status": {
        const sessions = await listItems(admin, "collab_session", userId, 1);
        return json({ success: true, session: sessions[0] ?? null });
      }

      case "collab.sync": {
        const session = await addItem(admin, "collab_session", userId, {
          doc_id: body.doc_id,
          cursor: body.cursor,
          content_hash: body.content_hash,
          synced_at: new Date().toISOString(),
        });
        return json({ success: true, session });
      }

      // --- File Storage ---
      case "file.list": {
        const items = await listItems(admin, "file_meta", userId);
        return json({ success: true, files: items });
      }

      case "file.save": {
        const file = await addItem(admin, "file_meta", userId, {
          name: body.name,
          path: body.path,
          size: body.size ?? 0,
          mime_type: body.mime_type ?? "application/octet-stream",
          storage_bucket: body.bucket ?? "files",
        });
        return json({ success: true, file });
      }

      case "file.delete": {
        await deleteItem(admin, "file_meta", userId, String(body.id));
        return json({ success: true });
      }

      // --- Expense Tracker ---
      case "expense.list": {
        const items = await listItems(admin, "expense", userId);
        return json({ success: true, expenses: items });
      }

      case "expense.add": {
        const expense = await addItem(admin, "expense", userId, {
          amount: body.amount,
          currency: body.currency ?? "JPY",
          category: body.category ?? "other",
          description: body.description ?? "",
          date: body.date ?? new Date().toISOString().split("T")[0],
        });
        return json({ success: true, expense });
      }

      case "expense.stats": {
        const expenses = await listItems(admin, "expense", userId, 200);
        const total = expenses.reduce(
          (s, e) =>
            s + Number((e.metadata as Record<string, unknown>)?.amount ?? 0),
          0,
        );
        return json({ success: true, total, count: expenses.length });
      }

      // --- Time Tracker ---
      case "time.list": {
        const view = String(
          body.view ?? new URL(req.url).searchParams.get("view") ?? "today",
        );
        const now = new Date();
        let since: Date;
        if (view === "week") {
          since = new Date(now);
          since.setDate(since.getDate() - since.getDay());
          since.setHours(0, 0, 0, 0);
        } else if (view === "month") {
          since = new Date(now.getFullYear(), now.getMonth(), 1);
        } else {
          since = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        }
        const { data, error: lerr } = await admin.from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "time_entry")
          .filter("metadata->>user_id", "eq", userId)
          .gte("created_at", since.toISOString())
          .order("created_at", { ascending: false });
        if (lerr) throw new Error(lerr.message);
        const rows = data ?? [];
        let totalHours = 0;
        for (const e of rows) {
          totalHours += Number(
            (e.metadata as Record<string, unknown>)?.hours ?? 0,
          );
        }
        const entries = rows.map((e) => ({
          ...(e.metadata as Record<string, unknown>),
          id: e.id,
          recordedAt: e.created_at,
        }));
        const cap = view === "month" ? 160 : view === "week" ? 40 : 8;
        return json({
          success: true,
          entries,
          totalHours: Math.round(totalHours * 100) / 100,
          overtimeAlert: totalHours > cap,
        });
      }

      case "time.projects": {
        const items = await listItems(admin, "time_entry", userId, 500);
        const projectHours = new Map<string, number>();
        for (const e of items) {
          const meta = e.metadata as Record<string, unknown>;
          const proj = String(meta?.project ?? "未分類");
          const hours = Number(meta?.hours ?? 0);
          projectHours.set(proj, (projectHours.get(proj) ?? 0) + hours);
        }
        const projects = [...projectHours.entries()]
          .map(([name, hours]) => ({
            name,
            hours: Math.round(hours * 100) / 100,
          }))
          .sort((a, b) => b.hours - a.hours);
        return json({ success: true, projects });
      }

      case "time.clock": {
        const clockType = String(body.type ?? "clock_in");
        const entry = await addItem(admin, "time_entry", userId, {
          type: clockType,
          timestamp: new Date().toISOString(),
          hours: 0,
        });
        return json({ success: true, entry });
      }

      case "time.log_hours": {
        const hours = Number(body.hours ?? 0);
        if (hours <= 0) {
          return json({ success: false, error: "hours required" }, 400);
        }
        const entry = await addItem(admin, "time_entry", userId, {
          type: "manual",
          project: body.project ?? "未分類",
          hours,
          memo: body.memo ?? "",
          date: body.date ?? new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, entry });
      }

      case "time.start": {
        const entry = await addItem(admin, "time_entry", userId, {
          project: body.project ?? "default",
          started_at: new Date().toISOString(),
          status: "running",
        });
        return json({ success: true, entry });
      }

      case "time.stop": {
        const { error: ste } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "done",
              stopped_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "time_entry");
        if (ste) throw new Error(ste.message);
        return json({ success: true });
      }

      // --- Automation Workflows ---
      case "workflow.list": {
        const items = await listItems(admin, "workflow", userId);
        return json({ success: true, workflows: items });
      }

      case "workflow.create": {
        const workflow = await addItem(admin, "workflow", userId, {
          name: body.name,
          trigger: body.trigger ?? "manual",
          steps: body.steps ?? [],
          status: "active",
        });
        return json({ success: true, workflow });
      }

      case "workflow.run": {
        const run = await addItem(admin, "workflow_run", userId, {
          workflow_id: body.workflow_id,
          triggered_at: new Date().toISOString(),
          status: "running",
        });
        return json({ success: true, run });
      }

      case "workflow.delete": {
        await deleteItem(admin, "workflow", userId, String(body.id));
        return json({ success: true });
      }

      // --- Data Export ---
      case "export.create": {
        const job = await addItem(admin, "export_job", userId, {
          format: body.format ?? "csv",
          table: body.table ?? "hub_data",
          status: "pending",
          created_at: new Date().toISOString(),
        });
        return json({ success: true, job });
      }

      case "export.list": {
        const items = await listItems(admin, "export_job", userId);
        return json({ success: true, jobs: items });
      }

      // --- Webhooks ---
      case "webhook.list": {
        const items = await listItems(admin, "webhook", userId);
        return json({ success: true, webhooks: items });
      }

      case "webhook.create": {
        const webhook = await addItem(admin, "webhook", userId, {
          url: body.url,
          events: body.events ?? [],
          secret: crypto.randomUUID(),
          status: "active",
        });
        return json({ success: true, webhook });
      }

      case "webhook.delete": {
        await deleteItem(admin, "webhook", userId, String(body.id));
        return json({ success: true });
      }

      // --- Rate Limiter ---
      case "ratelimit.check": {
        const windowMs = Number(body.window_ms ?? 60000);
        const limit = Number(body.limit ?? 100);
        const since = new Date(Date.now() - windowMs).toISOString();
        const { data: hits } = await admin.from("hub_data")
          .select("id")
          .eq("source", "rate_hit")
          .filter("metadata->>user_id", "eq", userId)
          .gte("created_at", since);
        const count = hits?.length ?? 0;
        if (count < limit) {
          await addItem(admin, "rate_hit", userId, {
            key: body.key ?? "default",
          });
        }
        return json({
          allowed: count < limit,
          count,
          limit,
          remaining: Math.max(0, limit - count),
        });
      }

      // --- Music Collaboration ---
      case "music.sessions": {
        const items = await listItems(admin, "music_collab", userId);
        return json({ success: true, sessions: items });
      }

      case "music.create_session": {
        const session = await addItem(admin, "music_collab", userId, {
          room_id: crypto.randomUUID().slice(0, 8),
          name: body.name ?? "新しいセッション",
          participants: [],
          status: "open",
        });
        return json({ success: true, session });
      }

      case "music.join": {
        const join = await addItem(admin, "music_collab_join", userId, {
          room_id: body.room_id,
          joined_at: new Date().toISOString(),
        });
        return json({ success: true, join });
      }

      // ── Changelog ───────────────────────────────────────────────────────────────
      case "changelog.list": {
        const entries = await listItems(admin, "changelog_entry", userId);
        return json({ success: true, entries });
      }
      case "changelog.create": {
        const entry = await addItem(admin, "changelog_entry", userId, {
          title: body.title,
          type: body.type ?? "feature",
          description: body.description ?? "",
          created_at: new Date().toISOString(),
        });
        return json({ success: true, entry });
      }

      // --- Agent GPA Evaluations (#1124 Phase 1) ---
      case "agent.evaluate_gpa":
      case "agent.list_gpa_recent": {
        const result = await handleAgentGpaAction({
          action,
          admin,
          body,
          userId,
        });
        return json({ success: true, ...result });
      }

      // --- GA Launch Readiness Gate (#1640) ---
      case "agent.list_ga_axes": {
        const gaReadiness = handleGaReadinessAction(action);
        return json({ success: true, ga_readiness: gaReadiness });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const status = err instanceof AgentGpaActionError ||
        err instanceof GaReadinessActionError
      ? err.status
      : 500;
    return json({ error: message }, status);
  }
});
