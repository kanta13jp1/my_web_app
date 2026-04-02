// Agent Personality Edge Function
// エージェントの性格管理・記憶・学習
// X post の機能: 性格ログ、行動パターン記憶、苦手カバー
//
// GET  → エージェントの性格情報・記憶一覧
// POST → 性格更新 / 記憶記録 / 行動パターン学習

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const agentId = url.searchParams.get("agent_id");
      const view = url.searchParams.get("view"); // 'personality' | 'memories' | 'patterns' | 'all'

      if (view === "memories" && agentId) {
        // エージェントの記憶一覧
        const { data, error } = await supabase
          .from("agent_memories")
          .select("*")
          .eq("agent_id", agentId)
          .order("created_at", { ascending: false })
          .limit(50);

        if (error) throw error;

        // レイヤー別に分類
        const byLayer: Record<string, unknown[]> = {};
        for (const m of data ?? []) {
          const layer = (m.layer as string) ?? "unknown";
          if (!byLayer[layer]) byLayer[layer] = [];
          byLayer[layer].push(m);
        }

        return new Response(
          JSON.stringify({ success: true, memories: data ?? [], byLayer }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "personality" && agentId) {
        // エージェントの性格情報
        const { data: agent, error } = await supabase
          .from("agents")
          .select("id, slug, display_name, role_title, department, identity_prompt, metadata")
          .eq("id", agentId)
          .single();

        if (error) throw error;

        // identity_prompt から性格特性を抽出
        const personality = parsePersonality(agent?.identity_prompt ?? "");

        return new Response(
          JSON.stringify({
            success: true,
            agent,
            personality,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 全エージェントの性格サマリー
      const { data: agents, error } = await supabase
        .from("agents")
        .select("id, slug, display_name, role_title, department, identity_prompt, metadata, status")
        .order("department", { ascending: true });

      if (error) throw error;

      const agentSummaries = (agents ?? []).map((a) => ({
        id: a.id,
        slug: a.slug,
        display_name: a.display_name,
        role_title: a.role_title,
        department: a.department,
        status: a.status,
        personality: parsePersonality(a.identity_prompt ?? ""),
        hasCustomPersonality: !!(a.metadata as Record<string, unknown>)?.personality_traits,
      }));

      return new Response(
        JSON.stringify({ success: true, agents: agentSummaries }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "update_personality") {
        // エージェントの性格を更新
        const { agent_id, identity_prompt, personality_traits } = body;

        if (!agent_id) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updates: Record<string, unknown> = {
          updated_at: new Date().toISOString(),
        };
        if (identity_prompt) updates.identity_prompt = identity_prompt;
        if (personality_traits) {
          // metadata に性格特性を保存
          const { data: current } = await supabase
            .from("agents")
            .select("metadata")
            .eq("id", agent_id)
            .single();

          const currentMeta = (current?.metadata ?? {}) as Record<string, unknown>;
          updates.metadata = { ...currentMeta, personality_traits };
        }

        const { data, error } = await supabase
          .from("agents")
          .update(updates)
          .eq("id", agent_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agent: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "record_memory") {
        // 記憶を記録 (会話や行動パターンから)
        const { agent_id, user_id, layer, content, metadata } = body;

        if (!agent_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id and content are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let userId = user_id;
        if (!userId) {
          const { data: agent } = await supabase
            .from("agents")
            .select("user_id")
            .eq("id", agent_id)
            .single();
          userId = agent?.user_id;
        }

        const { data, error } = await supabase
          .from("agent_memories")
          .insert({
            agent_id,
            user_id: userId,
            layer: layer ?? "episodes",
            content,
            metadata: metadata ?? {},
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, memory: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "learn_from_conversation") {
        // 会話から性格を学習 (人間の会話パターンを記録)
        const { agent_id, user_id, conversation_summary, detected_traits } = body;

        if (!agent_id || !conversation_summary) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id and conversation_summary are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let userId = user_id;
        if (!userId) {
          const { data: agent } = await supabase
            .from("agents")
            .select("user_id")
            .eq("id", agent_id)
            .single();
          userId = agent?.user_id;
        }

        // 会話内容を knowledge レイヤーに保存
        const { data: memory, error: memError } = await supabase
          .from("agent_memories")
          .insert({
            agent_id,
            user_id: userId,
            layer: "knowledge",
            content: conversation_summary,
            metadata: { detected_traits: detected_traits ?? [], type: "personality_learning" },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (memError) throw memError;

        // 検出された性格特性を metadata に蓄積
        if (detected_traits && detected_traits.length > 0) {
          const { data: agent } = await supabase
            .from("agents")
            .select("metadata")
            .eq("id", agent_id)
            .single();

          const meta = (agent?.metadata ?? {}) as Record<string, unknown>;
          const existingTraits = (meta.learned_traits ?? []) as string[];
          const newTraits = [...new Set([...existingTraits, ...detected_traits])];

          await supabase
            .from("agents")
            .update({
              metadata: { ...meta, learned_traits: newTraits },
              updated_at: new Date().toISOString(),
            })
            .eq("id", agent_id);
        }

        return new Response(
          JSON.stringify({ success: true, memory }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("agent-personality error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

// identity_prompt からキーワードで性格特性を推定
function parsePersonality(prompt: string): {
  traits: string[];
  style: string;
  strengths: string[];
} {
  const traits: string[] = [];
  const strengths: string[] = [];

  const traitMap: Record<string, string> = {
    "慎重": "慎重",
    "大胆": "大胆",
    "分析": "分析的",
    "論理": "論理的",
    "共感": "共感力",
    "創造": "創造的",
    "リーダー": "リーダーシップ",
    "実行": "実行力",
    "計画": "計画的",
    "柔軟": "柔軟性",
    "正確": "正確性",
    "迅速": "迅速",
    "戦略": "戦略的思考",
    "コミュニケーション": "コミュニケーション力",
  };

  for (const [keyword, trait] of Object.entries(traitMap)) {
    if (prompt.includes(keyword)) traits.push(trait);
  }

  if (prompt.includes("CEO") || prompt.includes("リーダー")) {
    strengths.push("意思決定", "ビジョン策定");
  }
  if (prompt.includes("開発") || prompt.includes("CTO")) {
    strengths.push("技術判断", "アーキテクチャ設計");
  }
  if (prompt.includes("営業") || prompt.includes("Sales")) {
    strengths.push("顧客開拓", "交渉力");
  }
  if (prompt.includes("経理") || prompt.includes("CFO")) {
    strengths.push("財務分析", "予算管理");
  }

  const style = traits.length > 2 ? "多面的" : traits.length > 0 ? "専門特化" : "汎用";

  return { traits, style, strengths };
}
