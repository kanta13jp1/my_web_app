// AI Assistant Edge Function: Advanced 6-Level Vision Benchmark
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
 * 6段階難易度別テスト画像
 * 簡単→難しいの順でモデルの実力差を明確化
 */
const TEST_IMAGES = {
    // Level 1: 色認識（簡単）- ほぼ全モデル正解
    level1: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAX0lEQVR4nO3PQQ0AIBDAMMC/50MEj4ZkVbDtWX87OuBVA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA9oFUoUBf3Xr7AgAAAAASUVORK5CYII=",
        prompt: "この画像の色を日本語1文字で答えてください（例：青）",
        answers: ["赤", "red"],
        points: 10,
        description: "色認識"
    },
    // Level 2: 単純OCR（簡単）- 大きな数字
    level2: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAIAAABMXPacAAACxUlEQVR4nO3bMUorURSA4RshkCKNjUVgIGAUhICNoK1VJDtwAbZpBF2Eop0rcAUprNMJCiIpElJIMJWdhGAhKPO6YUjnw3n/fZP/67zV8fw5KQQraZoGcdboAVadAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkAZgCYAWAGgBkABgdotVqVHzo6OmJn/l1eAMwAsP8vQKPRoEf4TZWY/1E7TdOdnZ3JZJJ/fH5+3t3dpUb6dVFfQL/fX9p+p9Mp0/ZD5AEuLy+XXs7Pz5FJihPvV9DDw8P+/n7+ZW9v7/HxkZqnIPFewMXFxdLL2dkZMkmhIr2A6XS6tbX1/f2dvbRarclksrYW7yfm70T6+1xdXeW3H0I4PT0t3/ZDnBfw/v6eJMnHx0f2srGx8fr6WqvVwKkKEuNn6ubmJr/9EEKv1yvl9kOEF/D5+dlsNt/e3rKXer0+m83W19fBqYoT3QXc3t7mtx9CODk5Kev2Q2wXkKZpu90ejUbZS7VafXl5SZIEnKpQcV3A3d1dfvshhOPj4xJvP8R2AYeHh4PBIPuxUqkMh8N2u81NVLiILuDp6Sm//RBCt9st9/ZDVAFW5G8PS2L5CprNZpubm19fX9nLwcHB/f09ONK/EcsFXF9f57cfVuPjHyK5gPl8niTJYrHIXra3t8fjcSn/+LMkigCrrPwfscgZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYAmAFgBoAZAGYA2B9eJKHHJvW42wAAAABJRU5ErkJggg==",
        prompt: "この画像に書かれている数字を1文字で答えてください",
        answers: ["7"],
        points: 10,
        description: "単純OCR"
    },
    // Level 3: 複雑なカウント（中程度）- 異なる色・形を区別
    level3: {
        base64: "iVBORw0KGgoAAAANSUhEUgAAAMgAAABkCAIAAABM5OhcAAACb0lEQVR4nO3c0W6bQBCGUaj6/q9MLyJFrerYi9nf7Oyec9m6EuAvZjoh2Y/j2KC3X3cfAHMSFhHCIkJYRAiLCGERISwihEWEsIgQFhHCIkJYRAiLCGERISwihEWEsIgQFhHCIkJYRAiLCGERISwihEXE77sPoKB9f/CHfu73X8Jq9rCn//9WYdu2CavJ86Qevnj5vMxYr5yq6uK/moiwnrrSx9pt9bgVzjrMXi9j3xuvQzTCW96KC2HNPcz2equb25rMW7fCfT9x3U+9eBB9D7jc6fdwPizDLA1OhrXCMJs4zirn3s+ZsLoMs6yhOayOwywLaAtrnWE2d2wjn3WABSkRDWEZZjmv8jehZ934f1DfL/C/r33BsObe+M/i1a1wqGF2+o3/ROoM7zb+pRQJ62Mb/9wNdLFbc4WwbPwLGj4sG/+axg7rlo1/4p612H1wGz0synoV1o3D7I0b/75nvd7H1eYT60e9aliyqk1Yz1xvYtWqtqawbhlmB9n4Xzn3havafGK99l4fa1e1tYa1+DB7HCeO+dSL59X8dMNx9Lk91b3o30fucZ0GZx6bud7WHFd/jrMIOzljGWZpc354N8zS4K3/FX5gmPX4SnEXHk02zPKzHs+8a+iy+S7hwAtSj69UNnBYVDZ2WItv/CsbO6zN4ytV7UeJK27jX83wn1hfbPyrKRLWZuNfTKnf3fBVyY0/bEOzUmF9sfGvoGBY3zQ0sDozFqUIiwhhESEsIoRFhLCIEBYRwiJCWEQIiwhhESEsIoRFhLCIEBYRwiJCWEQIiwhhESEsIoRFhLCIEBYRwiJCWEQIiwhhESEsIv4AaHOW2Znp9HIAAAAASUVORK5CYII=",
        prompt: "この画像には赤い丸と青い四角があります。赤い丸は何個ありますか？数字のみで答えてください",
        answers: ["3"],
        points: 20,
        description: "複雑カウント"
    },
    // Level 4: 空間認識（難しい）- 位置関係の理解
    level4: {
        base64: "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",
        prompt: "この画像には黄色い星と緑の三角形があります。星は三角形の左と右、どちらにありますか？「左」か「右」で答えてください",
        answers: ["左"],
        points: 20,
        description: "空間認識"
    },
    // Level 5: 論理推論（非常に難しい）- 魔方陣パターン
    level5: {
        base64: "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0unTp0feCvAiNRyVlZV5eXmMsSeffDI5OZnHSJPFYmFJScP13LmsspK57b03Y4yxtra21tbWoaGhkYsDAwMtLS2dnZ3O6CgpHP39/cITilwuz8vLm2IHOZtMrK/v7/r++106zV1cvXp1yZIl586dY4ylpKS0t7ffvHlzzZo1d+7cOXny5OLFizs6Org3lfTltNlsFouFMfb222+HhYXxmWjS3LgxXKjVLDzcpaPcXVZW1u3btxljOp3uwIEDer3e398/NzdXLpczxjo7O/Pz87k35fO9npWVJb4xajQahUWr1SqscGnBX3Y2cziYw8G6u109yt01/fcee/bs2UqlUqg1Go34NvS1a9e4N51STwR8JSczmYzJZG7+UkOg1WqF4saNG4ODg0Ld3d0tvtrQaDTcm0oKh7+//9j3XNeuXSt8VHz7nMec97qVK1cKRVdXV3p6emdn52+//ZacnPzXX38J6zExMdyb3sM7x5TyyiuviPk4ePCgXq+fOXOmyWQSVhITE5cvX869KcIxNcjl8tLS0qKioujo6JkzZyqVSpVKFRgYGBsb+8UXXxw6dMgZTXGW/SSZijNj5wASwgEkhANICAeQEA4gIRxAQjiAhHAACeEAEsIBJIQDSAgHkBAOICEcQEI4gIRwAAnhABLCASSEA0gIB5AQDiAhHEBCOICEcAAJ4QDSfwC0FzHUVrP/HQAAAABJRU5ErkJggg==",
        prompt: "これは魔方陣の一部です。各行・列・対角線の合計が同じになります。「?」に入る数字を答えてください。数字のみで回答してください",
        answers: ["3"],
        points: 20,
        description: "論理推論"
    },
    // Level 6: 微細な違い識別（エキスパート）
    level6: {
        base64: "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",
        prompt: "この画像には5つの図形が並んでいます。1つだけ他と形が違うものがあります。それは何番目ですか？数字のみで答えてください",
        answers: ["4"],
        points: 20,
        description: "微細識別"
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

        // --- 2. 6段階ベンチマークテスト ---
        if (action === 'test_model') {
            if (!targetModel) throw new Error('Model name is required');

            const candidates = await gatherAllCandidates(supabaseClient);
            const fighter = candidates.find(c => c.model === targetModel);
            if (!fighter) throw new Error(`Model ${targetModel} not found`);

            // 多段階ベンチマーク実行
            const benchmark = await runAdvancedBenchmark(fighter, KEYS);

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
                    type: 'advanced_6level_v1'
                }
            }), { headers: corsHeaders });
        }

        return new Response(JSON.stringify({ success: false, error: "Action not found" }), { headers: corsHeaders, status: 404 });

    } catch (error: any) {
        return new Response(JSON.stringify({ success: false, error: error.message }), { headers: corsHeaders, status: 400 });
    }
});

/**
 * 6段階ベンチマーク実行
 */
async function runAdvancedBenchmark(fighter: any, keys: any) {
    const levels: any[] = [];
    let totalScore = 0;
    let totalLatency = 0;
    let passedCount = 0;

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
            const normalizedResponse = response.toLowerCase().trim();
            const isCorrect = test.answers.some(ans => 
                normalizedResponse.includes(ans.toLowerCase())
            );
            
            const score = isCorrect ? test.points : 0;
            totalScore += score;
            totalLatency += latency;
            if (isCorrect) passedCount++;

            levels.push({
                level: levelName,
                description: test.description,
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
                description: test.description,
                score: 0,
                maxPoints: test.points,
                latency,
                response: `Error: ${e.message}`,
                passed: false
            });
        }
    }

    // サマリー生成
    const totalTests = Object.keys(TEST_IMAGES).length;
    const levelResults = levels.map(l => l.passed ? '✓' : '✗').join('');
    const summary = `${passedCount}/${totalTests}通過 [${levelResults}] 合計${totalScore}/100点`;

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
        body: JSON.stringify({ model, messages: [{ role: "user", content }], max_tokens: 256 })
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
                // スコア計算: (認識率 * 10) - (速度ms / 100)
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