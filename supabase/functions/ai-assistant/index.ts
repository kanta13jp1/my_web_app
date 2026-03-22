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
    { provider: 'openai', model: 'gpt-4o-mini' },
    { provider: 'anthropic', model: 'claude-3-haiku-20240307' },
    { provider: 'gemini', model: 'gemini-2.5-flash' },
    { provider: 'deepseek', model: 'deepseek-chat' },
];

const MODEL_CATALOG = [
    {
        name: 'claude-sonnet-4-6',
        provider: 'Anthropic',
        description: '品質重視の推奨モデル',
        score: 980,
    },
    {
        name: 'gpt-5.4',
        provider: 'OpenAI',
        description: '品質重視の推奨モデル',
        score: 970,
    },
    {
        name: 'gpt-4o-mini',
        provider: 'OpenAI',
        description: '速度重視の推奨モデル',
        score: 910,
    },
    {
        name: 'claude-3-haiku-20240307',
        provider: 'Anthropic',
        description: '速度重視の推奨モデル',
        score: 890,
    },
    {
        name: 'gemini-2.5-flash',
        provider: 'Google',
        description: 'Gemini 系の推奨モデル',
        score: 860,
    },
    {
        name: 'gemma-3n-e2b-it',
        provider: 'Google',
        description: 'Gemini 系の軽量モデル',
        score: 820,
    },
    {
        name: 'deepseek-reasoner',
        provider: 'DeepSeek',
        description: '推論特化の DeepSeek モデル',
        score: 780,
    },
    {
        name: 'deepseek-chat',
        provider: 'DeepSeek',
        description: '高速な DeepSeek チャットモデル',
        score: 760,
    },
];

// 型定義の追加（any排除のため）
interface AIRequest {
    action: string;
    model?: string;
    content?: string;
    text?: string;
    styleName?: string;
    styleInstruction?: string;
    imageBase64?: string;
    mimeType?: string;
    targetLanguage?: string;
    userId?: string;
    recentNotes?: Record<string, unknown>[];
    userStats?: Record<string, unknown>;
    participants?: string[];
    useMagi?: boolean;
    melchiorModel?: string;
    balthasarModel?: string;
    casperModel?: string;
    synthesisModel?: string;
}

interface Fighter {
    provider: string;
    model: string;
}

interface MagiNodeProfile {
    nodeName: string;
    viewpoint: string;
    instruction: string;
    provider: string;
    defaultModel: string;
}

interface MagiOpinion {
    nodeName: string;
    viewpoint: string;
    content: string;
}

const MAGI_OPINION_MAX_LENGTH = 900;
const DEFAULT_MELCHIOR_MODEL = 'gpt-4o-mini';
const DEFAULT_BALTHASAR_MODEL = 'claude-sonnet-4-6';
const DEFAULT_CASPER_MODEL = 'gemini-2.5-flash';
const DEFAULT_SYNTHESIS_MODEL = 'claude-sonnet-4-6';

