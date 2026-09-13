// lifestyle-hub — ライフスタイル・通知・セキュリティ統合EF
// Merges (29 EFs): fitness-health-tracker, recipe-meal-planner, carbon-footprint-tracker,
//   pet-care-manager, travel-itinerary-planner, vehicle-fleet-manager,
//   parking-reservation, geo-checkin, ar-navigation, smart-home-automation,
//   home-iot-manager, two-factor-auth, encrypted-messaging, oauth-sso-provider,
//   backup-restore, cloud-storage-sync, realtime-presence, notification-preferences,
//   notification-digest, scheduled-notifications, push-notification-manager,
//   discord-notifications, line-notifications, status-page, smart-inbox-triage,
//   smart-search, family-sharing-manager, access-control, rate-limiter-enhanced
//
// GET/POST ?action=<action> or body { action: "..." }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildJournalInsight,
  coerceJournalInsight,
  extractFirstJsonObject,
} from "./journal_analysis.ts";

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
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
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

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function boolBody(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    return !["false", "0", "no", "off"].includes(value.toLowerCase());
  }
  return fallback;
}

const mealTypes = ["breakfast", "lunch", "dinner", "snack"] as const;
type MealType = typeof mealTypes[number];

function isMealType(value: unknown): value is MealType {
  return typeof value === "string" &&
    mealTypes.includes(value as MealType);
}

function optionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function optionalNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function optionalInt(value: unknown): number | null {
  const parsed = optionalNumber(value);
  if (parsed == null) return null;
  return Math.round(parsed);
}

function boundedLimit(value: unknown, fallback = 50, max = 200): number {
  const parsed = optionalInt(value) ?? fallback;
  return Math.min(Math.max(parsed, 1), max);
}

function dateWindowForDay(value: unknown): {
  date: string;
  start: string;
  end: string;
} {
  const date = optionalText(value) ?? dateOnly(new Date());
  const start = new Date(`${date}T00:00:00.000Z`);
  if (Number.isNaN(start.getTime())) {
    throw new Error("invalid date");
  }
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 1);
  return {
    date: dateOnly(start),
    start: start.toISOString(),
    end: end.toISOString(),
  };
}

function dateWindowFromRange(fromValue: unknown, toValue: unknown): {
  start: string;
  end: string;
} {
  const from = dateWindowForDay(fromValue);
  const to = dateWindowForDay(toValue ?? from.date);
  if (Date.parse(from.start) > Date.parse(to.start)) {
    throw new Error("from must be before or equal to to");
  }
  return { start: from.start, end: to.end };
}

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
}

function finiteNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function legacyMealLog(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    food_name: row.food_name ?? row.menu_name ?? "",
    meal_type: row.meal_type ?? "snack",
    calories: Math.round(finiteNumber(row.calories ?? row.kcal)),
    protein_g: roundOne(finiteNumber(row.protein_g)),
    carbs_g: roundOne(finiteNumber(row.carbs_g ?? row.carb_g)),
    fat_g: roundOne(finiteNumber(row.fat_g)),
    logged_at: row.logged_at,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ??
      "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const authHeader = req.headers.get("Authorization") ?? "";
    const userDb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Fitness & Health ─────────────────────────────────────────────────────
      case "fitness.log": {
        const item = await addItem(admin, "fitness_log", userId, {
          activity: body.activity,
          duration_min: body.duration_min,
          calories: body.calories,
          distance_km: body.distance_km,
          notes: body.notes,
          logged_at: new Date().toISOString(),
        });
        return json({ success: true, log: item });
      }
      case "fitness.list":
        return json({
          success: true,
          logs: await listItems(admin, "fitness_log", userId),
          workouts: await listItems(admin, "fitness_log", userId),
        });
      case "fitness.stats": {
        const logs = await listItems(admin, "fitness_log", userId, 200);
        const totalCal = logs.reduce(
          (s, l) =>
            s + Number((l.metadata as Record<string, unknown>)?.calories ?? 0),
          0,
        );
        return json({
          success: true,
          total_sessions: logs.length,
          total_calories: totalCal,
        });
      }
      case "fitness.log_weight": {
        const item = await addItem(admin, "weight_log", userId, {
          weight: body.weight,
          unit: body.unit ?? "kg",
          logged_at: new Date().toISOString(),
        });
        return json({ success: true, log: item });
      }
      case "fitness.list_weight":
        return json({
          success: true,
          weights: await listItems(admin, "weight_log", userId),
        });

      // ── Journal AI feedback ─────────────────────────────────────────────────
      case "journal.list": {
        const limit = Math.min(Math.max(Number(body.limit ?? 30), 1), 100);
        const { data, error } = await admin.from("mental_health_records")
          .select("*")
          .eq("user_id", userId)
          .order("recorded_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, records: data ?? [] });
      }
      case "journal.analyze": {
        const recordId = String(body.record_id ?? "").trim();
        const note = String(body.note ?? "").trim();
        if (!recordId && !note) {
          return json({ error: "note or record_id is required" }, 400);
        }

        const moodScore = Math.max(
          1,
          Math.min(5, Number(body.mood_score ?? 3)),
        );
        const stressScore = Math.max(
          1,
          Math.min(5, Number(body.stress_score ?? 3)),
        );
        const sleepHours = Math.max(
          0,
          Math.min(24, Number(body.sleep_hours ?? 7)),
        );
        const recordedAt = String(body.recorded_at ?? new Date().toISOString());

        let record: Record<string, unknown> | null = null;
        if (recordId) {
          const { data, error } = await admin.from("mental_health_records")
            .select("*")
            .eq("id", recordId)
            .eq("user_id", userId)
            .single();
          if (error || !data) {
            return json({ error: error?.message ?? "record not found" }, 404);
          }
          record = data as Record<string, unknown>;
        } else {
          const { data, error } = await admin.from("mental_health_records")
            .insert({
              user_id: userId,
              mood_score: moodScore,
              stress_score: stressScore,
              sleep_hours: sleepHours,
              note,
              recorded_at: recordedAt,
            })
            .select("*")
            .single();
          if (error) return json({ error: error.message }, 400);
          record = data as Record<string, unknown>;
        }

        const analysisInput = {
          note: String(record.note ?? note),
          moodScore: Number(record.mood_score ?? moodScore),
          stressScore: Number(record.stress_score ?? stressScore),
          sleepHours: Number(record.sleep_hours ?? sleepHours),
        };
        const fallback = buildJournalInsight(analysisInput);
        let insight = fallback;
        let model = "local-journal-heuristic";

        try {
          const aiPrompt = [
            "あなたは日記から自己改善のヒントを抽出するAIです。",
            "出力はJSONのみ。キーは summary, emotion_tags, trigger_tags, next_actions, risk_level, focus_area。",
            "risk_level は low/medium/high。focus_area は spending/health/mental/work/general。",
            "next_actions は明日実行できる15分以内の行動を最大3件。",
            "",
            `気分スコア: ${analysisInput.moodScore}/5`,
            `ストレススコア: ${analysisInput.stressScore}/5`,
            `睡眠時間: ${analysisInput.sleepHours}h`,
            `日記: ${analysisInput.note}`,
          ].join("\n");
          const aiResp = await fetch(`${SUPABASE_URL}/functions/v1/ai-hub`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              action: "provider.chat",
              provider: "groq",
              message: aiPrompt,
            }),
          });
          const aiData = await aiResp.json() as Record<string, unknown>;
          const text = String(aiData.text ?? "");
          if (aiData.success === true && text.trim()) {
            insight = coerceJournalInsight(
              extractFirstJsonObject(text),
              fallback,
            );
            model = String(aiData.model_used ?? "groq");
          }
        } catch {
          insight = fallback;
        }

        const analyzedAt = new Date().toISOString();
        const { data: updated, error: updateError } = await admin
          .from("mental_health_records")
          .update({
            ai_summary: insight.summary,
            emotion_tags: insight.emotion_tags,
            trigger_tags: insight.trigger_tags,
            next_actions: insight.next_actions,
            risk_level: insight.risk_level,
            focus_area: insight.focus_area,
            ai_model: model,
            analyzed_at: analyzedAt,
            analysis_report: {
              ...insight,
              generated_at: analyzedAt,
              source: model,
            },
          })
          .eq("id", String(record.id))
          .eq("user_id", userId)
          .select("*")
          .single();
        if (updateError) return json({ error: updateError.message }, 400);

        const createdTasks: Array<Record<string, unknown>> = [];
        if (boolBody(body.create_tomorrow_tasks, true)) {
          const tomorrow = new Date();
          tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
          const tomorrowDate = dateOnly(tomorrow);
          for (const actionText of insight.next_actions.slice(0, 3)) {
            const { data: task, error: taskError } = await admin
              .from("daily_todos")
              .insert({
                user_id: userId,
                task: actionText,
                is_completed: false,
                is_important: insight.risk_level !== "low",
                category: "journal_ai",
                estimated_minutes: 15,
                difficulty: "easy",
                task_date: tomorrowDate,
                due_date: `${tomorrowDate}T09:00:00.000Z`,
                details:
                  `AI日記分析から生成: ${insight.summary} / record=${record.id}`,
              })
              .select("id, task, task_date, category")
              .single();
            if (!taskError && task) {
              createdTasks.push(task as Record<string, unknown>);
            }
          }
        }

        return json({
          success: true,
          record: updated,
          insight,
          created_tasks: createdTasks,
        });
      }

      // ── Recipe & Meal Planner ─────────────────────────────────────────────────
      case "recipe.list":
        return json({
          success: true,
          recipes: await listItems(admin, "recipe", userId),
        });
      case "recipe.add": {
        const item = await addItem(admin, "recipe", userId, {
          name: body.name,
          ingredients: body.ingredients ?? [],
          instructions: body.instructions,
          prep_min: body.prep_min,
          servings: body.servings ?? 2,
          tags: body.tags ?? [],
        });
        return json({ success: true, recipe: item });
      }
      case "meal.plan": {
        const item = await addItem(admin, "meal_plan", userId, {
          week_start: body.week_start,
          meals: body.meals ?? {},
          notes: body.notes,
        });
        return json({ success: true, plan: item });
      }
      case "meal.list_plans":
        return json({
          success: true,
          plans: await listItems(admin, "meal_plan", userId),
        });
      case "meal.log": {
        if (!isMealType(body.meal_type)) {
          return json({ error: "meal_type is required" }, 400);
        }
        const foodName = optionalText(body.food_name) ??
          optionalText(body.menu_name);
        if (!foodName) {
          return json({ error: "food_name is required" }, 400);
        }
        const loggedAt = optionalText(body.logged_at) ??
          new Date().toISOString();
        if (Number.isNaN(Date.parse(loggedAt))) {
          return json({ error: "logged_at must be an ISO timestamp" }, 400);
        }

        const { data, error } = await userDb.from("meal_logs")
          .insert({
            user_id: userId,
            meal_type: body.meal_type,
            menu_name: foodName,
            kcal: optionalInt(body.calories ?? body.kcal),
            protein_g: optionalNumber(body.protein_g),
            fat_g: optionalNumber(body.fat_g),
            carb_g: optionalNumber(body.carbs_g ?? body.carb_g),
            logged_at: loggedAt,
          })
          .select("*")
          .single();
        if (error) return json({ error: error.message }, 400);
        const log = legacyMealLog(data as Record<string, unknown>);
        return json({ success: true, ok: true, id: data.id, log });
      }
      case "meal.today": {
        let range: { date: string; start: string; end: string };
        try {
          range = dateWindowForDay(body.date);
        } catch (error) {
          return json({ error: String(error) }, 400);
        }
        const { data, error } = await userDb.from("meal_logs")
          .select("meal_type, kcal, protein_g, fat_g, carb_g")
          .eq("user_id", userId)
          .gte("logged_at", range.start)
          .lt("logged_at", range.end);
        if (error) return json({ error: error.message }, 400);

        const byMeal: Record<MealType, number> = {
          breakfast: 0,
          lunch: 0,
          dinner: 0,
          snack: 0,
        };
        let calories = 0;
        let protein = 0;
        let carbs = 0;
        let fat = 0;
        for (const row of data ?? []) {
          const record = row as Record<string, unknown>;
          const mealType = isMealType(record.meal_type)
            ? record.meal_type
            : "snack";
          const rowCalories = finiteNumber(record.kcal);
          byMeal[mealType] += rowCalories;
          calories += rowCalories;
          protein += finiteNumber(record.protein_g);
          carbs += finiteNumber(record.carb_g);
          fat += finiteNumber(record.fat_g);
        }
        return json({
          success: true,
          date: range.date,
          total_calories: Math.round(calories),
          total_protein_g: roundOne(protein),
          total_carbs_g: roundOne(carbs),
          total_fat_g: roundOne(fat),
          by_meal: {
            breakfast: Math.round(byMeal.breakfast),
            lunch: Math.round(byMeal.lunch),
            dinner: Math.round(byMeal.dinner),
            snack: Math.round(byMeal.snack),
          },
        });
      }
      case "meal.list": {
        const limit = boundedLimit(body.limit, 20, 100);
        const { data, error, count } = await userDb.from("meal_logs")
          .select("*", { count: "exact" })
          .eq("user_id", userId)
          .order("logged_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        return json({
          success: true,
          logs: (data ?? []).map((row) =>
            legacyMealLog(row as Record<string, unknown>)
          ),
          total: count ?? data?.length ?? 0,
        });
      }
      case "meal_log.add": {
        if (!isMealType(body.meal_type)) {
          return json({ error: "meal_type is required" }, 400);
        }
        const menuName = optionalText(body.menu_name);
        if (!menuName) {
          return json({ error: "menu_name is required" }, 400);
        }
        const loggedAt = optionalText(body.logged_at) ??
          new Date().toISOString();
        if (Number.isNaN(Date.parse(loggedAt))) {
          return json({ error: "logged_at must be an ISO timestamp" }, 400);
        }

        const { data, error } = await userDb.from("meal_logs")
          .insert({
            user_id: userId,
            meal_type: body.meal_type,
            menu_name: menuName,
            store_name: optionalText(body.store_name),
            kcal: optionalInt(body.kcal),
            protein_g: optionalNumber(body.protein_g),
            fat_g: optionalNumber(body.fat_g),
            carb_g: optionalNumber(body.carb_g),
            vegetables_note: optionalText(body.vegetables_note),
            salt_note: optionalText(body.salt_note),
            logged_at: loggedAt,
          })
          .select("*")
          .single();
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, ok: true, id: data.id, log: data });
      }
      case "meal_log.list": {
        let range: { start: string; end: string };
        try {
          range = dateWindowFromRange(body.from, body.to);
        } catch (error) {
          return json({ error: String(error) }, 400);
        }
        const limit = boundedLimit(body.limit, 50, 200);
        const { data, error, count } = await userDb.from("meal_logs")
          .select("*", { count: "exact" })
          .eq("user_id", userId)
          .gte("logged_at", range.start)
          .lt("logged_at", range.end)
          .order("logged_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        return json({
          success: true,
          logs: data ?? [],
          total: count ?? data?.length ?? 0,
        });
      }
      case "meal_log.summary_today": {
        let range: { date: string; start: string; end: string };
        try {
          range = dateWindowForDay(body.date);
        } catch (error) {
          return json({ error: String(error) }, 400);
        }
        const { data, error } = await userDb.from("meal_logs")
          .select("meal_type, kcal, protein_g, fat_g, carb_g")
          .eq("user_id", userId)
          .gte("logged_at", range.start)
          .lt("logged_at", range.end);
        if (error) return json({ error: error.message }, 400);

        const byMealType: Record<MealType, number> = {
          breakfast: 0,
          lunch: 0,
          dinner: 0,
          snack: 0,
        };
        let kcalTotal = 0;
        let proteinTotal = 0;
        let fatTotal = 0;
        let carbTotal = 0;
        for (const row of data ?? []) {
          const mealType = isMealType(row.meal_type) ? row.meal_type : "snack";
          const kcal = Number(row.kcal ?? 0);
          const protein = Number(row.protein_g ?? 0);
          const fat = Number(row.fat_g ?? 0);
          const carb = Number(row.carb_g ?? 0);
          byMealType[mealType] += Number.isFinite(kcal) ? kcal : 0;
          kcalTotal += Number.isFinite(kcal) ? kcal : 0;
          proteinTotal += Number.isFinite(protein) ? protein : 0;
          fatTotal += Number.isFinite(fat) ? fat : 0;
          carbTotal += Number.isFinite(carb) ? carb : 0;
        }
        return json({
          success: true,
          date: range.date,
          kcal_total: Math.round(kcalTotal),
          protein_g_total: roundOne(proteinTotal),
          fat_g_total: roundOne(fatTotal),
          carb_g_total: roundOne(carbTotal),
          by_meal_type: {
            breakfast: Math.round(byMealType.breakfast),
            lunch: Math.round(byMealType.lunch),
            dinner: Math.round(byMealType.dinner),
            snack: Math.round(byMealType.snack),
          },
        });
      }
      case "meal_log.delete": {
        const id = optionalText(body.id) ?? String(body.id ?? "").trim();
        if (!id) return json({ error: "id is required" }, 400);
        const { data, error } = await userDb.from("meal_logs")
          .delete()
          .eq("id", id)
          .eq("user_id", userId)
          .select("id")
          .maybeSingle();
        if (error) return json({ error: error.message }, 400);
        if (!data) return json({ error: "meal log not found" }, 404);
        return json({ success: true, ok: true });
      }

      // ── Carbon Footprint ──────────────────────────────────────────────────────
      case "carbon.log": {
        const item = await addItem(admin, "carbon_log", userId, {
          category: body.category,
          activity: body.activity,
          kg_co2: body.kg_co2,
          date: body.date ?? new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, log: item });
      }
      case "carbon.list":
        return json({
          success: true,
          records: await listItems(admin, "carbon_log", userId),
        });
      case "carbon.summary": {
        const logs = await listItems(admin, "carbon_log", userId, 365);
        const total = logs.reduce(
          (s, l) =>
            s + Number((l.metadata as Record<string, unknown>)?.kg_co2 ?? 0),
          0,
        );
        return json({
          success: true,
          total_kg_co2: total,
          entries: logs.length,
        });
      }

      // ── Donation / Crowdfunding ───────────────────────────────────────────────
      case "donation.list":
        return json({
          success: true,
          projects: await listItems(admin, "donation_project", userId),
        });
      case "donation.create": {
        const item = await addItem(admin, "donation_project", userId, {
          title: body.title,
          goal_amount: body.goal_amount,
          description: body.description,
          raised_amount: 0,
          status: "active",
        });
        return json({ success: true, project: item });
      }

      // ── Appointments ──────────────────────────────────────────────────────────
      case "appt.list":
        return json({
          success: true,
          appointments: await listItems(admin, "appointment", userId),
        });
      case "appt.create": {
        const item = await addItem(admin, "appointment", userId, {
          title: body.title,
          date: body.date,
          time: body.time,
          location: body.location,
          notes: body.notes,
          status: "scheduled",
        });
        return json({ success: true, appointment: item });
      }

      // ── Pet Care ──────────────────────────────────────────────────────────────
      case "pet.list":
        return json({
          success: true,
          pets: await listItems(admin, "pet", userId),
        });
      case "pet.register": {
        const item = await addItem(admin, "pet", userId, {
          name: body.name,
          species: body.species,
          breed: body.breed,
          birth_date: body.birth_date,
          weight_kg: body.weight_kg,
        });
        return json({ success: true, pet: item });
      }
      case "pet.log_care": {
        const item = await addItem(admin, "pet_care_log", userId, {
          pet_id: body.pet_id,
          type: body.type ?? "feeding",
          notes: body.notes,
          logged_at: new Date().toISOString(),
        });
        return json({ success: true, log: item });
      }
      case "pet.vet_records":
        return json({
          success: true,
          records: await listItems(admin, "vet_record", userId),
        });

      // ── Travel Itinerary ──────────────────────────────────────────────────────
      case "travel.list":
        return json({
          success: true,
          trips: await listItems(admin, "trip", userId),
        });
      case "travel.create": {
        const item = await addItem(admin, "trip", userId, {
          title: body.title,
          destination: body.destination,
          start_date: body.start_date,
          end_date: body.end_date,
          budget: body.budget,
          status: "planning",
        });
        return json({ success: true, trip: item });
      }
      case "travel.add_item": {
        const item = await addItem(admin, "trip_item", userId, {
          trip_id: body.trip_id,
          type: body.type ?? "activity",
          title: body.title,
          date: body.date,
          notes: body.notes,
          booked: body.booked ?? false,
          name: body.name,
          time: body.time,
          day: body.day,
          cost: body.cost,
        });
        return json({ success: true, item });
      }
      case "travel.get_items": {
        const items = await listItems(admin, "trip_item", userId, 200);
        const filtered = body.trip_id
          ? items.filter((i) =>
            (i.metadata as Record<string, unknown>)?.trip_id === body.trip_id
          )
          : items;
        const byType = body.type
          ? filtered.filter((i) =>
            (i.metadata as Record<string, unknown>)?.type === body.type
          )
          : filtered;
        return json({
          success: true,
          items: byType,
          bookings: byType,
          itinerary: byType,
        });
      }
      case "travel.get_budget": {
        const items = await listItems(admin, "trip_item", userId, 200);
        const tripItems = body.trip_id
          ? items.filter((i) =>
            (i.metadata as Record<string, unknown>)?.trip_id === body.trip_id
          )
          : items;
        const total = tripItems.reduce(
          (s, i) =>
            s + Number((i.metadata as Record<string, unknown>)?.cost ?? 0),
          0,
        );
        return json({
          success: true,
          total_cost: total,
          currency: "JPY",
          items: tripItems,
        });
      }

      // ── Vehicle & Fleet ────────────────────────────────────────────────────────
      case "vehicle.list":
        return json({
          success: true,
          vehicles: await listItems(admin, "vehicle", userId),
        });
      case "vehicle.add": {
        const item = await addItem(admin, "vehicle", userId, {
          make: body.make,
          model: body.model,
          year: body.year,
          plate: body.plate,
          mileage_km: body.mileage_km ?? 0,
          fuel_type: body.fuel_type,
        });
        return json({ success: true, vehicle: item });
      }
      case "vehicle.log_service": {
        const item = await addItem(admin, "vehicle_service", userId, {
          vehicle_id: body.vehicle_id,
          type: body.type,
          mileage_km: body.mileage_km,
          cost: body.cost,
          notes: body.notes,
          serviced_at: new Date().toISOString(),
        });
        return json({ success: true, service: item });
      }

      case "vehicle.list_trips":
        return json({
          success: true,
          trips: await listItems(admin, "vehicle_trip", userId),
        });
      case "vehicle.maintenance":
        return json({
          success: true,
          services: await listItems(admin, "vehicle_service", userId),
        });

      // ── Parking Reservation ────────────────────────────────────────────────────
      case "parking.list":
        return json({
          success: true,
          reservations: await listItems(admin, "parking_reservation", userId),
        });
      case "parking.reserve": {
        const item = await addItem(admin, "parking_reservation", userId, {
          lot_id: body.lot_id,
          spot: body.spot,
          start_time: body.start_time,
          end_time: body.end_time,
          plate: body.plate,
          fee: body.fee,
        });
        return json({ success: true, reservation: item });
      }

      // ── Geo Check-in ──────────────────────────────────────────────────────────
      case "checkin.add": {
        const item = await addItem(admin, "geo_checkin", userId, {
          lat: body.lat,
          lng: body.lng,
          place_name: body.place_name,
          category: body.category,
          note: body.note,
        });
        return json({ success: true, checkin: item });
      }
      case "checkin.list":
        return json({
          success: true,
          checkins: await listItems(admin, "geo_checkin", userId),
        });

      // ── AR Navigation ─────────────────────────────────────────────────────────
      case "navigate.save_route": {
        const item = await addItem(admin, "ar_route", userId, {
          from: body.from,
          to: body.to,
          waypoints: body.waypoints ?? [],
          distance_m: body.distance_m,
          mode: body.mode ?? "walking",
        });
        return json({ success: true, route: item });
      }
      case "navigate.list_routes":
        return json({
          success: true,
          routes: await listItems(admin, "ar_route", userId),
        });

      // ── Smart Home / IoT ──────────────────────────────────────────────────────
      case "smarthome.list_devices":
        return json({
          success: true,
          devices: await listItems(admin, "iot_device", userId),
        });
      case "smarthome.add_device": {
        const item = await addItem(admin, "iot_device", userId, {
          name: body.name,
          type: body.type ?? "switch",
          ip: body.ip,
          room: body.room,
          protocol: body.protocol ?? "wifi",
          status: "offline",
        });
        return json({ success: true, device: item });
      }
      case "smarthome.control": {
        const item = await addItem(admin, "iot_command", userId, {
          device_id: body.device_id,
          command: body.command,
          params: body.params ?? {},
          sent_at: new Date().toISOString(),
        });
        return json({ success: true, command: item });
      }
      case "smarthome.automation": {
        const item = await addItem(admin, "iot_automation", userId, {
          name: body.name,
          trigger: body.trigger,
          actions: body.actions ?? [],
          enabled: true,
        });
        return json({ success: true, automation: item });
      }
      case "smarthome.list_automations":
        return json({
          success: true,
          automations: await listItems(admin, "iot_automation", userId),
        });

      // ── 2FA ───────────────────────────────────────────────────────────────────
      case "2fa.setup": {
        const secret = crypto.randomUUID().replace(/-/g, "").slice(0, 32)
          .toUpperCase();
        const item = await addItem(admin, "2fa_setup", userId, {
          secret_hint: secret.slice(0, 4) + "****",
          method: body.method ?? "totp",
          enabled: false,
        });
        return json({ success: true, setup: item, secret });
      }
      case "2fa.enable": {
        const backupCodes = Array.from(
          { length: 8 },
          () => Math.random().toString(36).slice(2, 10).toUpperCase(),
        );
        await addItem(admin, "2fa_setup", userId, {
          method: body.method ?? "totp",
          enabled: true,
          backup_codes: backupCodes,
        });
        return json({ success: true, backupCodes });
      }
      case "2fa.disable": {
        await admin.from("hub_data").delete().eq("source", "2fa_setup").eq(
          "user_id",
          userId,
        );
        return json({ success: true });
      }
      case "2fa.verify": {
        const item = await addItem(admin, "2fa_attempt", userId, {
          method: body.method ?? "totp",
          success: body.success ?? true,
          attempted_at: new Date().toISOString(),
        });
        return json({
          success: true,
          verified: body.success ?? true,
          attempt: item,
        });
      }
      case "2fa.status": {
        const setups = await listItems(admin, "2fa_setup", userId, 1);
        return json({
          success: true,
          enabled: setups.length > 0,
          method: (setups[0]?.metadata as Record<string, unknown>)?.method,
        });
      }
      case "2fa.list_devices":
        return json({
          success: true,
          devices: await listItems(admin, "trusted_device", userId),
        });
      case "2fa.revoke_device": {
        if (!body.deviceId) return json({ error: "deviceId required" }, 400);
        await admin.from("hub_data").delete().eq("id", String(body.deviceId))
          .eq("user_id", userId);
        return json({ success: true });
      }

      // ── Encrypted Messaging ────────────────────────────────────────────────────
      case "encrypt.send": {
        const msgId = crypto.randomUUID();
        const item = await addItem(admin, "encrypted_msg", userId, {
          msg_id: msgId,
          to: body.to,
          ciphertext: body.ciphertext,
          algorithm: body.algorithm ?? "AES-256",
          sent_at: new Date().toISOString(),
        });
        return json({ success: true, msg_id: msgId, message: item });
      }
      case "encrypt.inbox":
        return json({
          success: true,
          messages: await listItems(admin, "encrypted_msg", userId),
        });

      // ── OAuth / SSO ────────────────────────────────────────────────────────────
      case "oauth.list_providers": {
        const providers = [
          "google",
          "github",
          "apple",
          "twitter",
          "facebook",
          "discord",
          "slack",
        ];
        const configured = providers.filter((p) =>
          Deno.env.get(`${p.toUpperCase()}_CLIENT_ID`)
        );
        return json({
          success: true,
          providers: configured,
          all_providers: providers,
        });
      }
      case "oauth.log_event": {
        const item = await addItem(admin, "oauth_event", userId, {
          provider: body.provider,
          event: body.event,
          success: body.success ?? true,
          occurred_at: new Date().toISOString(),
        });
        return json({ success: true, event: item });
      }

      // ── Backup & Restore ──────────────────────────────────────────────────────
      case "backup.create": {
        const backupId = crypto.randomUUID();
        const item = await addItem(admin, "backup_record", userId, {
          backup_id: backupId,
          type: body.type ?? "full",
          size_bytes: body.size_bytes,
          storage_url: body.storage_url,
          created_at: new Date().toISOString(),
        });
        return json({ success: true, backup_id: backupId, record: item });
      }
      case "backup.list":
        return json({
          success: true,
          backups: await listItems(admin, "backup_record", userId),
        });
      case "backup.restore": {
        const item = await addItem(admin, "restore_record", userId, {
          backup_id: body.backup_id,
          status: "started",
          started_at: new Date().toISOString(),
        });
        return json({ success: true, restore: item });
      }

      // ── Cloud Storage Sync ────────────────────────────────────────────────────
      case "storage.list":
        return json({
          success: true,
          files: await listItems(admin, "cloud_file", userId),
        });
      case "storage.add": {
        const item = await addItem(admin, "cloud_file", userId, {
          path: body.path,
          name: body.name,
          size_bytes: body.size_bytes,
          mime_type: body.mime_type,
          provider: body.provider ?? "supabase",
        });
        return json({ success: true, file: item });
      }
      case "storage.sync": {
        const item = await addItem(admin, "storage_sync", userId, {
          provider: body.provider,
          synced_count: body.synced_count ?? 0,
          synced_at: new Date().toISOString(),
        });
        return json({ success: true, sync: item });
      }

      // ── Realtime Presence ─────────────────────────────────────────────────────
      case "presence.update": {
        const item = await addItem(admin, "presence", userId, {
          status: body.status ?? "online",
          room: body.room,
          custom: body.custom,
          updated_at: new Date().toISOString(),
        });
        return json({ success: true, presence: item });
      }
      case "presence.list_room": {
        const cutoff = new Date(Date.now() - 5 * 60000).toISOString();
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "presence")
          .filter("metadata->>room", "eq", String(body.room ?? ""))
          .gte("created_at", cutoff);
        return json({ success: true, online: data ?? [] });
      }

      // ── Notification Preferences ──────────────────────────────────────────────
      case "notif_pref.get": {
        const prefs = await listItems(admin, "notification_pref", userId, 1);
        const defaultPrefs = {
          email: true,
          push: true,
          sms: false,
          discord: false,
          line: false,
        };
        return json({
          success: true,
          preferences: prefs[0]?.metadata ?? defaultPrefs,
        });
      }
      case "notif_pref.set": {
        const item = await addItem(admin, "notification_pref", userId, {
          email: body.email ?? true,
          push: body.push ?? true,
          sms: body.sms ?? false,
          discord: body.discord ?? false,
          line: body.line ?? false,
          updated_at: new Date().toISOString(),
        });
        return json({ success: true, preferences: item });
      }

      // ── Notification Digest ───────────────────────────────────────────────────
      case "digest.list":
        return json({
          success: true,
          digests: await listItems(admin, "notification_digest", userId),
        });
      case "digest.create": {
        const item = await addItem(admin, "notification_digest", userId, {
          summary: body.summary,
          items: body.items ?? [],
          period: body.period ?? "daily",
          sent_at: new Date().toISOString(),
        });
        return json({ success: true, digest: item });
      }

      // ── Scheduled Notifications ───────────────────────────────────────────────
      case "scheduled_notif.list":
        return json({
          success: true,
          notifications: await listItems(admin, "scheduled_notif", userId),
        });
      case "scheduled_notif.create": {
        const item = await addItem(admin, "scheduled_notif", userId, {
          title: body.title,
          body: body.body,
          schedule_at: body.schedule_at,
          channel: body.channel ?? "push",
          status: "pending",
        });
        return json({ success: true, notification: item });
      }
      case "scheduled_notif.cancel": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "cancelled" } })
          .eq("id", String(body.id ?? "")).eq("source", "scheduled_notif");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Push Notification Manager ─────────────────────────────────────────────
      case "push.register": {
        const item = await addItem(admin, "push_token", userId, {
          token: body.token,
          platform: body.platform ?? "web",
          active: true,
        });
        return json({ success: true, registered: item });
      }
      case "push.send": {
        const item = await addItem(admin, "push_event", userId, {
          title: body.title,
          body: body.body,
          data: body.data,
          sent_at: new Date().toISOString(),
        });
        return json({ success: true, sent: item });
      }

      // ── Discord Notifications ─────────────────────────────────────────────────
      case "discord.send": {
        const webhookUrl = String(
          body.webhook_url ?? Deno.env.get("DISCORD_WEBHOOK_URL") ?? "",
        );
        if (!webhookUrl) return json({ error: "No webhook URL provided" }, 400);
        const res = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            content: body.message,
            username: body.username ?? "自分株式会社",
          }),
        });
        const ok = res.status < 400;
        await addItem(admin, "discord_send", userId, {
          message: body.message,
          success: ok,
          sent_at: new Date().toISOString(),
        });
        return json({ success: ok, http_status: res.status });
      }
      case "discord.history":
        return json({
          success: true,
          history: await listItems(admin, "discord_send", userId),
        });
      case "discord.get_config": {
        const { data } = await admin.from("hub_data")
          .select("metadata").eq("source", "discord_config").eq(
            "user_id",
            userId,
          )
          .order("created_at", { ascending: false }).limit(1).maybeSingle();
        const cfg = (data?.metadata ?? {}) as Record<string, unknown>;
        return json({
          success: true,
          webhook_url: cfg.webhook_url ?? "",
          triggers: cfg.triggers ?? [],
        });
      }
      case "discord.configure": {
        const existing = await admin.from("hub_data")
          .select("id").eq("source", "discord_config").eq("user_id", userId)
          .limit(1).maybeSingle();
        const meta = {
          webhook_url: body.webhook_url,
          triggers: body.triggers ?? [],
          updated_at: new Date().toISOString(),
        };
        if (existing.data?.id) {
          await admin.from("hub_data").update({ metadata: meta }).eq(
            "id",
            existing.data.id,
          );
        } else {
          await addItem(admin, "discord_config", userId, meta);
        }
        return json({ success: true });
      }
      case "discord.test": {
        const { data } = await admin.from("hub_data")
          .select("metadata").eq("source", "discord_config").eq(
            "user_id",
            userId,
          )
          .order("created_at", { ascending: false }).limit(1).maybeSingle();
        const webhookUrl = String(
          (data?.metadata as Record<string, unknown>)?.webhook_url ??
            body.webhook_url ?? "",
        );
        if (!webhookUrl) {
          return json({
            success: false,
            message: "Webhook URL が設定されていません",
          });
        }
        const res = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            content: "🔔 自分株式会社 Discord通知テスト",
            username: "自分株式会社",
          }),
        });
        return json({
          success: res.status < 400,
          message: res.status < 400
            ? "テスト通知を送信しました"
            : "送信に失敗しました",
        });
      }

      // ── LINE Notifications ────────────────────────────────────────────────────
      case "line.send": {
        const token = String(
          body.token ?? Deno.env.get("LINE_NOTIFY_TOKEN") ?? "",
        );
        if (!token) {
          return json({ error: "LINE_NOTIFY_TOKEN not configured" }, 400);
        }
        const formData = new FormData();
        formData.append("message", String(body.message ?? ""));
        const res = await fetch("https://notify-api.line.me/api/notify", {
          method: "POST",
          headers: { Authorization: `Bearer ${token}` },
          body: formData,
        });
        const ok = res.status < 400;
        return json({ success: ok, http_status: res.status });
      }
      case "line.get_config": {
        const { data } = await admin.from("hub_data")
          .select("metadata").eq("source", "line_config").eq("user_id", userId)
          .order("created_at", { ascending: false }).limit(1).maybeSingle();
        const cfg = (data?.metadata ?? {}) as Record<string, unknown>;
        return json({
          success: true,
          token: cfg.token ?? "",
          triggers: cfg.triggers ?? [],
        });
      }
      case "line.configure": {
        const existing = await admin.from("hub_data")
          .select("id").eq("source", "line_config").eq("user_id", userId).limit(
            1,
          ).maybeSingle();
        const meta = {
          token: body.token,
          triggers: body.triggers ?? [],
          updated_at: new Date().toISOString(),
        };
        if (existing.data?.id) {
          await admin.from("hub_data").update({ metadata: meta }).eq(
            "id",
            existing.data.id,
          );
        } else {
          await addItem(admin, "line_config", userId, meta);
        }
        return json({ success: true });
      }
      case "line.test": {
        const { data } = await admin.from("hub_data")
          .select("metadata").eq("source", "line_config").eq("user_id", userId)
          .order("created_at", { ascending: false }).limit(1).maybeSingle();
        const token = String(
          (data?.metadata as Record<string, unknown>)?.token ?? body.token ??
            "",
        );
        if (!token) {
          return json({
            success: false,
            message: "LINE Notify トークンが設定されていません",
          });
        }
        const formData = new FormData();
        formData.append("message", "\n🔔 自分株式会社 LINE通知テスト");
        const res = await fetch("https://notify-api.line.me/api/notify", {
          method: "POST",
          headers: { Authorization: `Bearer ${token}` },
          body: formData,
        });
        return json({
          success: res.status < 400,
          message: res.status < 400
            ? "テスト通知を送信しました"
            : "送信に失敗しました",
        });
      }

      // ── Status Page ───────────────────────────────────────────────────────────
      case "status.get": {
        const checks = [
          {
            service: "Supabase DB",
            url: `${SUPABASE_URL}/rest/v1/`,
            expected: 200,
          },
          {
            service: "Edge Functions",
            url: `${SUPABASE_URL}/functions/v1/health-check`,
            expected: 200,
          },
        ];
        const results = await Promise.all(checks.map(async (c) => {
          const res = await fetch(c.url, {
            headers: { apikey: SUPABASE_ANON_KEY },
          }).catch(() => null);
          return {
            service: c.service,
            status: res?.ok ? "operational" : "degraded",
            http: res?.status ?? 0,
          };
        }));
        return json({
          success: true,
          status: results.every((r) => r.status === "operational")
            ? "operational"
            : "degraded",
          services: results,
        });
      }
      case "status.log_incident": {
        const item = await addItem(admin, "status_incident", userId, {
          service: body.service,
          severity: body.severity ?? "minor",
          description: body.description,
          started_at: new Date().toISOString(),
        });
        return json({ success: true, incident: item });
      }

      // ── Smart Inbox Triage ─────────────────────────────────────────────────────
      case "inbox.list":
        return json({
          success: true,
          items: await listItems(admin, "inbox_item", userId),
        });
      case "inbox.add": {
        const item = await addItem(admin, "inbox_item", userId, {
          subject: body.subject,
          from: body.from,
          preview: body.preview,
          priority: body.priority ?? "normal",
          category: body.category ?? "inbox",
        });
        return json({ success: true, item });
      }
      case "inbox.triage": {
        const items = await listItems(admin, "inbox_item", userId);
        const urgent = items.filter((i) =>
          (i.metadata as Record<string, unknown>)?.priority === "urgent"
        );
        return json({
          success: true,
          urgent: urgent.length,
          total: items.length,
          items: urgent.slice(0, 10),
        });
      }

      // ── Smart Search ──────────────────────────────────────────────────────────
      case "search.query": {
        const q = String(body.query ?? "");
        const { data } = await admin.from("hub_data")
          .select("id, source, metadata, created_at")
          .ilike("metadata->>title", `%${q}%`)
          .limit(30);
        const results = (data ?? []).concat();
        await addItem(admin, "search_history", userId, {
          query: q,
          results_count: results.length,
        });
        return json({ success: true, query: q, results });
      }
      case "search.history":
        return json({
          success: true,
          history: await listItems(admin, "search_history", userId, 20),
        });

      // ── Family Sharing ────────────────────────────────────────────────────────
      case "family.list":
        return json({
          success: true,
          members: await listItems(admin, "family_member", userId),
        });
      case "family.add_member": {
        const item = await addItem(admin, "family_member", userId, {
          name: body.name,
          email: body.email,
          role: body.role ?? "member",
          relation: body.relation,
          invited_at: new Date().toISOString(),
        });
        return json({ success: true, member: item });
      }
      case "family.share_item": {
        const item = await addItem(admin, "family_shared", userId, {
          item_type: body.item_type,
          item_id: body.item_id,
          shared_with: body.shared_with,
          shared_at: new Date().toISOString(),
        });
        return json({ success: true, share: item });
      }

      // ── Real Estate Tracker ───────────────────────────────────────────────────
      case "realestate.list": {
        const items = await listItems(
          admin,
          "realestate_property",
          userId,
          100,
        );
        const properties = items.map((i) => ({
          property_id: i.id,
          ...(i.metadata as Record<string, unknown>),
        }));
        return json({ success: true, properties });
      }
      case "realestate.register": {
        const item = await addItem(admin, "realestate_property", userId, {
          name: body.name,
          property_type: body.property_type ?? "apartment",
          address: body.address ?? "",
          purchase_price: body.purchase_price ?? 0,
          area_sqm: body.area_sqm ?? null,
          registered_at: new Date().toISOString(),
        });
        return json({ success: true, property: item });
      }
      case "realestate.stats": {
        const props = await listItems(
          admin,
          "realestate_property",
          userId,
          100,
        );
        const txns = await listItems(admin, "realestate_txn", userId, 1000);
        const totalProperties = props.length;
        const totalIncome = txns.reduce((s, t) => {
          const meta = t.metadata as Record<string, unknown>;
          const type = String(meta?.type ?? "");
          return type === "rent_income" || type === "other_income"
            ? s + Number(meta?.amount ?? 0)
            : s;
        }, 0);
        const totalExpense = txns.reduce((s, t) => {
          const meta = t.metadata as Record<string, unknown>;
          const type = String(meta?.type ?? "");
          return type !== "rent_income" && type !== "other_income"
            ? s + Number(meta?.amount ?? 0)
            : s;
        }, 0);
        return json({
          success: true,
          stats: {
            totalProperties,
            totalIncome,
            totalExpense,
            netIncome: totalIncome - totalExpense,
          },
        });
      }
      case "realestate.finances": {
        const propertyId = String(body.property_id ?? "");
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "realestate_txn")
          .filter("metadata->>property_id", "eq", propertyId)
          .order("created_at", { ascending: false }).limit(100);
        return json({
          success: true,
          transactions: (data ?? []).map((t) => ({
            ...(t.metadata as Record<string, unknown>),
            id: t.id,
          })),
        });
      }
      case "realestate.record_txn": {
        const item = await addItem(admin, "realestate_txn", userId, {
          property_id: body.property_id,
          type: body.type ?? "other_expense",
          amount: body.amount ?? 0,
          description: body.description ?? "",
          date: body.date ?? new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, transaction: item });
      }

      // ── Access Control ─────────────────────────────────────────────────────────
      case "access.list_roles":
        return json({
          success: true,
          roles: await listItems(admin, "access_role", userId),
        });
      case "access.create_role": {
        const item = await addItem(admin, "access_role", userId, {
          name: body.name,
          permissions: body.permissions ?? [],
          description: body.description,
        });
        return json({ success: true, role: item });
      }
      case "access.check": {
        const roles = await listItems(admin, "access_role", userId, 100);
        const hasPermission = roles.some((r) => {
          const perms = ((r.metadata as Record<string, unknown>)
            ?.permissions as string[]) ?? [];
          return perms.includes(String(body.permission ?? ""));
        });
        return json({
          success: true,
          allowed: hasPermission,
          permission: body.permission,
        });
      }
      case "access.list_access_logs":
        return json({
          success: true,
          logs: await listItems(admin, "access_log", userId),
        });
      case "access.log_event": {
        const item = await addItem(admin, "access_log", userId, {
          resource: body.resource,
          action: body.event_action,
          allowed: body.allowed ?? true,
          ip: body.ip,
          logged_at: new Date().toISOString(),
        });
        return json({ success: true, log: item });
      }

      // ── Rate Limiter Enhanced ──────────────────────────────────────────────────
      case "ratelimit.check": {
        const key = String(body.key ?? userId);
        const window_sec = Number(body.window_sec ?? 60);
        const limit = Number(body.limit ?? 100);
        const since = new Date(Date.now() - window_sec * 1000).toISOString();
        const { count } = await admin.from("hub_data")
          .select("*", { count: "exact", head: true })
          .eq("source", "rate_limit_hit")
          .filter("metadata->>key", "eq", key)
          .gte("created_at", since);
        const current = count ?? 0;
        const allowed = current < limit;
        if (allowed) {
          await addItem(admin, "rate_limit_hit", userId, { key, window_sec });
        }
        return json({
          success: true,
          allowed,
          current,
          limit,
          remaining: Math.max(0, limit - current),
        });
      }

      // ── Price Tracker (Win版#131 / NotebookLM d6dd44af) ───────────────────────
      // 既存 hub_data ではなく専用テーブル tracked_products + price_logs を使用
      case "price.add": {
        const url = String(body.product_url ?? "").trim();
        if (!url) return json({ error: "product_url is required" }, 400);
        const storeDomain = (() => {
          try {
            return new URL(url).hostname.replace(/^www\./, "");
          } catch {
            return "";
          }
        })();
        const { data, error } = await admin.from("tracked_products").insert({
          user_id: userId,
          product_url: url,
          product_name: String(body.product_name ?? "").trim(),
          store_domain: storeDomain,
          image_url: body.image_url ?? null,
          target_price: body.target_price ?? null,
          current_price: body.current_price ?? null,
          highest_price: body.current_price ?? null,
          lowest_price: body.current_price ?? null,
          notify_on_drop: body.notify_on_drop !== false,
          note: body.note ?? "",
        }).select().single();
        if (error) return json({ error: error.message }, 400);
        if (body.current_price != null) {
          await admin.from("price_logs").insert({
            product_id: data.id,
            user_id: userId,
            price: body.current_price,
            source: "manual",
          });
        }
        return json({ success: true, product: data });
      }
      case "price.list": {
        const onlyActive = body.only_active !== false;
        let query = admin.from("tracked_products")
          .select("*")
          .eq("user_id", userId)
          .order("updated_at", { ascending: false });
        if (onlyActive) {
          query = query.eq("is_active", true).eq("is_purchased", false);
        }
        const { data, error } = await query;
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, products: data ?? [] });
      }
      case "price.log": {
        const productId = String(body.product_id ?? "");
        const price = Number(body.price);
        if (!productId || !Number.isFinite(price)) {
          return json({ error: "product_id and price are required" }, 400);
        }
        const { data, error } = await admin.from("price_logs").insert({
          product_id: productId,
          user_id: userId,
          price,
          in_stock: body.in_stock !== false,
          source: String(body.source ?? "manual"),
        }).select().single();
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, log: data });
      }
      case "price.history": {
        const productId = String(body.product_id ?? "");
        if (!productId) return json({ error: "product_id is required" }, 400);
        const limit = Math.min(Number(body.limit ?? 200), 1000);
        const { data, error } = await admin.from("price_logs")
          .select("price, in_stock, source, fetched_at")
          .eq("product_id", productId)
          .eq("user_id", userId)
          .order("fetched_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, logs: (data ?? []).reverse() });
      }
      case "price.update_target": {
        const productId = String(body.product_id ?? "");
        if (!productId) return json({ error: "product_id is required" }, 400);
        const { data, error } = await admin.from("tracked_products")
          .update({
            target_price: body.target_price ?? null,
            notify_on_drop: body.notify_on_drop !== false,
            updated_at: new Date().toISOString(),
          })
          .eq("id", productId).eq("user_id", userId)
          .select().single();
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, product: data });
      }
      case "price.mark_purchased": {
        const productId = String(body.product_id ?? "");
        const purchasedPrice = body.purchased_price != null
          ? Number(body.purchased_price)
          : null;
        if (!productId) return json({ error: "product_id is required" }, 400);
        const { data, error } = await admin.from("tracked_products")
          .update({
            is_purchased: true,
            purchased_at: new Date().toISOString(),
            purchased_price: purchasedPrice,
            updated_at: new Date().toISOString(),
          })
          .eq("id", productId).eq("user_id", userId)
          .select().single();
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, product: data });
      }
      case "price.delete": {
        const productId = String(body.product_id ?? "");
        if (!productId) return json({ error: "product_id is required" }, 400);
        const { error } = await admin.from("tracked_products")
          .delete().eq("id", productId).eq("user_id", userId);
        if (error) return json({ error: error.message }, 400);
        return json({ success: true });
      }
      case "price.alerts": {
        // target_price 達成中のアクティブ商品を返す (フロント表示用)
        const { data, error } = await admin.from("tracked_products")
          .select("*")
          .eq("user_id", userId)
          .eq("is_active", true)
          .eq("is_purchased", false)
          .eq("notify_on_drop", true)
          .not("target_price", "is", null)
          .not("current_price", "is", null);
        if (error) return json({ error: error.message }, 400);
        const alerts = (data ?? []).filter((p) =>
          typeof p.current_price === "number" &&
          typeof p.target_price === "number" &&
          p.current_price <= p.target_price
        );
        return json({ success: true, alerts });
      }
      case "price.advise": {
        // AI 購入アドバイザー (Win版#131 Phase 2 / NotebookLM 提案 #7)
        // 価格履歴 + 目標価格 → ai-hub:provider.chat (Groq 無料枠) で「買い時」助言
        // PHILOSOPHY 9 原則: 3 (mentor) + 8 (KPI=昨日の自分=最安比較) + 6 (時間=即決支援)
        const productId = String(body.product_id ?? "");
        if (!productId) return json({ error: "product_id is required" }, 400);
        const { data: product, error: pErr } = await admin
          .from("tracked_products")
          .select("*")
          .eq("id", productId)
          .eq("user_id", userId)
          .single();
        if (pErr || !product) {
          return json({ error: pErr?.message ?? "product not found" }, 404);
        }
        const { data: logs, error: lErr } = await admin
          .from("price_logs")
          .select("price, fetched_at")
          .eq("product_id", productId)
          .eq("user_id", userId)
          .order("fetched_at", { ascending: false })
          .limit(30);
        if (lErr) return json({ error: lErr.message }, 400);
        const series = (logs ?? []).map((l) =>
          `${l.fetched_at?.slice(0, 10)}: ¥${l.price}`
        ).join(" / ");
        const prompt = `商品: ${product.product_name}\n` +
          `現在価格: ¥${product.current_price ?? "?"}\n` +
          `目標価格: ¥${product.target_price ?? "なし"}\n` +
          `史上最安: ¥${product.lowest_price ?? "?"}\n` +
          `史上最高: ¥${product.highest_price ?? "?"}\n` +
          `直近30件: ${series || "履歴なし"}\n\n` +
          `この商品を「今買うべき」か「待つべき」か、200字以内で判断理由付きで答えてください。` +
          `「今買うべき」なら理由 (例: 史上最安・目標達成・在庫薄)。` +
          `「待つべき」なら根拠 (例: セール直前・下落トレンド)。`;
        try {
          const aiResp = await fetch(
            `${SUPABASE_URL}/functions/v1/ai-hub`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                action: "provider.chat",
                provider: "groq",
                message: prompt,
              }),
            },
          );
          const aiData = await aiResp.json() as Record<string, unknown>;
          if (aiData.success === true) {
            return json({
              success: true,
              advice: String(aiData.text ?? ""),
              model: String(aiData.model_used ?? "groq:llama-3.3-70b"),
            });
          }
          return json({
            success: false,
            advice: "AI助言が現在利用できません (Groq APIキー未設定の可能性)",
            detail: aiData,
          }, 200);
        } catch (e) {
          return json({
            success: false,
            advice: "AI助言取得エラー",
            error: String(e),
          }, 200);
        }
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
