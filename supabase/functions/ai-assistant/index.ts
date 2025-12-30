// AI Assistant Edge Function: Multi-Level Vision Benchmark
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
 * 多段階ベンチマーク用テスト画像
 */
const TEST_IMAGES = {
    // Level 1: 赤い正方形 (64x64) - 色認識テスト
    level1: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAX0lEQVR4nO3PQQ0AIBDAMMC/50MEj4ZkVbDtWX87OuBVA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA9oFUoUBf3Xr7AgAAAAASUVORK5CYII=",
        prompt: "この画像の色を日本語1文字で答えてください（例：青）",
        answer: ["赤", "red"],
        points: 30
    },
    // Level 2: 「AI」の文字 (128x64) - OCRテスト
    level2: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAIAAAABACAIAAABdtOgoAAADKUlEQVR4nO2az0oCURSHR2uRYItAgjaCYgszl0G0aBXt1Jahb+B7uPMhUlEoo1pEG7FFRatA3QgZRIoYKojlH0JypoUQceeaA83cX03n23XmzPHIN/fMbUaLoigSgcOKbuC/QwLAkAAwJAAMCQBDAsCQADAkAAwJAEMCwJAAMCQADAkAAxNQKpUs07m/v9dY5/j4mFuhWCwa2b5uwAQcHBx8czSRSIhqBAxGwPv7eyaT+SYhlUrJsiysHyAYARcXF61W65uEer2ez+eF9QMEI0DLhPknUwggoNPpnJ+fz0w7PT3t9XoC+sECEJDJZEajERO02WxMZDgcHh0diWoKBkAAd7bE43GNmSZDtIByuXx3d8cEvV5vNBp1uVxM/Obm5vHxUVRrGEQL4G7/w+GwJEn7+/tMXFEU0y8CoQLG43E6nVbHJwIikYj6UDKZNPcvl4QKyOVyjUaDCW5ubrrdbkmSfD6f3+9njj49PV1dXQnqD4FQAdz58/XCnywFLWeZB0UU3W53YWGB+fS5ublms/mZU61WLRYLk2O32/v9/rSy2WyW+70KhYKIb/VjxK2Aw8PDt7c3Jrizs7O8vPz5p9Pp3NraYnL6/f7JyYnh/YEQJ4C7n1HfeLlTyMx7ITELrVKpqD/aZrO9vr4yme12e35+nsm0Wq3VapVbmUaQJriXcCAQWFxcZIIOh2N3d5cJyrKcSqWMag6LAMmyLDudzh/2ubq6yi1OK2A2l5eXtVrth0UeHh5ub2916edXIUKAXrdQU96KDReg4yaSu5H96xguIJvNDgYDXUq9vLycnZ3pUur3YLiAaU//Z96dYrGYxmp/GmMFTHuUFgqFZp4bDAbVwVwu9/z8rENnvwZjBSQSCUX1MHltbc3j8cw8d319ffKU9Cvj8dhk/xAYKyCZTKqDe3t7Gk8PBALqoMmmkIECrq+vuS8UtcyfCdwpxH2p+XcxUAD3Ul1ZWdnY2NBYYXt7e2lpSR030xsCi3pGEyKhn6eDIQFgSAAYEgCGBIAhAWBIABgSAIYEgCEBYEgAGBIAhgSAIQFgSAAYEgCGBIAhAWBIABgSAOYD4n2nWK6QlrQAAAAASUVORK5CYII=",
        prompt: "この画像に書かれている英字2文字を答えてください",
        answer: ["AI", "ai", "Ai", "aI"],
        points: 35
    },
    // Level 3: 青い円が3つ (128x64) - 複合認識テスト
    level3: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAIAAAABACAIAAABdtOgoAAABSUlEQVR4nO2aUQvCMAwGN/H//+X5qKDYNuk4SO4eB80Xd41lbOd1XYdwPOgGuqMAGAXAKABGATAKgFEAjAJgFACjABgFwCgARgEwCoBRAIwCYJ75Euf54+Ldr3nKhJ7hN2I/u/lm702pFxoRMNnQJ/k7UjV0+QwI9BRe1SF0TUDmJ4XX1g5dEJDcULEK5UNnBeR7CtTpEDolYFdPS9WahPogBjMWsHdTTNbsE+oEwCgAZiDgjqkcVu4TejgBOAqAUQCMAmAUAKMAmIGA+17y/ancJ/RwAnAUADMWcMdsDmv2CXUCYKYE7N0ak9WahM5OwK7Olup0CF34C8p3FqhQPnTtDMh0Fl5bO3T5EI51ltxThUP9NhQOjQt4l6jyoTISukGAZPBBDEYBMAqAUQCMAmAUAKMAGAXAKABGATAKgFEAjAJgFACjAJgX8zWEa6rF56QAAAAASUVORK5CYII=",
        prompt: "この画像には何色の丸が何個ありますか？「○色の丸が○個」の形式で答えてください",
        answer: ["青", "3", "三"],
        points: 35
    }
};

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

        // --- 1. モデル一覧取得 ---
        if (action === 'get_models') {
            const models = await gatherAllCandidates(supabaseClient);
            return new Response(JSON.stringify({ success: true, models }), { headers: corsHeaders });
        }

        // --- 2. 多段階ベンチマークテスト ---
        if (action === 'test_model') {
            if (!targetModel) throw new Error('Model name is required');

            const candidates = await gatherAllCandidates(supabaseClient);
            const fighter = candidates.find(c => c.model === targetModel);
            if (!fighter) throw new Error(`Model ${targetModel} not found`);

            // 多段階ベンチマーク実行
            const benchmark = await runMultiLevelBenchmark(fighter, KEYS);

            // データベースへの保存
            const { error: dbError } = await supabaseClient
                .from('ai_benchmark_results')
                .insert({
                    user_id: user.id,
                    model_name: fighter.model,
                    provider: fighter.provider,
                    vision_score: benchmark.totalScore,
                    latency_ms: benchmark.totalLatency,
                    detail: JSON.stringify(benchmark.levels)
                });

            if (dbError) console.error("Database Insert Error:", dbError.message);

            return new Response(JSON.stringify({
                success: true,
                status: "active",
                benchmark: {
                    score: benchmark.totalScore,
                    latency: benchmark.totalLatency,
                    detail: benchmark.summary,
                    levels: benchmark.levels,
                    type: 'multi_level_v1'
                }
            }), { headers: corsHeaders });
        }

        return new Response(JSON.stringify({ success: false, error: "Action not found" }), { headers: corsHeaders, status: 404 });

    } catch (error: any) {
        return new Response(JSON.stringify({ success: false, error: error.message }), { headers: corsHeaders, status: 400 });
    }
});

