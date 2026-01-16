// AI Assistant Edge Function: "The Five Emperors" (Ultimate Edition)
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

const FALLBACK_MODELS = [
    { provider: 'gemini', model: 'gemini-2.0-flash' },
    { provider: 'openai', model: 'gpt-4o-mini' },
    { provider: 'anthropic', model: 'claude-3-haiku-20240307' }
];

// Define types to avoid 'any'
interface AIRequest {
    action: string;
    model?: string;
    content?: string;
    imageBase64?: string;
    mimeType?: string;
    targetLanguage?: string;
    userId?: string;
    recentNotes?: Record<string, unknown>[]; // Better than any[]
    userStats?: Record<string, unknown>; // Better than any
    participants?: string[];
}

interface Fighter {
    provider: string;
    model: string;
}

interface ApiKeys {
    gemini?: string;
    openai?: string;
    anthropic?: string;
    deepseek?: string;
    grok?: string;
}

// Interfaces for API payloads
interface OpenAIMessage {
    role: string;
    content: string | Array<{ type: string; text?: string; image_url?: { url: string } }>;
}

interface AnthropicContent {
    type: string;
    text?: string;
    source?: { type: string; media_type: string; data: string };
}

interface GeminiPart {
    text?: string;
    inline_data?: { mime_type: string; data: string };
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

        const tryAIChain = async (originalPrompt: string, image?: { base64: string, mime: string }) => {
            if (targetModel) {
                const fighter = { provider: inferProvider(targetModel), model: targetModel };
                return await callAI(fighter, KEYS, { ...requestData, content: originalPrompt, imageBase64: image?.base64, mimeType: image?.mime });
            }
            let lastError;
            for (const model of FALLBACK_MODELS) {
                try {
                    return await callAI(model, KEYS, { ...requestData, content: originalPrompt, imageBase64: image?.base64, mimeType: image?.mime });
                } catch (e: unknown) { // Use unknown instead of any
                    const errorMessage = e instanceof Error ? e.message : String(e);
                    console.error(`Model ${model.model} failed:`, errorMessage);
                    lastError = e;
                }
            }
            throw lastError || new Error("All AI models failed.");
        };

        // --- 1. GET MODELS (Fix for 404 Error) ---
        if (action === 'get_models') {
            return new Response(
                JSON.stringify({
                    success: true,
                    models: [
                        { name: 'gemini-2.0-flash', provider: 'Google', description: 'Fast & Versatile' },
                        { name: 'gpt-4o', provider: 'OpenAI', description: 'High Intelligence' },
                        { name: 'claude-3-opus', provider: 'Anthropic', description: 'Complex Tasks' },
                        // Add more models as needed
                    ]
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
        }

        // --- 2. リアル断捨離クエスト (Vision Analysis) ---
        if (action === 'analyze_danshari_item') {
            if (!requestData.imageBase64) throw new Error("Image required");

            const prompt = `
            あなたは「自分株式会社」のCSO（最高戦略責任者）です。
            ユーザーがアップロードした「断捨離候補のモノ」の画像を分析し、辛口かつ的確に判定を下してください。

            判定基準:
            1. 「ときめき」が感じられるか？
            2. 実用性はあるか？（ボロボロではないか？）
            3. 過去への執着ではないか？

            出力フォーマット (JSONのみ):
            {
                "item_name": "アイテム名（例: 古びたマグカップ）",
                "spark_joy_score": 0-100の数値 (低いほど捨てるべき),
                "decision": "KEEP" または "DISCARD",
                "reason": "判定理由（例: 持ち手が欠けており、実用性がありません。）",
                "witty_comment": "CSOとしての皮肉やユーモアのあるコメント（例: これを『ヴィンテージ』と呼ぶのは無理がありますね。）"
            }
            `;

            const resultStr = await tryAIChain(prompt, { base64: requestData.imageBase64, mime: requestData.mimeType || 'image/jpeg' });
            const cleanJson = resultStr.replace(/```json|```/g, '').trim();
            const result = JSON.parse(cleanJson);
            return new Response(JSON.stringify({ success: true, result }), { headers: corsHeaders });
        }

        // --- 3. Board Meeting ---
        if (action === 'hold_board_meeting') {
            const topic = requestData.content;
            const prompt = `
            あなたは「自分株式会社」の取締役会シミュレーターです。
            議題: ${topic}
            役割: CEO(Steve), CTO(Linus), CMO(Gary), CFO(Warren).
            JSON出力: { "meeting_minutes": [{"role": "...", "name": "...", "text": "..."}], "conclusion": "..." }
            `;
            const resultStr = await tryAIChain(prompt);
            const cleanJson = resultStr.replace(/```json|```/g, '').trim();
            const result = JSON.parse(cleanJson);
            return new Response(JSON.stringify({ success: true, result }), { headers: corsHeaders });
        }

        // --- 4. Generic Actions ---
        if (['improve', 'summarize', 'expand', 'translate', 'suggest_title'].includes(action)) {
            const prompt = `Action: ${action}\nContent: ${requestData.content}`;
            const result = await tryAIChain(prompt);
            return new Response(JSON.stringify({ success: true, result }), { headers: corsHeaders });
        }

        return new Response(JSON.stringify({ success: false, error: `Action "${action}" not found` }), { headers: corsHeaders, status: 404 });

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return new Response(JSON.stringify({ success: false, error: errorMessage }), { headers: corsHeaders, status: 400 });
    }
});

function inferProvider(modelName: string): string {
    if (modelName.startsWith('gpt')) return 'openai';
    if (modelName.startsWith('claude')) return 'anthropic';
    if (modelName.startsWith('gemini')) return 'gemini';
    return 'openai';
}

async function callAI(fighter: Fighter, keys: ApiKeys, data: AIRequest): Promise<string> {
    if (fighter.provider === 'gemini') return await callGemini(fighter.model, keys.gemini!, data);
    if (fighter.provider === 'anthropic') return await callAnthropic(fighter.model, keys.anthropic!, data);
    return await callOpenAICompatible(fighter.model, keys.openai!, data);
}

// (Helper functions: callOpenAICompatible, callAnthropic, callGemini)
// Removed unused 'provider' argument
async function callOpenAICompatible(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const messages: OpenAIMessage[] = [{ role: "user", content: data.content || "" }];
    if (data.imageBase64) {
        messages[0].content = [
            { type: "text", text: data.content || "" },
            { type: "image_url", image_url: { url: `data:${data.mimeType};base64,${data.imageBase64}` } }
        ];
    }
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages, max_tokens: 1024 })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`OpenAI: ${json.error?.message || "Unknown error"}`);
    return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const content: AnthropicContent[] = [{ type: "text", text: data.content || "" }];
    if (data.imageBase64) {
        content.unshift({ type: "image", source: { type: "base64", media_type: data.mimeType || "image/jpeg", data: data.imageBase64 } });
    }
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 1024, messages: [{ role: "user", content }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Anthropic: ${json.error?.message || "Unknown error"}`);
    return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const parts: GeminiPart[] = [{ text: data.content || "" }];
    if (data.imageBase64) {
        parts.push({ inline_data: { mime_type: data.mimeType || "image/jpeg", data: data.imageBase64 } });
    }
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Gemini: ${json.error?.message || "Unknown error"}`);
    return json.candidates[0].content.parts[0].text;
}