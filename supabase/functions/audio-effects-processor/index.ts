import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Audio effects catalog — parameters for Web Audio API on the frontend
const EFFECTS_CATALOG: Record<string, {
  name: string;
  category: string;
  description: string;
  parameters: Array<{ name: string; min: number; max: number; default: number; unit: string }>;
  webAudioNode: string;
}> = {
  reverb_hall: {
    name: "ホールリバーブ",
    category: "reverb",
    description: "コンサートホールのような広がりのある残響",
    parameters: [
      { name: "decay", min: 0.5, max: 10, default: 3.0, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 40, unit: "%" },
      { name: "preDelay", min: 0, max: 100, default: 20, unit: "ms" },
    ],
    webAudioNode: "ConvolverNode",
  },
  reverb_room: {
    name: "ルームリバーブ",
    category: "reverb",
    description: "小さな部屋のナチュラルな残響",
    parameters: [
      { name: "decay", min: 0.2, max: 3, default: 1.0, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 30, unit: "%" },
    ],
    webAudioNode: "ConvolverNode",
  },
  reverb_spring: {
    name: "スプリングリバーブ",
    category: "reverb",
    description: "ヴィンテージアンプのスプリングリバーブサウンド",
    parameters: [
      { name: "decay", min: 0.3, max: 5, default: 2.0, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 35, unit: "%" },
      { name: "tone", min: 200, max: 8000, default: 3000, unit: "Hz" },
    ],
    webAudioNode: "ConvolverNode",
  },
  reverb_plate: {
    name: "プレートリバーブ",
    category: "reverb",
    description: "密度の高い金属的な残響",
    parameters: [
      { name: "decay", min: 0.5, max: 8, default: 2.5, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 35, unit: "%" },
    ],
    webAudioNode: "ConvolverNode",
  },
  reverb_shimmer: {
    name: "シマーリバーブ",
    category: "reverb",
    description: "オクターブ上のピッチシフトを含む幻想的なリバーブ",
    parameters: [
      { name: "decay", min: 2, max: 20, default: 8.0, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 50, unit: "%" },
      { name: "shimmer", min: 0, max: 100, default: 60, unit: "%" },
    ],
    webAudioNode: "ConvolverNode",
  },
  reverb_cathedral: {
    name: "カテドラルリバーブ",
    category: "reverb",
    description: "大聖堂のような壮大な残響",
    parameters: [
      { name: "decay", min: 3, max: 15, default: 6.0, unit: "s" },
      { name: "mix", min: 0, max: 100, default: 45, unit: "%" },
    ],
    webAudioNode: "ConvolverNode",
  },
  distortion_medium: {
    name: "ミディアムディストーション",
    category: "distortion",
    description: "クランチからドライブまで。ロック向き",
    parameters: [
      { name: "gain", min: 0, max: 100, default: 50, unit: "%" },
      { name: "tone", min: 200, max: 8000, default: 4000, unit: "Hz" },
      { name: "level", min: 0, max: 100, default: 70, unit: "%" },
    ],
    webAudioNode: "WaveShaperNode",
  },
  distortion_heavy: {
    name: "ヘビーディストーション",
    category: "distortion",
    description: "メタル・ハードロック向けの激しい歪み",
    parameters: [
      { name: "gain", min: 50, max: 100, default: 85, unit: "%" },
      { name: "tone", min: 200, max: 6000, default: 3000, unit: "Hz" },
      { name: "level", min: 0, max: 100, default: 80, unit: "%" },
    ],
    webAudioNode: "WaveShaperNode",
  },
  overdrive: {
    name: "オーバードライブ",
    category: "distortion",
    description: "温かみのあるナチュラルな歪み。ブルース向き",
    parameters: [
      { name: "drive", min: 0, max: 100, default: 40, unit: "%" },
      { name: "tone", min: 200, max: 8000, default: 5000, unit: "Hz" },
      { name: "level", min: 0, max: 100, default: 65, unit: "%" },
    ],
    webAudioNode: "WaveShaperNode",
  },
  delay_slap: {
    name: "スラップバックディレイ",
    category: "delay",
    description: "短いディレイ。ロカビリー・カントリー向き",
    parameters: [
      { name: "time", min: 50, max: 200, default: 120, unit: "ms" },
      { name: "feedback", min: 0, max: 50, default: 10, unit: "%" },
      { name: "mix", min: 0, max: 100, default: 40, unit: "%" },
    ],
    webAudioNode: "DelayNode",
  },
  delay_long: {
    name: "ロングディレイ",
    category: "delay",
    description: "長いフィードバックのアンビエント向きディレイ",
    parameters: [
      { name: "time", min: 200, max: 2000, default: 500, unit: "ms" },
      { name: "feedback", min: 0, max: 90, default: 60, unit: "%" },
      { name: "mix", min: 0, max: 100, default: 35, unit: "%" },
    ],
    webAudioNode: "DelayNode",
  },
  chorus: {
    name: "コーラス",
    category: "modulation",
    description: "音に厚みと揺らぎを加える",
    parameters: [
      { name: "rate", min: 0.1, max: 10, default: 1.5, unit: "Hz" },
      { name: "depth", min: 0, max: 100, default: 50, unit: "%" },
      { name: "mix", min: 0, max: 100, default: 50, unit: "%" },
    ],
    webAudioNode: "DelayNode+OscillatorNode",
  },
  phaser: {
    name: "フェイザー",
    category: "modulation",
    description: "位相をずらしてシュワシュワした効果を出す",
    parameters: [
      { name: "rate", min: 0.1, max: 8, default: 0.5, unit: "Hz" },
      { name: "depth", min: 0, max: 100, default: 70, unit: "%" },
      { name: "feedback", min: 0, max: 90, default: 40, unit: "%" },
    ],
    webAudioNode: "BiquadFilterNode+OscillatorNode",
  },
  tremolo: {
    name: "トレモロ",
    category: "modulation",
    description: "音量の周期的な揺れ",
    parameters: [
      { name: "rate", min: 0.5, max: 20, default: 5, unit: "Hz" },
      { name: "depth", min: 0, max: 100, default: 60, unit: "%" },
    ],
    webAudioNode: "GainNode+OscillatorNode",
  },
  wah_auto: {
    name: "オートワウ",
    category: "filter",
    description: "入力音量に応じてフィルターが動くファンキーな効果",
    parameters: [
      { name: "sensitivity", min: 0, max: 100, default: 60, unit: "%" },
      { name: "range", min: 200, max: 8000, default: 4000, unit: "Hz" },
      { name: "speed", min: 0.1, max: 5, default: 1, unit: "Hz" },
    ],
    webAudioNode: "BiquadFilterNode",
  },
  compressor_light: {
    name: "ライトコンプレッサー",
    category: "dynamics",
    description: "軽い圧縮でダイナミクスを整える",
    parameters: [
      { name: "threshold", min: -60, max: 0, default: -24, unit: "dB" },
      { name: "ratio", min: 1, max: 4, default: 2, unit: ":1" },
      { name: "attack", min: 0, max: 100, default: 10, unit: "ms" },
      { name: "release", min: 50, max: 500, default: 250, unit: "ms" },
    ],
    webAudioNode: "DynamicsCompressorNode",
  },
  compressor_medium: {
    name: "ミディアムコンプレッサー",
    category: "dynamics",
    description: "しっかりした圧縮でサステインを出す",
    parameters: [
      { name: "threshold", min: -60, max: 0, default: -30, unit: "dB" },
      { name: "ratio", min: 2, max: 8, default: 4, unit: ":1" },
      { name: "attack", min: 0, max: 100, default: 5, unit: "ms" },
      { name: "release", min: 50, max: 500, default: 200, unit: "ms" },
    ],
    webAudioNode: "DynamicsCompressorNode",
  },
  compressor_heavy: {
    name: "ヘビーコンプレッサー",
    category: "dynamics",
    description: "強い圧縮でパーカッシブなアタックを出す",
    parameters: [
      { name: "threshold", min: -60, max: 0, default: -40, unit: "dB" },
      { name: "ratio", min: 6, max: 20, default: 12, unit: ":1" },
      { name: "attack", min: 0, max: 50, default: 1, unit: "ms" },
      { name: "release", min: 50, max: 500, default: 100, unit: "ms" },
    ],
    webAudioNode: "DynamicsCompressorNode",
  },
  noise_gate: {
    name: "ノイズゲート",
    category: "dynamics",
    description: "一定音量以下をカットしてノイズを除去",
    parameters: [
      { name: "threshold", min: -80, max: -20, default: -50, unit: "dB" },
      { name: "attack", min: 0, max: 10, default: 0.5, unit: "ms" },
      { name: "release", min: 10, max: 200, default: 50, unit: "ms" },
    ],
    webAudioNode: "GainNode+AnalyserNode",
  },
  eq_3band: {
    name: "3バンドEQ",
    category: "eq",
    description: "低域・中域・高域を調整",
    parameters: [
      { name: "low", min: -12, max: 12, default: 0, unit: "dB" },
      { name: "mid", min: -12, max: 12, default: 0, unit: "dB" },
      { name: "high", min: -12, max: 12, default: 0, unit: "dB" },
      { name: "lowFreq", min: 60, max: 300, default: 120, unit: "Hz" },
      { name: "highFreq", min: 2000, max: 12000, default: 4000, unit: "Hz" },
    ],
    webAudioNode: "BiquadFilterNode",
  },
};

