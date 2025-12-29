// AI Assistant Edge Function: "The All-Seeing Eye"
// Detailed Logging & Observability

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

    // ---  Priority Queue ---
    let providerQueue: string[] = [];
    if (requestData.imageBase64 || requestData.fileBase64) {
        providerQueue = ['gemini', 'openai', 'anthropic', 'grok'];
    } else {
        providerQueue = ['deepseek', 'gemini', 'openai', 'anthropic', 'grok'];
    }

    let finalResult = '';
    let usedProvider = '';
    let usedModel = '';
    let logs: string[] = [];

    // ---  The Loop ---
    for (const provider of providerQueue) {
        if (!KEYS[provider as keyof typeof KEYS]) continue;

        try {
            console.log(` Scanning models for: ${provider}...`);
            const models = await fetchDynamicModels(provider, KEYS[provider as keyof typeof KEYS]!);
            
            for (const model of models) {
                const startTime = Date.now();
                try {
                    console.log(` Attempting: ${action} via ${provider} [${model}]`);
                    
                    if (provider === 'gemini') {
                        finalResult = await callGemini(model, KEYS.gemini!, requestData);
                    } else if (provider === 'anthropic') {
                        finalResult = await callAnthropic(model, KEYS.anthropic!, requestData);
                    } else {
                        finalResult = await callOpenAICompatible(provider, model, KEYS[provider as keyof typeof KEYS]!, requestData);
                    }

                    usedProvider = provider;
                    usedModel = model;
                    
                    //  Success Log
                    await logRequest(supabaseClient, user.id, action, provider, model, 200, Date.now() - startTime);
                    break; 

                } catch (e) {
                    const duration = Date.now() - startTime;
                    const statusMatch = e.message.match(/(\d{3})/);
                    const statusCode = statusMatch ? parseInt(statusMatch[1]) : 500;
                    
                    console.warn(` Failed [${model}]: ${e.message}`);
                    logs.push(`${provider}/${model}: ${statusCode}`);
                    
                    //  Error Log (429, 402, etc.)
                    await logRequest(supabaseClient, user.id, action, provider, model, statusCode, duration, e.message);
                }
            }
            if (usedProvider) break;

        } catch (e) {
            console.error(` Provider Failed ${provider}: ${e.message}`);
        }
    }

    if (!usedProvider) {
        throw new Error(`All providers exhausted. Logs: ${logs.join(' | ')}`);
    }

    // JSON Parsing
    let parsedResult = finalResult;
    if (['secretary_task_from_image', 'extract_subscriptions_from_file', 'audit_meal', 'evaluate_performance', 'hold_board_meeting', 'proactive_intervention'].includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: usedProvider, used_model: usedModel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// ---  Logger Function ---
async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try {
        await supabase.from('ai_request_logs').insert({
            user_id: userId,
            action: action,
            provider: provider,
            model: model,
            status_code: status,
            duration_ms: duration,
            error_message: errorMsg.substring(0, 1000) // Truncate if too long
        });
    } catch(e) {
        console.error("Logging failed:", e);
    }
}

// ... (以下、前回と同じ fetchDynamicModels, Callers, buildPrompt, parseJsonResult 関数を維持) ...
//  長くなるため省略しますが、前回のコードの関数群をここに続けてください。
// このPowerShellコマンドは既存ファイルを上書きするため、以下のヘルパー関数群が必要です。

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
            models = (json.models || []).map((m: any) => m.name.replace('models/', '')).filter((n: string) => n.includes('gemini') && !n.includes('vision')).sort((a: string, b: string) => b.localeCompare(a));
        } else if (provider === 'anthropic') {
             models = (json.data || []).sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()).map((m: any) => m.id);
        } else {
            models = (json.data || []).map((m: any) => m.id).filter((id: string) => {
                if (provider === 'openai') return id.includes('gpt-4') || id.includes('o1');
                if (provider === 'deepseek') return id.includes('chat');
                if (provider === 'grok') return id.includes('grok');
                return false;
            }).sort((a: string, b: string) => b.localeCompare(a));
        }
        if (models.length === 0) throw new Error('No compatible models');
        return models;
    } catch (e) {
        if (provider === 'openai') return ['gpt-4o'];
        if (provider === 'anthropic') return ['claude-3-5-sonnet-20241022'];
        if (provider === 'gemini') return ['gemini-2.0-flash'];
        if (provider === 'deepseek') return ['deepseek-chat'];
        if (provider === 'grok') return ['grok-2-latest'];
        return [];
    }
}

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    let url = 'https://api.openai.com/v1/chat/completions';
    if (provider === 'deepseek') url = 'https://api.deepseek.com/chat/completions';
    if (provider === 'grok') url = 'https://api.x.ai/v1/chat/completions';
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "system", content: "You are an executive AI. Output in Japanese." }, { role: "user", content: prompt }];
    let responseFormat = undefined;
    if (data.action.includes('json') || ['audit_subscriptions', 'hold_board_meeting', 'proactive_intervention'].includes(data.action)) responseFormat = { type: "json_object" };
    if (data.imageBase64 && (provider === 'openai' || provider === 'grok')) messages = [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType||'image/jpeg'};base64,${data.imageBase64}` } }] }];
    const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` }, body: JSON.stringify({ model, messages, response_format: responseFormat, temperature: 0.7 }) });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.choices?.[0]?.message?.content || '';
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let system = "Executive AI. Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting'].includes(data.action)) system += " Valid JSON only.";
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

function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime } = data;
    const jsonPrefix = "Output purely valid JSON.";
    if (action === 'hold_board_meeting') {
        const d = boardData || {};
        const notes = d.recentNotes?.map((n:any) => n.title).join(',') || 'None';
        return `${jsonPrefix} Role: Chairman. Agenda: Activities(${notes}), Assets(${d.userStats?.total_points}pt). Simulate debate. JSON: { "agenda": string, "discussion": string, "decision": string, "stock_price_impact": string }`;
    }
    if (action === 'proactive_intervention') {
        const d = boardData || {};
        let unaudited = d.paymentSources?.filter((s:any) => !s.last_audited_at).length || 0;
        return `${jsonPrefix} Time: ${currentTime}. Unaudited: ${unaudited}. Warn if >0. JSON: { "should_intervene": boolean, "role": string, "message": "60 chars max", "action_label": string }`;
    }
    if (action === 'audit_meal') return `${jsonPrefix} Audit meal image. JSON: { "menu_name": string, "calorie_estimate": number, "performance_score": number, "audit_result": string, "advice": string }`;
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
