// Virtual Pet Edge Function
// バーチャルペット (たまごっち/ポケモン/どうぶつの森競合)
// - ペット育成
// - エサ・お世話
// - ステータス管理
// - ミニゲーム
// - ペットショップ

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PET_TYPES = [
  { id: "cat", name: "ネコ", emoji: "🐱", baseStats: { hunger: 50, happiness: 60, energy: 70 } },
  { id: "dog", name: "イヌ", emoji: "🐶", baseStats: { hunger: 60, happiness: 70, energy: 80 } },
  { id: "rabbit", name: "ウサギ", emoji: "🐰", baseStats: { hunger: 40, happiness: 50, energy: 60 } },
  { id: "bird", name: "トリ", emoji: "🐦", baseStats: { hunger: 30, happiness: 65, energy: 90 } },
  { id: "hamster", name: "ハムスター", emoji: "🐹", baseStats: { hunger: 35, happiness: 55, energy: 75 } },
  { id: "dragon", name: "ドラゴン", emoji: "🐲", baseStats: { hunger: 80, happiness: 40, energy: 100 } },
  { id: "penguin", name: "ペンギン", emoji: "🐧", baseStats: { hunger: 45, happiness: 60, energy: 50 } },
  { id: "unicorn", name: "ユニコーン", emoji: "🦄", baseStats: { hunger: 50, happiness: 80, energy: 90 } },
];

const FOOD_ITEMS = [
  { id: "kibble", name: "ドライフード", cost: 10, hungerRestore: 20, happinessBoost: 5 },
  { id: "treat", name: "おやつ", cost: 20, hungerRestore: 10, happinessBoost: 15 },
  { id: "premium_meal", name: "プレミアムごはん", cost: 50, hungerRestore: 40, happinessBoost: 20 },
  { id: "special_feast", name: "ごちそう", cost: 100, hungerRestore: 60, happinessBoost: 30 },
];

const ACTIVITIES = [
  { id: "play", name: "遊ぶ", energyCost: 15, happinessGain: 20, xpGain: 10 },
  { id: "walk", name: "散歩", energyCost: 20, happinessGain: 15, xpGain: 15 },
  { id: "train", name: "トレーニング", energyCost: 25, happinessGain: 10, xpGain: 25 },
  { id: "sleep", name: "お昼寝", energyCost: -40, happinessGain: 5, xpGain: 5 },
  { id: "bath", name: "お風呂", energyCost: 10, happinessGain: 10, xpGain: 5 },
];

