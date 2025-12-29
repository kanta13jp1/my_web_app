// AI Assistant Edge Function: "The Five Emperors" (2025 Ultimate Edition v2)
// Fully optimized for discovered models (Gemini 3, GPT-5, Claude 3.7/4.5)

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
  recentMeals?: any[]
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

    // ---  Unified Model Ranking ---
    console.log(` Gathering candidates for: ${action}...`);
    
    let candidates = await gatherAllCandidates(requestData);
    if (candidates.length === 0) throw new Error('No AI models available.');

    // Sort by Score (Desc)
    candidates.sort((a, b) => b.score - a.score);
    
    // Log Top Candidates
    const topCandidates = candidates.slice(0, 5).map(c => `${c.provider}:${c.model}(${c.score})`).join(' > ');
    console.log(` Model Hierarchy: ${topCandidates}`);

    let finalResult = '';
    let winner: any = null;
    let logs: string[] = [];

    // ---  The Meritocracy Loop ---
    for (const candidate of candidates) {
        const { provider, model } = candidate;
        const startTime = Date.now();
        
        try {
            console.log(` Attempting: ${provider} [${model}]`);
            
            if (provider === 'gemini') {
                finalResult = await callGemini(model, KEYS.gemini!, requestData);
            } else if (provider === 'anthropic') {
                finalResult = await callAnthropic(model, KEYS.anthropic!, requestData);
            } else {
                finalResult = await callOpenAICompatible(provider, model, KEYS[provider as keyof typeof KEYS]!, requestData);
            }

            winner = candidate;
            await logRequest(supabaseClient, user.id, action, provider, model, 200, Date.now() - startTime);
            console.log(` WINNER: ${provider} (${model})`);
            break; 

        } catch (e) {
            const duration = Date.now() - startTime;
            const statusMatch = e.message.match(/(\d{3})/);
            const statusCode = statusMatch ? parseInt(statusMatch[1]) : 500;
            
            console.warn(` Failed [${model}]: ${e.message}`);
            logs.push(`${provider}/${model}: ${statusCode}`);
            
            await logRequest(supabaseClient, user.id, action, provider, model, statusCode, duration, e.message);
        }
    }

    if (!winner) {
        throw new Error(`All candidates exhausted. Logs: ${logs.join(' | ')}`);
    }

    let parsedResult = finalResult;
    if (['secretary_task_from_image', 'extract_subscriptions_from_file', 'audit_meal', 'evaluate_performance', 'hold_board_meeting', 'proactive_intervention', 'suggest_next_meal'].includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: winner.provider, used_model: winner.model }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// ---  2025 Model Scoring Logic (Based on Actual List) ---
function calculateModelScore(provider: string, modelId: string, isVision: boolean): number {
    let score = 0;
    const id = modelId.toLowerCase();

    // ---  GOD TIER (Score: 1100+) ---
    // The absolute bleeding edge discovered in the logs.
    if (id.includes('claude-opus-4-5') || id.includes('claude-sonnet-4-5')) score = 1200; // Claude 4.5
    else if (id.includes('gemini-3')) score = 1150; // Gemini 3.0
    else if (id.includes('gpt-5')) score = 1140; // GPT-5
    else if (id.includes('o3')) score = 1130; // OpenAI O3
    else if (id.includes('claude-3-7')) score = 1120; // Claude 3.7

    // ---  KING TIER (Score: 1000-1099) ---
    // Exceptional performance.
    else if (id.includes('gemini-2.5-pro')) score = 1050;
    else if (id.includes('o1-pro')) score = 1040;
    else if (id.includes('gpt-4.1')) score = 1030;
    else if (id.includes('deepseek-reasoner')) score = 1020; // DeepSeek R1/Reasoner

    // ---  KNIGHT TIER (Score: 900-999) ---
    // High standard for daily tasks.
    else if (id.includes('claude-3-5-sonnet')) score = 980;
    else if (id.includes('gemini-2.0-pro')) score = 970;
    else if (id.includes('gemini-2.5-flash')) score = 960;
    else if (id.includes('gpt-4o') && !id.includes('mini')) score = 950;
    else if (id.includes('o1') && !id.includes('mini')) score = 940;

    // ---  SOLDIER TIER (Score: 800-899) ---
    // Previous gen flagships.
    else if (id.includes('gemini-1.5-pro')) score = 850;
    else if (id.includes('claude-3-opus')) score = 840;
    else if (id.includes('deepseek-chat')) score = 830;
    else if (id.includes('grok-2')) score = 820;

    // ---  SCOUT TIER (Score: < 800) ---
    // Fast & Cheap.
    else if (id.includes('claude-3-5-haiku') || id.includes('claude-haiku-4-5')) score = 780; // Haiku 4.5 is strong
    else if (id.includes('gemini-2.0-flash')) score = 760;
    else if (id.includes('gpt-4o-mini')) score = 700;
    else if (id.includes('gemini-1.5-flash')) score = 680;

    // ---  Contextual Adjustments ---
    
    // Vision Task Penalty
    if (isVision) {
        if (id.includes('deepseek') && !id.includes('vision')) score = -1; // Text only
        if (id.includes('o1') || id.includes('o3')) score -= 200; // Reasoning models are often slow/bad at vision
        if (id.includes('nano') || id.includes('embedding')) score = -1;
    }

    // Preview/Exp Bonus (Newer is usually smarter)
    if (id.includes('preview') || id.includes('exp') || id.includes('latest')) score += 10;

    return score;
}