const MAGI_NODE_PROFILES: MagiNodeProfile[] = [
    {
        nodeName: 'MELCHIOR',
        viewpoint: '論理・分析重視',
        instruction: 'Provide logical, evidence-based analysis with clear tradeoffs and practical recommendations.',
        provider: 'openai',
        defaultModel: DEFAULT_MELCHIOR_MODEL,
    },
    {
        nodeName: 'BALTHASAR',
        viewpoint: '共感・人間理解重視',
        instruction: 'Focus on emotional nuance, empathy, and how the response will feel for the user.',
        provider: 'anthropic',
        defaultModel: DEFAULT_BALTHASAR_MODEL,
    },
    {
        nodeName: 'CASPER',
        viewpoint: '批判・リスク検討',
        instruction: 'Look for blind spots, edge cases, and strategic risks before making a recommendation.',
        provider: 'gemini',
        defaultModel: DEFAULT_CASPER_MODEL,
    },
];

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

        const requestContent = requestData.content ?? requestData.text;
        const runFallbackChain = async (
            originalPrompt: string,
            image?: { base64: string, mime: string },
        ) => {
            if (targetModel) {
                 const fighter = { provider: inferProvider(targetModel), model: targetModel };
                 if (!isProviderAvailable(fighter.provider)) {
                    throw new Error(`${fighter.provider} API key is not configured`);
                 }
                 return await callAI(fighter, KEYS, { ...requestData, content: originalPrompt, imageBase64: image?.base64, mimeType: image?.mime });
            }
            let lastError;
            for (const model of FALLBACK_MODELS) {
                try {
                    return await callAI(model, KEYS, { ...requestData, content: originalPrompt, imageBase64: image?.base64, mimeType: image?.mime });
                } catch (e: unknown) {
                    const msg = e instanceof Error ? e.message : String(e);
                    console.error(`Model ${model.model} failed:`, msg);
                    lastError = e;
                }
            }
            throw lastError || new Error("All AI models failed.");
        };

        const runPromptWithStrategy = async (
            originalPrompt: string,
            image?: { base64: string, mime: string },
        ) => {
            const shouldUseMagi = requestData.useMagi ?? true;
            if (!shouldUseMagi) {
                return await runFallbackChain(originalPrompt, image);
            }
            return await runMagiChain({
                prompt: originalPrompt,
                requestData: {
                    ...requestData,
                    content: originalPrompt,
                    imageBase64: image?.base64,
                    mimeType: image?.mime,
                },
                image,
                fallback: runFallbackChain,
            });
        };

        // --- 1. GET MODELS ---
        if (action === 'get_models') {
            const models = MODEL_CATALOG.filter((item) => isProviderAvailable(item.provider));
            return new Response(
                JSON.stringify({
                    success: true,
                    models,
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
        }

        // --- 2. リアル断捨離クエスト ---
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

            const resultStr = await runFallbackChain(prompt, { base64: requestData.imageBase64!, mime: requestData.mimeType || 'image/jpeg' });
            const cleanJson = resultStr.replace(/```json|```/g, '').trim();
            const result = JSON.parse(cleanJson);
            return new Response(JSON.stringify({ success: true, result }), { headers: corsHeaders });
        }

        // --- 3. Board Meeting ---
        if (action === 'hold_board_meeting') {
            const contextFromClient = requestContent ?? '';
            const systemPrompt = `
あなたは「自分株式会社」の緊急役員会議 BI レポート生成システムです。
雑談ではなく、受け取った現状データだけを根拠に、4名の役員が短く具体的な分析を返してください。

必須ルール:
- 数字が渡されている項目は、できるだけ具体的に引用する
- 不明な数字は推測しない
- 各発言は「現状の数字 -> 問題解釈 -> 次の一手」の順で 2〜4 文にする
- 抽象論や精神論だけで終わらせない
- CFO はサブスク・ポイント・固定費・投資対効果を見る
- CKO はノート・継続実行・深い作業・知識の実行率を見る
- CHRO はストリーク・禁欲・回復行動・習慣崩れの兆候を見る
- CEO は全体を統合し、48時間以内の具体的な実行判断を下す

以下の JSON だけを返してください。コードブロックや前置きは禁止です。
{
  "messages": [
    {
      "speaker_name": "AI CFO",
      "role": "CFO",
      "content": "CFO としての分析..."
    },
    {
      "speaker_name": "AI CKO",
      "role": "CKO",
      "content": "CKO としての分析..."
    },
    {
      "speaker_name": "AI CHRO",
      "role": "CHRO",
      "content": "CHRO としての分析..."
    },
    {
      "speaker_name": "AI CEO",
      "role": "CEO",
      "content": "CEO としての統合判断..."
    }
  ],
  "conclusion": "CEO が今すぐ実行すべき具体策..."
}
`;

            const finalPrompt = `${systemPrompt}\n\n[CURRENT BOARD CONTEXT]\n${contextFromClient}`;
            const resultStr = await runPromptWithStrategy(finalPrompt);
            const match = resultStr.match(/\{[\s\S]*\}/);
            if (!match) {
                throw new Error("AI response did not contain valid JSON.");
            }
            const cleanJson = match[0];
            const result = JSON.parse(cleanJson);
            const rawMessages = Array.isArray(result.messages) ? result.messages : [];
            const normalizedMessages = rawMessages
                .map((item: Record<string, unknown>) => {
                    const role = typeof item.role === 'string' ? item.role : 'CEO';
                    const speakerName =
                        typeof item.speaker_name === 'string'
                            ? item.speaker_name
                            : typeof item.speakerName === 'string'
                                ? item.speakerName
                                : `AI ${role}`;
                    const content = typeof item.content === 'string' ? item.content.trim() : '';
                    if (!content) return null;
                    return {
                        speaker_name: speakerName,
                        role,
                        content,
                    };
                })
                .filter(Boolean);
            const formattedResult = {
                messages: normalizedMessages,
                conclusion: typeof result.conclusion === 'string' ? result.conclusion.trim() : '',
            };

            return new Response(JSON.stringify({ success: true, result: formattedResult }), { headers: corsHeaders });
        }

        if (action === 'test_model') {
            const benchmarkPrompt = [
                'You are running a connectivity benchmark.',
                'Reply with the exact text "ping-ok" and nothing else.',
            ].join('\n');
            const startedAt = Date.now();
            const result = await runFallbackChain(benchmarkPrompt);
            const latency = Date.now() - startedAt;
            const normalized = result.trim();
            const passed = normalized === 'ping-ok';
            const score = passed ? Math.max(60, 100 - Math.floor(latency / 100)) : 0;
            const benchmark = {
                score,
                latency,
                detail: passed
                    ? `Smoke test passed in ${latency}ms`
                    : `Unexpected response: ${normalized.slice(0, 120)}`,
                levels: [
                    {
                        level: 'level1',
                        description: 'Connectivity smoke test',
                        passed,
                        score,
                        maxPoints: 100,
                        response: normalized,
                        latency,
                    },
                ],
            };

            if (!passed) {
                return new Response(
                    JSON.stringify({
                        success: false,
                        error: `Model returned an unexpected benchmark response: ${normalized.slice(0, 120)}`,
                        benchmark,
                    }),
                    { headers: corsHeaders, status: 400 },
                );
            }

            return new Response(
                JSON.stringify({ success: true, benchmark }),
                { headers: corsHeaders },
            );
        }
        
        // --- 4. Generic Actions ---
        if (['improve', 'summarize', 'expand', 'translate', 'suggest_title', 'custom_prompt'].includes(action)) {
             const normalizedStyleInstruction = requestData.styleInstruction?.trim();
             const targetLanguagePrompt =
                action === 'translate' && requestData.targetLanguage?.trim()
                    ? `\nTarget language: ${requestData.targetLanguage.trim()}`
                    : '';
             const stylePrompt = normalizedStyleInstruction
                ? `\nStyle preset: ${requestData.styleName || 'custom'}\nStyle instruction: ${normalizedStyleInstruction}\nFollow this style while completing the action.`
                : '';
             const prompt = action === 'custom_prompt'
                ? `Action: custom_prompt${stylePrompt}${targetLanguagePrompt}\nSaved prompt:\n${requestContent ?? ''}`
                : `Action: ${action}${stylePrompt}${targetLanguagePrompt}\nContent: ${requestContent ?? ''}`;
             const result = await runPromptWithStrategy(prompt);
             return new Response(JSON.stringify({ success: true, result }), { headers: corsHeaders });
        }

        return new Response(JSON.stringify({ success: false, error: `Action "${action}" not found` }), { headers: corsHeaders, status: 404 });

    } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        
        // Check for quota/rate limit errors
        const isQuotaError = /quota|rate limit/i.test(msg);
        const status = isQuotaError ? 429 : 400;

        return new Response(JSON.stringify({ success: false, error: msg }), { headers: corsHeaders, status });
    }
});

