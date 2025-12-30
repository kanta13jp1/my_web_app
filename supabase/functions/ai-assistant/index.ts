// AI Assistant Edge Function: "The Five Emperors" (Strict Vision Benchmarking & Dynamic Ranking)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const KEYS = {
    gemini: Deno.env.get('GEMINI_API_KEY'),
    openai: Deno.env.get('OPENAI_API_KEY'),
    anthropic: Deno.env.get('ANTHROPIC_API_KEY'),
    deepseek: Deno.env.get('DEEPSEEK_API_KEY'),
    grok: Deno.env.get('XAI_API_KEY'),
};

/**
 * 検証済み: 32x32 純粋な赤 (#FF0000) PNG
 */
const VERIFIED_RED_SQUARE = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKElEQVR4nO3NMQEAAAjDMMC/ZzDBvlRA01vZJvwHAAAAAAAAAAAAbx2jxAE/i2AjOgAAAABJRU5ErkJggg==";

interface AIRequest {
    action: string;
    model?: string;
    content?: string;
    imageBase64?: string;
    mimeType?: string;
}

serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Missing authorization header')

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error('Unauthorized')

        const requestData: AIRequest = await req.json()
        const { action, model: targetModel } = requestData

        // --- 1. モデル一覧取得 (DBの実績からスコアを算出してソート) ---
        if (action === 'get_models') {
            const models = await gatherAllCandidates(supabaseClient);
            return new Response(JSON.stringify({ success: true, models }), { headers: corsHeaders });
        }

        // --- 2. 死活監視・ベンチマークテスト & DB保存 ---
        if (action === 'test_model') {
            if (!targetModel) throw new Error('Model name is required');

            // 候補リストを取得してプロバイダーを特定
            const candidates = await gatherAllCandidates(supabaseClient);
            const fighter = candidates.find(c => c.model === targetModel);
            if (!fighter) throw new Error(`Model ${targetModel} not found`);

            // ベンチマーク実行
            const benchmark = await runStrictVisionBenchmark(fighter, KEYS);

            // データベースへの保存
            const { error: dbError } = await supabaseClient
                .from('ai_benchmark_results')
                .insert({
                    user_id: user.id,
                    model_name: fighter.model,
                    provider: fighter.provider,
                    vision_score: benchmark.score,
                    latency_ms: benchmark.latency,
                    detail: benchmark.detail
                });

            if (dbError) console.error("Database Insert Error:", dbError.message);

            return new Response(JSON.stringify({
                success: true,
                status: "active",
                benchmark
            }), { headers: corsHeaders });
        }

        return new Response(JSON.stringify({ success: false, error: "Action implementation pending" }), { headers: corsHeaders, status: 404 });

    } catch (error: any) {
        return new Response(JSON.stringify({ success: false, error: error.message }), { headers: corsHeaders, status: 400 });
    }
});

/**
 * データベースの実績に基づいてモデルを収集・スコアリング・ソートする
 */
async function gatherAllCandidates(supabase: any): Promise<any[]> {
    // 全モデルの最新のベンチマーク結果をDBから取得
    const { data: latestResults } = await supabase
        .from('ai_benchmark_results')
        .select('model_name, vision_score, latency_ms')
        .order('tested_at', { ascending: false });

    const promises = Object.entries(KEYS).map(async ([provider, key]) => {
        if (!key) return [];
        try {
            const models = await fetchDynamicModels(provider, key);
            return models.map(m => {
                // そのモデルの直近の実績を取得
                const history = latestResults?.find((r: any) => r.model_name === m);
                
                // スコア計算ロジック:
                // 実績がある場合: (正確性 0-100 * 10) - (速度ms / 100)
                // 実績がない場合: 500点 (未評価のベースライン)
                const score = history 
                    ? (history.vision_score * 10) - Math.floor(history.latency_ms / 100)
                    : 500;

                return { provider, model: m, score };
            });
        } catch { return []; }
    });

    const results = (await Promise.all(promises)).flat();
    
    // スコアの高い順にソート
    return results.sort((a, b) => b.score - a.score);
}

/**
 * 画像認識単体テスト
 */
async function runStrictVisionBenchmark(fighter: any, keys: any) {
    const start = Date.now();

    const visionData: AIRequest = {
        action: 'test_vision',
        content: "この画像の中央にある色を日本語1文字（例：青）で答えてください。",
        imageBase64: VERIFIED_RED_SQUARE,
        mimeType: "image/png"
    };

    try {
        const text = await callAI(fighter, keys, visionData);
        const latency = Date.now() - start;

        // 評価ロジック
        const isCorrect = text.includes("赤") || text.toLowerCase().includes("red");

        return {
            score: isCorrect ? 100 : 0,
            latency,
            detail: text,
            type: 'vision_strict_v2'
        };
    } catch (e: any) {
        // エラー時はスコア0で記録し、例外を投げずに結果を返す
        return {
            score: 0,
            latency: Date.now() - start,
            detail: `Error: ${e.message}`,
            type: 'vision_strict_error'
        };
    }
}

async function callAI(fighter: any, keys: any, data: AIRequest): Promise<string> {
    if (fighter.provider === 'gemini') return await callGemini(fighter.model, keys.gemini!, data);
    if (fighter.provider === 'anthropic') return await callAnthropic(fighter.model, keys.anthropic!, data);
    return await callOpenAICompatible(fighter.provider, fighter.model, keys.openai!, data);
}

// --- API Wrappers ---

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const content = [
        { type: "text", text: data.content },
        { type: "image_url", image_url: { url: `data:${data.mimeType};base64,${data.imageBase64}` } }
    ];

    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages: [{ role: "user", content }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`OpenAI: ${json.error?.message || "Unknown error"}`);
    return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const content = [
        { type: "image", source: { type: "base64", media_type: data.mimeType as any, data: data.imageBase64 } },
        { type: "text", text: data.content }
    ];

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 128, messages: [{ role: "user", content }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Anthropic: ${json.error?.message || "Unknown error"}`);
    return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const parts = [{ text: data.content }, { inline_data: { mime_type: data.mimeType, data: data.imageBase64 } }];

    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Gemini: ${json.error?.message || "Unknown error"}`);
    return json.candidates[0].content.parts[0].text;
}

async function fetchDynamicModels(provider: string, apiKey: string): Promise<string[]> {
    let url = ''; let headers = {};
    if (provider === 'openai') { url = 'https://api.openai.com/v1/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; }
    else if (provider === 'anthropic') { url = 'https://api.anthropic.com/v1/models'; headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' }; }
    else if (provider === 'gemini') { url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`; }
    else return [];

    const resp = await fetch(url, { headers });
    const json = await resp.json();
    if (provider === 'gemini') return (json.models || []).map((m: any) => m.name.replace('models/', ''));
    return (json.data || []).map((m: any) => m.id || m.name);
}