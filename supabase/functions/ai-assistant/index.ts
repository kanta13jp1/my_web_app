// AI Assistant Edge Function: 2025 Future-Proof Edition
// Dynamic Model Fetching & Total Failover

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// API Keys
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
const DEEPSEEK_API_KEY = Deno.env.get('DEEPSEEK_API_KEY')
const XAI_API_KEY = Deno.env.get('XAI_API_KEY')

// Static Providers Config
const PROVIDERS = {
    deepseek: { model: 'deepseek-chat', url: 'https://api.deepseek.com/chat/completions', key: DEEPSEEK_API_KEY },
    gemini:   { model: 'gemini-2.0-flash', url: 'https://generativelanguage.googleapis.com/v1beta/models/', key: GEMINI_API_KEY },
    openai:   { model: 'gpt-4o', url: 'https://api.openai.com/v1/chat/completions', key: OPENAI_API_KEY },
    grok:     { model: 'grok-2-latest', url: 'https://api.x.ai/v1/chat/completions', key: XAI_API_KEY },
    // Anthropic is now Dynamic
    anthropic:{ key: ANTHROPIC_API_KEY }, 
};

interface AIRequest {
  action: string
  content?: string
  imageBase64?: string
  fileBase64?: string
  mimeType?: string
  boardData?: any
  subscriptions?: any[]
  userStats?: any
  paymentSources?: any[]
  currentTime?: string
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
    const { action } = requestData

    // ---  Priority Queue Strategy ---
    let providerQueue: string[] = [];

    // Image/Vision Tasks
    if (requestData.imageBase64 || requestData.fileBase64) {
        // Claude (Dynamic) -> Gemini -> OpenAI -> Grok
        providerQueue = ['anthropic', 'gemini', 'openai', 'grok'];
    } 
    // Standard Tasks
    else {
        // DeepSeek (Cheap) -> Anthropic (Smartest) -> OpenAI -> Gemini -> Grok
        providerQueue = ['deepseek', 'anthropic', 'openai', 'gemini', 'grok'];
    }

    let finalResult = '';
    let usedProvider = '';
    let usedModel = '';
    let attemptLogs: string[] = [];

    // ---  The Grand Loop ---
    for (const provider of providerQueue) {
        try {
            // Check API Key existence
            if (provider === 'anthropic' && !ANTHROPIC_API_KEY) continue;
            if (provider !== 'anthropic' && !PROVIDERS[provider].key) continue;

            console.log(` Attempting: ${action} via ${provider}...`);
            
            if (provider === 'anthropic') {
                // Dynamic Fetch & Attack
                const result = await callAnthropicDynamic(ANTHROPIC_API_KEY!, requestData);
                finalResult = result.text;
                usedModel = result.model;
            } else if (provider === 'gemini') {
                const conf = PROVIDERS.gemini;
                finalResult = await callGemini(conf.model, conf.key!, requestData);
                usedModel = conf.model;
            } else {
                // OpenAI / DeepSeek / Grok
                const conf = PROVIDERS[provider];
                finalResult = await callOpenAICompatible(conf.url, conf.model, conf.key!, requestData);
                usedModel = conf.model;
            }

            usedProvider = provider;
            console.log(` Success with ${provider} (${usedModel})`);
            break; 

        } catch (e) {
            console.error(` Failed with ${provider}: ${e.message}`);
            attemptLogs.push(`${provider}: ${e.message}`);
        }
    }

    if (!usedProvider) {
        throw new Error(`All providers failed. Logs: ${attemptLogs.join(' | ')}`);
    }

    // JSON Parsing
    let parsedResult = finalResult;
    const jsonActions = [
      'secretary_task_from_image', 'extract_subscriptions_from_file', 
      'audit_meal', 'evaluate_performance', 'hold_board_meeting',
      'proactive_intervention'
    ];
    if (jsonActions.includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    // Log Usage
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id, 
      action: action, 
      note: `Winner: ${usedProvider} (${usedModel})`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: usedProvider, used_model: usedModel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// ---  Anthropic Dynamic Caller (The 2025 Strategy) ---
async function callAnthropicDynamic(apiKey: string, data: AIRequest): Promise<{text: string, model: string}> {
    // 1. Fetch available models
    const modelsUrl = 'https://api.anthropic.com/v1/models';
    const listResp = await fetch(modelsUrl, {
        method: 'GET',
        headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        }
    });

    if (!listResp.ok) throw new Error('Failed to fetch Anthropic models');
    const listJson = await listResp.json();
    
    // 2. Sort by creation date (Newest First)
    // We assume the user wants the smartest/newest model (Claude 4.5, etc.)
    const models = listJson.data
        .sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .map((m: any) => m.id);

    console.log(`Found Anthropic models: ${models.join(', ')}`);

    let lastError = null;

    // 3. Try each model until one works
    for (const modelId of models) {
        try {
            console.log(`Trying Anthropic model: ${modelId}`);
            const text = await callAnthropicSingle(modelId, apiKey, data);
            return { text, model: modelId };
        } catch (e) {
            console.warn(`Model ${modelId} failed: ${e.message}`);
            lastError = e;
            // Continue to next model...
        }
    }
    
    throw lastError || new Error('All Anthropic models failed');
}

async function callAnthropicSingle(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const url = 'https://api.anthropic.com/v1/messages';
    const prompt = buildPrompt(data);
    
    let systemPrompt = "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting', 'evaluate_performance', 'proactive_intervention', 'extract_subscriptions_from_file', 'audit_meal'].includes(data.action)) {
        systemPrompt += " You MUST output strictly valid JSON only. No markdown.";
    }