function inferProvider(modelName: string): string {
    const normalized = modelName.toLowerCase().trim();
    if (normalized.startsWith('deepseek')) return 'deepseek';
    if (normalized.startsWith('claude')) return 'anthropic';
    if (normalized.startsWith('gemini') || normalized.startsWith('gemma')) return 'gemini';
    if (normalized.startsWith('gpt') || normalized.startsWith('o')) return 'openai';
    return 'openai';
}

function normalizeMagiText(text: string | null | undefined): string | null {
    const normalized = text?.trim();
    if (!normalized) {
        return null;
    }
    if (normalized.length <= MAGI_OPINION_MAX_LENGTH) {
        return normalized;
    }
    return normalized.slice(0, MAGI_OPINION_MAX_LENGTH);
}

function buildMagiNodePrompt(originalPrompt: string, profile: MagiNodeProfile): string {
    return [
        `You are MAGI system node "${profile.nodeName}".`,
        `Viewpoint: ${profile.viewpoint}`,
        `Additional instruction: ${profile.instruction}`,
        'Preserve the user\'s requested output language and any explicit format constraints from the original prompt.',
        '',
        '[USER_PROMPT]',
        originalPrompt,
    ].join('\n');
}

function buildMagiSynthesisPrompt(originalPrompt: string, opinions: MagiOpinion[]): string {
    const sections = opinions.flatMap((opinion) => [
        `[${opinion.nodeName} / ${opinion.viewpoint}]`,
        opinion.content,
        '',
    ]);

    return [
        'You are the MAGI synthesis node.',
        'Review the opinions from the other nodes, compare tradeoffs, and merge them into one final answer.',
        'Return exactly one JSON object with the merged recommendation and key reasoning.',
        'Keep the answer concise and do not use Markdown code fences.',
        'Preserve the original prompt language and any explicit format constraints.',
        '',
        '[ORIGINAL_PROMPT]',
        originalPrompt,
        '',
        ...sections,
    ].join('\n');
}