/**
 * 多段階ベンチマーク実行
 */
async function runMultiLevelBenchmark(fighter: any, keys: any) {
    const levels: any[] = [];
    let totalScore = 0;
    let totalLatency = 0;

    for (const [levelName, test] of Object.entries(TEST_IMAGES)) {
        const start = Date.now();
        
        const visionData: AIRequest = {
            action: 'test_vision',
            content: test.prompt,
            imageBase64: test.base64,
            mimeType: "image/png"
        };

        try {
            const response = await callAI(fighter, keys, visionData);
            const latency = Date.now() - start;
            
            // スコア判定: 回答に正解キーワードが含まれているか
            const isCorrect = test.answer.some(ans => 
                response.toLowerCase().includes(ans.toLowerCase())
            );
            
            const score = isCorrect ? test.points : 0;
            totalScore += score;
            totalLatency += latency;

            levels.push({
                level: levelName,
                score,
                maxPoints: test.points,
                latency,
                response: response.substring(0, 100),
                passed: isCorrect
            });

        } catch (e: any) {
            const latency = Date.now() - start;
            totalLatency += latency;
            
            levels.push({
                level: levelName,
                score: 0,
                maxPoints: test.points,
                latency,
                response: `Error: ${e.message}`,
                passed: false
            });
        }
    }

    // サマリー生成
    const passedCount = levels.filter(l => l.passed).length;
    const summary = `${passedCount}/3テスト通過 (L1:${levels[0]?.passed ? '✓' : '✗'} L2:${levels[1]?.passed ? '✓' : '✗'} L3:${levels[2]?.passed ? '✓' : '✗'})`;

    return {
        totalScore,
        totalLatency,
        levels,
        summary
    };
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
        body: JSON.stringify({ model, max_tokens: 256, messages: [{ role: "user", content }] })
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

// --- Model List ---

async function gatherAllCandidates(supabase: any): Promise<any[]> {
    const { data: latestResults } = await supabase
        .from('ai_benchmark_results')
        .select('model_name, vision_score, latency_ms')
        .order('tested_at', { ascending: false });

    const promises = Object.entries(KEYS).map(async ([provider, key]) => {
        if (!key) return [];
        try {
            const models = await fetchDynamicModels(provider, key);
            return models.map(m => {
                const history = latestResults?.find((r: any) => r.model_name === m);
                const score = history 
                    ? (history.vision_score * 10) - Math.floor(history.latency_ms / 100)
                    : 500;
                return { provider, model: m, score };
            });
        } catch { return []; }
    });

    const results = (await Promise.all(promises)).flat();
    return results.sort((a, b) => b.score - a.score);
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