async function gatherAllCandidates(data: AIRequest): Promise<{provider: string, model: string, score: number}[]> {
    const isVision = !!(data.imageBase64 || data.fileBase64);
    const promises: Promise<any>[] = [];
    const candidates: {provider: string, model: string, score: number}[] = [];

    Object.keys(KEYS).forEach(provider => {
        const key = KEYS[provider as keyof typeof KEYS];
        if (key) {
            promises.push(
                fetchDynamicModels(provider, key)
                    .then(models => {
                        models.forEach(model => {
                            const score = calculateModelScore(provider, model, isVision);
                            if (score > 0) candidates.push({ provider, model, score });
                        });
                    })
                    .catch(e => console.warn(`Skipping ${provider}: ${e.message}`))
            );
        }
    });

    await Promise.all(promises);
    return candidates;
}

// ---  API Fetchers ---
async function fetchDynamicModels(provider: string, apiKey: string): Promise<string[]> {
    try {
        let url = '';
        let headers: any = {};
        switch (provider) {
            case 'openai': url = 'https://api.openai.com/v1/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; break;
            case 'deepseek': url = 'https://api.deepseek.com/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; break;
            case 'grok': url = 'https://api.x.ai/v1/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; break;
            case 'anthropic': url = 'https://api.anthropic.com/v1/models'; headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' }; break;
            case 'gemini': url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`; headers = {}; break;
        }
        const resp = await fetch(url, { headers });
        if (!resp.ok) throw new Error(`Fetch failed: ${resp.status}`);
        const json = await resp.json();
        let models: string[] = [];
        
        if (provider === 'gemini') {
            models = (json.models || []).map((m: any) => m.name.replace('models/', '')).filter((n: string) => n.includes('gemini') && !n.includes('vision') && !n.includes('embedding'));
        } else if (provider === 'anthropic') {
             models = (json.data || []).map((m: any) => m.id);
        } else {
            models = (json.data || []).map((m: any) => m.id).filter((id: string) => {
                if (provider === 'openai') return id.includes('gpt-') || id.includes('o1') || id.includes('o3') || id.includes('chatgpt-4o');
                if (provider === 'deepseek') return id.includes('deepseek');
                if (provider === 'grok') return id.includes('grok');
                return false;
            });
        }
        return models;
    } catch (e) {
        if (provider === 'openai') return ['gpt-4o'];
        if (provider === 'anthropic') return ['claude-3-5-sonnet-20241022'];
        if (provider === 'gemini') return ['gemini-2.0-flash'];
        if (provider === 'deepseek') return ['deepseek-chat'];
        return [];
    }
}

// ---  Callers ---
async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    let url = 'https://api.openai.com/v1/chat/completions';
    if (provider === 'deepseek') url = 'https://api.deepseek.com/chat/completions';
    if (provider === 'grok') url = 'https://api.x.ai/v1/chat/completions';
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "system", content: "You are an executive AI. Output in Japanese." }, { role: "user", content: prompt }];
    let responseFormat = undefined;
    
    // DeepSeek & o1 often don't support json_object mode, so we rely on prompt engineering
    if (provider !== 'deepseek' && !model.includes('o1') && !model.includes('o3')) {
        if (data.action.includes('json') || ['audit_subscriptions', 'hold_board_meeting', 'proactive_intervention', 'suggest_next_meal'].includes(data.action)) responseFormat = { type: "json_object" };
    }

    if (data.imageBase64 && (provider === 'openai' || provider === 'grok')) messages = [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType||'image/jpeg'};base64,${data.imageBase64}` } }] }];
    const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` }, body: JSON.stringify({ model, messages, response_format: responseFormat, temperature: 0.7 }) });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.choices?.[0]?.message?.content || '';
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let system = "Executive AI. Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting', 'suggest_next_meal'].includes(data.action)) system += " Valid JSON only.";
    let messages: any[] = [{ role: "user", content: prompt }];
    if (data.imageBase64) messages = [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: data.mimeType||"image/jpeg", data: data.imageBase64 } }, { type: "text", text: prompt }] }];
    const resp = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST', headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }, body: JSON.stringify({ model, max_tokens: 4000, system, messages }) });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.content?.[0]?.text || '';
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const body: any = { generationConfig: { temperature: 0.7 }, contents: [] };
    if (data.imageBase64) body.contents.push({ parts: [{ text: prompt }, { inline_data: { mime_type: data.mimeType||'image/jpeg', data: data.imageBase64 } }] });
    else body.contents.push({ parts: [{ text: prompt }] });
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body) });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

// ---  Prompts & Helper ---
function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime, recentMeals } = data;
    const jsonPrefix = "Output purely valid JSON.";
    if (action === 'suggest_next_meal') {
        const mealHistory = recentMeals ? recentMeals.map((m:any) => m.menu_name || 'Unspecified').join(', ') : 'None';
        return `${jsonPrefix} Role: CHO (3-Star Chef). Time: ${currentTime}. History: ${mealHistory}. Suggest OPTIMAL next meal. JSON: { "menu_name": "Name", "reason": "Reason", "ingredients": ["A","B"], "recipe_steps": ["1","2"], "calorie_estimate": 500, "nutrients": { "protein": "20g", "fat": "15g", "carbs": "60g" } }`;
    }
    if (action === 'proactive_intervention') {
        const d = boardData || {};
        let unaudited = 0;
        if (d.paymentSources) unaudited = d.paymentSources.filter((s:any) => !s.last_audited_at).length;
        return `${jsonPrefix} Time: ${currentTime}. Unaudited: ${unaudited}. JSON: { "should_intervene": boolean, "role": "CFO"|"CHO"|"CSO"|"CHRO", "message": "JP text (60 chars)", "action_label": "Button" }`;
    }
    if (action === 'hold_board_meeting') {
        const d = boardData || {};
        const notes = d.recentNotes?.map((n:any) => n.title).join(',') || 'None';
        return `${jsonPrefix} Role: Chairman. Agenda: Activities(${notes}), Assets(${d.userStats?.total_points}pt). Simulate debate. JSON: { "agenda": string, "discussion": string, "decision": string, "stock_price_impact": string }`;
    }
    if (action === 'audit_meal') return `${jsonPrefix} Role: Nutritionist. Audit image. JSON: { "menu_name": string, "calorie_estimate": number, "performance_score": number, "audit_result": string, "advice": string }`;
    if (action === 'mental_chat') return `Empathize & Advise:\n${content}`;
    if (action === 'improve') return `Refine:\n${content}`;
    if (action === 'extract_subscriptions_from_file') return `${jsonPrefix} Extract subscriptions. JSON: [{ "service_name": string, "price": number, "description": string }]`;
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

async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try {
        await supabase.from('ai_request_logs').insert({
            user_id: userId,
            action: action,
            provider: provider,
            model: model,
            status_code: status,
            duration_ms: duration,
            error_message: errorMsg.substring(0, 1000)
        });
    } catch(e) { console.error("Logging failed:", e); }
}