function resolveMagiNodeModel(profile: MagiNodeProfile, requestData: AIRequest): string {
    const requestedModel = requestData.model?.trim();
    const safeGeminiModel =
        requestedModel && inferProvider(requestedModel) === 'gemini'
            ? requestedModel
            : DEFAULT_CASPER_MODEL;

    switch (profile.nodeName) {
        case 'MELCHIOR':
            return requestData.melchiorModel?.trim() || DEFAULT_MELCHIOR_MODEL;
        case 'BALTHASAR':
            return requestData.balthasarModel?.trim() || DEFAULT_BALTHASAR_MODEL;
        case 'CASPER':
            return requestData.casperModel?.trim() || safeGeminiModel;
        default:
            return profile.defaultModel;
    }
}

function buildMagiSynthesisFighters(requestData: AIRequest): Fighter[] {
    const fighters: Fighter[] = [];
    const addedProviders = new Set<string>();

    const addFighter = (modelName: string | undefined) => {
        const normalized = modelName?.trim();
        if (!normalized) {
            return;
        }
        const provider = inferProvider(normalized);
        if (addedProviders.has(provider) || !isProviderAvailable(provider)) {
            return;
        }
        fighters.push({ provider, model: normalized });
        addedProviders.add(provider);
    };

    addFighter(requestData.synthesisModel || DEFAULT_SYNTHESIS_MODEL);
    addFighter(requestData.casperModel || DEFAULT_CASPER_MODEL);
    addFighter(requestData.melchiorModel || DEFAULT_MELCHIOR_MODEL);
    addFighter(requestData.balthasarModel || DEFAULT_BALTHASAR_MODEL);
    addFighter('deepseek-chat');

    return fighters;
}

async function runMagiNode(params: {
    prompt: string;
    profile: MagiNodeProfile;
    requestData: AIRequest;
    image?: { base64: string; mime: string };
}): Promise<MagiOpinion | null> {
    const { prompt, profile, requestData, image } = params;
    const model = resolveMagiNodeModel(profile, requestData);
    const provider = inferProvider(model);
    if (!isProviderAvailable(provider)) {
        console.info(`MAGI node skipped: ${profile.nodeName} (${provider}, no API key)`);
        return null;
    }

    try {
        const response = await callAI(
            { provider, model },
            KEYS,
            {
                ...requestData,
                content: buildMagiNodePrompt(prompt, profile),
                imageBase64: image?.base64,
                mimeType: image?.mime,
            },
        );
        const content = normalizeMagiText(response);
        if (!content) {
            return null;
        }
        return {
            nodeName: profile.nodeName,
            viewpoint: profile.viewpoint,
            content,
        };
    } catch (error) {
        console.error(`MAGI node failed: ${profile.nodeName}`, error);
        return null;
    }
}

