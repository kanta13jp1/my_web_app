// AI Image Generator Edge Function
// AI画像生成 (DALL-E/Midjourney/Stable Diffusion/Canva競合)
// - プロンプト管理
// - 画像生成記録
// - ギャラリー
// - スタイル管理
// - テンプレート

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const IMAGE_STYLES = ["realistic", "anime", "watercolor", "oil_painting", "pixel_art", "3d_render", "sketch", "comic", "abstract", "minimalist"];
const IMAGE_SIZES = ["256x256", "512x512", "1024x1024", "1024x1792", "1792x1024"];
const PROMPT_TEMPLATES = [
  { id: "portrait", name: "ポートレート", template: "A professional portrait of {subject}, {style} style, high quality, detailed" },
  { id: "landscape", name: "風景", template: "A beautiful landscape of {location}, {time_of_day}, {style} style, scenic" },
  { id: "product", name: "商品", template: "A product photo of {product}, clean background, {style} lighting, commercial quality" },
  { id: "logo", name: "ロゴ", template: "A modern logo for {brand}, {style} design, minimal, vector style" },
  { id: "icon", name: "アイコン", template: "A {style} app icon for {concept}, flat design, vibrant colors" },
  { id: "banner", name: "バナー", template: "A web banner for {event}, {style} style, eye-catching, {color_scheme} colors" },
];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, styles: IMAGE_STYLES, sizes: IMAGE_SIZES, templates: PROMPT_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "gallery") {
        const { data: images } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "ai_image").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, images: (images ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "public_gallery") {
        const { data: images } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "ai_image").eq("metadata->>is_public", "true").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, images: (images ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "prompt_history") {
        const { data: prompts } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "ai_image_prompt").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, prompts: (prompts ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "usage") {
        const { count: totalGenerated } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "ai_image");
        const today = new Date().toISOString().split("T")[0];
        const { count: todayCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "ai_image").gte("created_at", today);
        return new Response(JSON.stringify({ success: true, usage: { totalGenerated: totalGenerated ?? 0, todayCount: todayCount ?? 0, dailyLimit: 20 } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, styles: IMAGE_STYLES, templates: PROMPT_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "generate") {
        const { prompt, style, size, is_public, template_id, template_vars } = body;
        if (!prompt) return new Response(JSON.stringify({ success: false, error: "prompt required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Check daily limit
        const today = new Date().toISOString().split("T")[0];
        const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "ai_image").gte("created_at", today);
        if ((count ?? 0) >= 20) return new Response(JSON.stringify({ success: false, error: "本日の生成上限に達しました (20枚/日)" }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Apply template if provided
        let finalPrompt = prompt;
        if (template_id && template_vars) {
          const tmpl = PROMPT_TEMPLATES.find((t) => t.id === template_id);
          if (tmpl) {
            finalPrompt = tmpl.template;
            for (const [key, val] of Object.entries(template_vars as Record<string, string>)) {
              finalPrompt = finalPrompt.replace(`{${key}}`, val);
            }
          }
        }
        // Record generation (actual image generation would require external API)
        const imageId = crypto.randomUUID();
        const placeholderUrl = `https://placehold.co/${(size ?? "512x512").replace("x", "x")}/1a1a2e/ffffff?text=AI+Generated`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ai_image",
          metadata: { image_id: imageId, prompt: finalPrompt, original_prompt: prompt, style: style ?? "realistic", size: size ?? "512x512", image_url: placeholderUrl, is_public: is_public ?? false, template_id: template_id ?? null, likes: 0 },
          created_at: new Date().toISOString(),
        });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ai_image_prompt",
          metadata: { prompt: finalPrompt, style: style ?? "realistic", image_id: imageId },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, imageId, imageUrl: placeholderUrl, prompt: finalPrompt }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "like") {
        const { image_id } = body;
        if (!image_id) return new Response(JSON.stringify({ success: false, error: "image_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: img } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "ai_image").eq("metadata->>image_id", image_id).maybeSingle();
        if (!img) return new Response(JSON.stringify({ success: false, error: "Image not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = img.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({ metadata: { ...m, likes: ((m.likes as number) ?? 0) + 1 } })
          .eq("source", "ai_image").eq("metadata->>image_id", image_id);
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete") {
        const { image_id } = body;
        if (!image_id) return new Response(JSON.stringify({ success: false, error: "image_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "ai_image").eq("metadata->>image_id", image_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
