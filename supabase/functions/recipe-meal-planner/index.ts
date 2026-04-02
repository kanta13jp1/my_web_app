// Recipe & Meal Planner Edge Function
// レシピ・食事プランナー (Amazon Fresh/Liven競合)
// - レシピ登録・管理
// - 週間献立計画
// - 買い物リスト自動生成
// - 栄養計算
// - カテゴリ・タグ管理
//
// GET  → レシピ一覧 / 献立 / 買い物リスト / 栄養統計
// POST → レシピ作成 / 献立設定 / 買い物リスト生成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"];
const RECIPE_CATEGORIES = ["和食", "洋食", "中華", "イタリアン", "フレンチ", "エスニック", "デザート", "ドリンク", "その他"];

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

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, mealTypes: MEAL_TYPES, categories: RECIPE_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "meal_plan") {
        const weekStart = url.searchParams.get("week_start") ?? new Date().toISOString().substring(0, 10);
        const { data: plans } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "meal_plan").eq("metadata->>week_start", weekStart);
        return new Response(JSON.stringify({
          success: true, weekStart,
          mealPlan: (plans ?? []).map((p) => (p.metadata as Record<string, unknown>)),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "shopping_list") {
        const weekStart = url.searchParams.get("week_start") ?? new Date().toISOString().substring(0, 10);
        const { data: list } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "shopping_list").eq("metadata->>week_start", weekStart).maybeSingle();
        return new Response(JSON.stringify({
          success: true,
          shoppingList: list ? (list.metadata as Record<string, unknown>).items : [],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "nutrition") {
        const { data: recipes } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "recipe");
        let totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
        for (const r of recipes ?? []) {
          const meta = r.metadata as Record<string, unknown>;
          const nutrition = meta.nutrition as Record<string, number> | undefined;
          if (nutrition) {
            totalCalories += nutrition.calories ?? 0;
            totalProtein += nutrition.protein ?? 0;
            totalCarbs += nutrition.carbs ?? 0;
            totalFat += nutrition.fat ?? 0;
          }
        }
        const count = (recipes ?? []).length || 1;
        return new Response(JSON.stringify({
          success: true,
          averagePerRecipe: { calories: Math.round(totalCalories / count), protein: Math.round(totalProtein / count), carbs: Math.round(totalCarbs / count), fat: Math.round(totalFat / count) },
          totalRecipes: (recipes ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: recipe list
      const category = url.searchParams.get("category");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "recipe")
        .order("created_at", { ascending: false });
      if (category) query = query.eq("metadata->>category", category);
      const { data: recipes } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        recipes: (recipes ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_recipe") {
        const { title, category, servings, prep_time_min, cook_time_min, ingredients, steps, nutrition, image_url } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const recipeId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "recipe",
          metadata: {
            recipe_id: recipeId, title, category: category ?? "その他",
            servings: servings ?? 2, prep_time_min: prep_time_min ?? 10, cook_time_min: cook_time_min ?? 20,
            ingredients: ingredients ?? [], steps: steps ?? [],
            nutrition: nutrition ?? { calories: 0, protein: 0, carbs: 0, fat: 0 },
            image_url: image_url ?? null, is_favorite: false,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recipeId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "set_meal_plan") {
        const { week_start, day, meal_type, recipe_id, recipe_title } = body;
        if (!week_start || !day || !meal_type) {
          return new Response(JSON.stringify({ success: false, error: "week_start, day, and meal_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "meal_plan",
          metadata: { week_start, day, meal_type, recipe_id: recipe_id ?? null, recipe_title: recipe_title ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, planned: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "generate_shopping_list") {
        const { week_start } = body;
        if (!week_start) {
          return new Response(JSON.stringify({ success: false, error: "week_start required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Get meal plan recipes
        const { data: plans } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "meal_plan").eq("metadata->>week_start", week_start);
        const recipeIds = [...new Set((plans ?? []).map((p) => (p.metadata as Record<string, unknown>).recipe_id as string).filter(Boolean))];
        // Get ingredients from recipes
        const allIngredients: Record<string, { amount: number; unit: string }> = {};
        for (const rid of recipeIds) {
          const { data: recipe } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "recipe").eq("metadata->>recipe_id", rid).maybeSingle();
          if (recipe) {
            const ingredients = ((recipe.metadata as Record<string, unknown>).ingredients as Array<{ name: string; amount: number; unit: string }>) ?? [];
            for (const ing of ingredients) {
              if (allIngredients[ing.name]) {
                allIngredients[ing.name].amount += ing.amount;
              } else {
                allIngredients[ing.name] = { amount: ing.amount, unit: ing.unit };
              }
            }
          }
        }
        const items = Object.entries(allIngredients).map(([name, info]) => ({ name, ...info, checked: false }));
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "shopping_list",
          metadata: { week_start, items, generated_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, items, recipeCount: recipeIds.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