async function runMagiBestEffort(params: {
    prompt: string;
    requestData: AIRequest;
    image?: { base64: string; mime: string };
}): Promise<string> {
    const { prompt, requestData, image } = params;
    let lastError: unknown;
    for (const fighter of buildMagiSynthesisFighters(requestData)) {
        try {
            const response = await callAI(
                fighter,
                KEYS,
                {
                    ...requestData,
                    content: prompt,
                    imageBase64: image?.base64,
                    mimeType: image?.mime,
                },
            );
            const normalized = normalizeMagiText(response);
            if (normalized) {
                return normalized;
            }
        } catch (error) {
            console.error(`MAGI synthesis fallback failed: ${fighter.model}`, error);
            lastError = error;
        }
    }
    if (lastError instanceof Error) {
        throw lastError;
    }
    throw new Error('MAGI synthesis fallback failed.');
}

async function runMagiChain(params: {
    prompt: string;
    requestData: AIRequest;
    image?: { base64: string; mime: string };
    fallback: (originalPrompt: string, image?: { base64: string; mime: string }) => Promise<string>;
}): Promise<string> {
    const { prompt, requestData, image, fallback } = params;
    const opinions = (await Promise.all(
        MAGI_NODE_PROFILES.map((profile) =>
            runMagiNode({ prompt, profile, requestData, image }),
        ),
    )).filter((opinion): opinion is MagiOpinion => opinion !== null);

    if (opinions.length === 0) {
        try {
            return await runMagiBestEffort({ prompt, requestData, image });
        } catch {
            return await fallback(prompt, image);
        }
    }

    if (opinions.length === 1) {
        return opinions[0].content;
    }

    const synthesisPrompt = buildMagiSynthesisPrompt(prompt, opinions);
    try {
        return await runMagiBestEffort({
            prompt: synthesisPrompt,
            requestData,
            image,
        });
    } catch {
        return opinions[0].content;
    }
}

// キーの型定義
type KeyMap = typeof KEYS;

async function callAI(fighter: Fighter, keys: KeyMap, data: AIRequest): Promise<string> {
    if (!isProviderAvailable(fighter.provider)) {
        throw new Error(`${fighter.provider} API key is not configured`);
    }
    if (fighter.provider === 'gemini') return await callGemini(fighter.model, keys.gemini!, data);
    if (fighter.provider === 'anthropic') return await callAnthropic(fighter.model, keys.anthropic!, data);
    if (fighter.provider === 'deepseek') return await callDeepSeek(fighter.model, keys.deepseek!, data);
    return await callOpenAICompatible(fighter.model, keys.openai!, data, {
        providerLabel: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1/chat/completions',
    });
}

// ---------------- Helper functions ----------------
// Removed unused 'provider' arg, typed arrays instead of any[]

function isProviderAvailable(providerName: string): boolean {
    switch (providerName.toLowerCase()) {
        case 'google':
        case 'gemini':
            return Boolean(KEYS.gemini);
        case 'openai':
            return Boolean(KEYS.openai);
        case 'anthropic':
            return Boolean(KEYS.anthropic);
        case 'deepseek':
            return Boolean(KEYS.deepseek);
        case 'xai':
        case 'grok':
            return false;
        default:
            return false;
    }
}

async function callOpenAICompatible(
    model: string,
    apiKey: string,
    data: AIRequest,
    options: { providerLabel: string; baseUrl: string },
): Promise<string> {
    const messages: Array<{ role: string; content: string | Array<Record<string, unknown>> }> = [{ role: "user", content: data.content || "" }];
    if (data.imageBase64) {
        messages[0].content = [
            { type: "text", text: data.content || "" },
            { type: "image_url", image_url: { url: `data:${data.mimeType};base64,${data.imageBase64}` } }
        ];
    }
    const resp = await fetch(options.baseUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages, max_tokens: 1024 })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`${options.providerLabel}: ${json.error?.message || "Unknown error"}`);
    return json.choices[0].message.content;
}

async function callDeepSeek(model: string, apiKey: string, data: AIRequest): Promise<string> {
    return await callOpenAICompatible(model, apiKey, data, {
        providerLabel: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/chat/completions',
    });
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const content: Array<Record<string, unknown>> = [{ type: "text", text: data.content || "" }];
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
    const parts: Array<Record<string, unknown>> = [{ text: data.content || "" }];
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