function calculateLevel(xp: number): { level: number; xpToNext: number } {
  let level = 1;
  let xpNeeded = 100;
  let totalXp = 0;
  while (totalXp + xpNeeded <= xp) {
    totalXp += xpNeeded;
    level++;
    xpNeeded = Math.floor(xpNeeded * 1.3);
  }
  return { level, xpToNext: xpNeeded - (xp - totalXp) };
}

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

      if (view === "config") return new Response(JSON.stringify({ success: true, petTypes: PET_TYPES, foodItems: FOOD_ITEMS, activities: ACTIVITIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "my_pets") {
        const { data: pets } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "virtual_pet").order("created_at", { ascending: false });
        const petsWithDecay = (pets ?? []).map((p) => {
          const m = p.metadata as Record<string, unknown>;
          const lastCare = new Date((m.last_care_at as string) ?? p.created_at).getTime();
          const hoursSince = (Date.now() - lastCare) / 3600000;
          const hungerDecay = Math.min(100, Math.floor(hoursSince * 3));
          const happinessDecay = Math.min(100, Math.floor(hoursSince * 2));
          return {
            ...m,
            hunger: Math.max(0, ((m.hunger as number) ?? 50) - hungerDecay),
            happiness: Math.max(0, ((m.happiness as number) ?? 50) - happinessDecay),
            level: calculateLevel((m.xp as number) ?? 0),
            createdAt: p.created_at,
          };
        });
        return new Response(JSON.stringify({ success: true, pets: petsWithDecay }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "leaderboard") {
        const { data: all } = await adminClient.from("app_analytics").select("metadata, user_id").eq("source", "virtual_pet");
        const userBest: Record<string, { xp: number; petName: string; petType: string }> = {};
        for (const p of all ?? []) {
          const m = p.metadata as Record<string, unknown>;
          const xp = (m.xp as number) ?? 0;
          if (!userBest[p.user_id] || xp > userBest[p.user_id].xp) {
            userBest[p.user_id] = { xp, petName: (m.name as string) ?? "", petType: (m.pet_type as string) ?? "" };
          }
        }
        const leaderboard = Object.entries(userBest).map(([uid, data]) => ({ userId: uid, ...data, level: calculateLevel(data.xp).level })).sort((a, b) => b.xp - a.xp).slice(0, 20);
        return new Response(JSON.stringify({ success: true, leaderboard }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, petTypes: PET_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "adopt") {
        const { pet_type, name } = body;
        if (!pet_type || !name) return new Response(JSON.stringify({ success: false, error: "pet_type and name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const petDef = PET_TYPES.find((p) => p.id === pet_type);
        if (!petDef) return new Response(JSON.stringify({ success: false, error: "Unknown pet_type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const petId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "virtual_pet",
          metadata: { pet_id: petId, name, pet_type, emoji: petDef.emoji, ...petDef.baseStats, xp: 0, coins: 100, last_care_at: new Date().toISOString(), adopted_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, petId, pet: { name, type: pet_type, emoji: petDef.emoji } }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "feed") {
        const { pet_id, food_id } = body;
        if (!pet_id || !food_id) return new Response(JSON.stringify({ success: false, error: "pet_id and food_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const food = FOOD_ITEMS.find((f) => f.id === food_id);
        if (!food) return new Response(JSON.stringify({ success: false, error: "Unknown food" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: pet } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "virtual_pet").eq("metadata->>pet_id", pet_id).maybeSingle();
        if (!pet) return new Response(JSON.stringify({ success: false, error: "Pet not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = pet.metadata as Record<string, unknown>;
        const coins = (m.coins as number) ?? 0;
        if (coins < food.cost) return new Response(JSON.stringify({ success: false, error: "コイン不足" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({
          metadata: { ...m, hunger: Math.min(100, ((m.hunger as number) ?? 0) + food.hungerRestore), happiness: Math.min(100, ((m.happiness as number) ?? 0) + food.happinessBoost), coins: coins - food.cost, last_care_at: new Date().toISOString() },
        }).eq("user_id", user.id).eq("source", "virtual_pet").eq("metadata->>pet_id", pet_id);
        return new Response(JSON.stringify({ success: true, fed: food.name }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "activity") {
        const { pet_id, activity_id } = body;
        if (!pet_id || !activity_id) return new Response(JSON.stringify({ success: false, error: "pet_id and activity_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const act = ACTIVITIES.find((a) => a.id === activity_id);
        if (!act) return new Response(JSON.stringify({ success: false, error: "Unknown activity" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: pet } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "virtual_pet").eq("metadata->>pet_id", pet_id).maybeSingle();
        if (!pet) return new Response(JSON.stringify({ success: false, error: "Pet not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = pet.metadata as Record<string, unknown>;
        const energy = (m.energy as number) ?? 50;
        if (act.energyCost > 0 && energy < act.energyCost) return new Response(JSON.stringify({ success: false, error: "エネルギー不足" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const newXp = ((m.xp as number) ?? 0) + act.xpGain;
        const coinsEarned = act.xpGain;
        await adminClient.from("app_analytics").update({
          metadata: { ...m, energy: Math.min(100, Math.max(0, energy - act.energyCost)), happiness: Math.min(100, ((m.happiness as number) ?? 0) + act.happinessGain), xp: newXp, coins: ((m.coins as number) ?? 0) + coinsEarned, last_care_at: new Date().toISOString() },
        }).eq("user_id", user.id).eq("source", "virtual_pet").eq("metadata->>pet_id", pet_id);
        return new Response(JSON.stringify({ success: true, activity: act.name, xpGained: act.xpGain, coinsEarned, level: calculateLevel(newXp) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