    let messages: any[] = [{ role: "user", content: prompt }];
    if (data.imageBase64) {
        messages = [{
            role: "user",
            content: [
                { type: "image", source: { type: "base64", media_type: data.mimeType || "image/jpeg", data: data.imageBase64 } },
                { type: "text", text: prompt }
            ]
        }];
    }

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        },
        body: JSON.stringify({
            model: model,
            max_tokens: 4000,
            system: systemPrompt,
            messages: messages
        })
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Status ${response.status}: ${errText}`);
    }
    const json = await response.json();
    return json.content?.[0]?.text || '';
}

// --- Universal Client ---
async function callOpenAICompatible(endpoint: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [
        { role: "system", content: "You are an executive AI for 'Jibun Inc.' Output in Japanese." },
        { role: "user", content: prompt }
    ];
    let responseFormat = undefined;
    if (data.action.includes('json') || ['audit_subscriptions', 'extract_subscriptions_from_file', 'proactive_intervention', 'audit_meal', 'hold_board_meeting'].includes(data.action)) {
        responseFormat = { type: "json_object" };
    }
    if (data.imageBase64 && (endpoint.includes('openai') || endpoint.includes('x.ai'))) {
        messages = [{ role: "system", content: "Executive AI." }, { role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType || 'image/jpeg'};base64,${data.imageBase64}` } }] }];
    }

    const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages, temperature: 0.7, response_format: responseFormat })
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`API Error: ${response.status} - ${errText}`);
    }
    const json = await response.json();
    return json.choices?.[0]?.message?.content || '';
}

// --- Gemini Client ---
async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const prompt = buildPrompt(data);
    const body: any = { generationConfig: { temperature: 0.7 }, contents: [] };
    if (data.imageBase64) {
        body.contents.push({ parts: [{ text: prompt }, { inline_data: { mime_type: data.mimeType || 'image/jpeg', data: data.imageBase64 } }] });
    } else {
        body.contents.push({ parts: [{ text: prompt }] });
    }
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!response.ok) { const err = await response.text(); throw new Error(`Gemini Error: ${err}`); }
    const json = await response.json();
    return json.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

// --- Prompt Builder ---
function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime, subscriptions } = data;
    const jsonPrefix = "Output valid JSON only.";
    
    if (action === 'hold_board_meeting') {
        const d = boardData || {};
        const notes = d.recentNotes?.map((n:any) => n.title).join(', ') || 'None';
        const cost = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
        return `${jsonPrefix} Role: Board Chairman (Claude 4.5/Opus). Agenda: Activities(${notes}), Finance(${cost}JPY), Assets(${d.userStats?.total_points}pt). Simulate discussion between Logic(DeepSeek/GPT), Vision(Gemini/Grok), and Strategy(You). Output JSON: { "agenda": string, "discussion": string, "decision": string, "stock_price_impact": string }`;
    }
    if (action === 'proactive_intervention') {
        const d = boardData || {};
        let unaudited = 0;
        if (d.paymentSources) unaudited = d.paymentSources.filter((s:any) => !s.last_audited_at || new Date(s.last_audited_at).getMonth() !== new Date().getMonth()).length;
        return `${jsonPrefix} Time: ${currentTime}. Assets: ${d.userStats?.total_points}pt. Unaudited: ${unaudited}. If unaudited>0 warn as CFO. Late night warn as CHO. Else advise as CSO. JSON: { "should_intervene": boolean, "role": string, "message": "60 chars max", "action_label": string }`;
    }
    if (action === 'audit_subscriptions') return `Role: CFO. Audit strictly:\n${subscriptions?.map((s:any) => `- ${s.service_name}: ${s.price}`).join('\n')}`;
    if (action === 'audit_meal') return `${jsonPrefix} Role: Nutritionist. Audit image. JSON: { "menu_name": string, "calorie_estimate": number, "performance_score": number, "audit_result": string, "advice": string }`;
    if (action === 'extract_subscriptions_from_file') return `${jsonPrefix} Extract subscriptions. JSON: [{ "service_name": string, "price": number, "description": string }]`;
    
    // General
    if (action === 'improve') return `Refine this business text:\n${content}`;
    if (action === 'mental_chat') return `Empathize and advise:\n${content}`;
    if (action === 'expand') return `Expand creatively:\n${content}`;
    if (action === 'suggest_title') return `Suggest 5 project titles:\n${content}`;
    return content || '';
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json/g, '').replace(/```/g, '').trim();
      const first = cleaned.indexOf(cleaned.startsWith('[') ? '[' : '{');
      const last = cleaned.lastIndexOf(cleaned.endsWith(']') ? ']' : '}');
      if (first !== -1 && last !== -1) cleaned = cleaned.substring(first, last + 1);
      return JSON.parse(cleaned);
    } catch (e) { return {}; }
}