// Effect chain presets
const CHAIN_PRESETS: Record<string, { name: string; effects: string[]; description: string }> = {
  clean_sparkle: { name: "クリーンスパークル", effects: ["compressor_light", "chorus", "reverb_room"], description: "キラキラしたクリーントーン" },
  blues_king: { name: "ブルースキング", effects: ["overdrive", "reverb_spring", "delay_slap"], description: "BB King風のブルーストーン" },
  rock_classic: { name: "クラシックロック", effects: ["distortion_medium", "eq_3band", "reverb_hall"], description: "70年代ロックサウンド" },
  metal_wall: { name: "メタルウォール", effects: ["noise_gate", "distortion_heavy", "eq_3band", "compressor_heavy"], description: "壁のようなヘビーサウンド" },
  ambient_dream: { name: "アンビエントドリーム", effects: ["compressor_light", "chorus", "delay_long", "reverb_shimmer"], description: "幻想的なアンビエントサウンド" },
  funk_machine: { name: "ファンクマシーン", effects: ["compressor_heavy", "wah_auto", "phaser"], description: "カッティング向きファンクサウンド" },
  jazz_warm: { name: "ジャズウォーム", effects: ["compressor_medium", "eq_3band", "chorus", "reverb_plate"], description: "温かいジャズトーン" },
  acoustic_natural: { name: "アコースティックナチュラル", effects: ["compressor_light", "eq_3band", "reverb_room"], description: "自然なアコースティックサウンド" },
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "catalog";

    // GET: Full effects catalog
    if (action === "catalog") {
      const category = url.searchParams.get("category");
      let effects = Object.entries(EFFECTS_CATALOG);

      if (category) {
        effects = effects.filter(([_, e]) => e.category === category);
      }

      const categories = [...new Set(Object.values(EFFECTS_CATALOG).map(e => e.category))];

      return new Response(
        JSON.stringify({
          effects: effects.map(([id, e]) => ({ id, ...e })),
          categories,
          totalEffects: Object.keys(EFFECTS_CATALOG).length,
          chainPresets: Object.entries(CHAIN_PRESETS).map(([id, p]) => ({ id, ...p })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: Single effect details
    if (action === "effect") {
      const effectId = url.searchParams.get("id");
      if (!effectId || !(effectId in EFFECTS_CATALOG)) {
        return new Response(
          JSON.stringify({ error: "Invalid effect ID", validEffects: Object.keys(EFFECTS_CATALOG) }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ id: effectId, ...EFFECTS_CATALOG[effectId] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: Chain presets
    if (action === "chain_presets") {
      return new Response(
        JSON.stringify({
          presets: Object.entries(CHAIN_PRESETS).map(([id, p]) => ({
            id,
            ...p,
            effectDetails: p.effects.map(eid => ({
              id: eid,
              name: EFFECTS_CATALOG[eid]?.name ?? eid,
              category: EFFECTS_CATALOG[eid]?.category ?? "unknown",
            })),
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // POST: Save user's custom effect chain
    if (req.method === "POST") {
      const body = await req.json();
      const postAction = body.action ?? action;

      if (postAction === "save_chain") {
        const { userId, name, effects, description } = body;

        if (!userId || !name || !effects || !Array.isArray(effects)) {
          return new Response(
            JSON.stringify({ error: "userId, name, and effects array are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const chainId = crypto.randomUUID();

        const { error: saveErr } = await supabase.from("app_analytics").insert({
          source: "audio-effects-processor",
          event_type: "custom_chain_saved",
          event_data: {
            chainId,
            userId,
            name,
            effects,
            description: description ?? "",
            createdAt: new Date().toISOString(),
          },
        });

        if (saveErr) {
          return new Response(
            JSON.stringify({ error: saveErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true, chainId }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Get user's custom chains
      if (postAction === "my_chains") {
        const { userId } = body;

        if (!userId) {
          return new Response(
            JSON.stringify({ error: "userId is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const { data: chains } = await supabase
          .from("app_analytics")
          .select("*")
          .eq("source", "audio-effects-processor")
          .eq("event_type", "custom_chain_saved")
          .order("created_at", { ascending: false })
          .limit(100);

        const userChains = (chains ?? [])
          .filter((c: Record<string, unknown>) => {
            const ed = c.event_data as Record<string, unknown>;
            return ed?.userId === userId;
          })
          .map((c: Record<string, unknown>) => c.event_data);

        return new Response(
          JSON.stringify({ chains: userChains }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ error: "Unknown POST action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unknown action",
        validActions: ["catalog", "effect", "chain_presets"],
        postActions: ["save_chain", "my_chains"],
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
