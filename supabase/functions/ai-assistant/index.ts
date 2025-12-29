// AI Assistant Edge Function: "The Omni-Presence"
// Fully Dynamic Model Fetching for ALL Providers

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// API Keys
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

    // ---  Dynamic Priority Queue ---
    // コストと性能のバランスを考慮した初期順序
    let providerQueue: string[] = [];

    // Vision Task
    if (requestData.imageBase64 || requestData.fileBase64) {
        // 画像はGemini/GPT/Claudeが強い
        providerQueue = ['gemini', 'openai', 'anthropic', 'grok'];
    } 
    // Standard Task
    else {
        // 安価なDeepSeekを先頭に、最強のClaude/OpenAIへ
        providerQueue = ['deepseek', 'gemini', 'openai', 'anthropic', 'grok'];
    }

    let finalResult = '';
    let usedProvider = '';
    let usedModel = '';
    let logs: string[] = [];

    // ---  The Omni-Loop ---
    for (const provider of providerQueue) {
        if (!KEYS[provider as keyof typeof KEYS]) continue; // キーがない場合はスキップ

        try {
            console.log(` Scanning models for: ${provider}...`);
            
            // 1. 動的にモデルリストを取得してソート
            const models = await fetchDynamicModels(provider, KEYS[provider as keyof typeof KEYS]!);
            console.log(`   Found ${models.length} models for ${provider}. Top: ${models[0]}`);

            // 2. モデル総当たり戦 (Failover inside Provider)
            for (const model of models) {
                try {
                    console.log(` Attempting: ${action} via ${provider} [${model}]`);
                    
                    if (provider === 'gemini') {
                        finalResult = await callGemini(model, KEYS.gemini!, requestData);
                    } else if (provider === 'anthropic') {
                        finalResult = await callAnthropic(model, KEYS.anthropic!, requestData);
                    } else {
                        // OpenAI Compatible (OpenAI, DeepSeek, Grok)
                        finalResult = await callOpenAICompatible(provider, model, KEYS[provider as keyof typeof KEYS]!, requestData);
                    }

                    // Success!
                    usedProvider = provider;
                    usedModel = model;
                    console.log(` SUCCESS: ${provider} (${model})`);
                    break; 

                } catch (e) {
                    console.warn(`   Failed [${model}]: ${e.message}`);
                    logs.push(`${provider}/${model}: ${e.message}`);
                    // Continue to next model...
                }
            }

            if (usedProvider) break; // プロバイダレベルで成功したら終了

        } catch (e) {
            console.error(` Provider Failed ${provider}: ${e.message}`);
            logs.push(`${provider}_FETCH: ${e.message}`);
        }
    }

    if (!usedProvider) {
        throw new Error(`All providers exhausted. Logs: ${logs.join(' | ')}`);
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
      note: `Used: ${usedProvider} (${usedModel})`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: usedProvider, used_model: usedModel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// ---  Dynamic Model Fetcher ---
async function fetchDynamicModels(provider: string, apiKey: string): Promise<string[]> {
    try {
        let url = '';
        let headers: any = {};
        
        // Configuration per provider
        switch (provider) {
            case 'openai':
                url = 'https://api.openai.com/v1/models';
                headers = { 'Authorization': `Bearer ${apiKey}` };
                break;
            case 'deepseek':
                url = 'https://api.deepseek.com/models';
                headers = { 'Authorization': `Bearer ${apiKey}` };
                break;
            case 'grok':
                url = 'https://api.x.ai/v1/models';
                headers = { 'Authorization': `Bearer ${apiKey}` };
                break;
            case 'anthropic':
                url = 'https://api.anthropic.com/v1/models';
                headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' };
                break;
            case 'gemini':
                url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;
                headers = {};
                break;
        }

        const resp = await fetch(url, { headers });
        if (!resp.ok) throw new Error(`Fetch failed: ${resp.status}`);
        const json = await resp.json();

        // Parsing & Sorting Logic
        let models: string[] = [];

        if (provider === 'gemini') {
            // Google format: { models: [{ name: 'models/gemini-pro' }, ...] }
            models = (json.models || [])
                .map((m: any) => m.name.replace('models/', ''))
                .filter((n: string) => n.includes('gemini') && !n.includes('vision')) // vision-onlyは除外
                .sort((a: string, b: string) => b.localeCompare(a)); // 2.0 > 1.5
        } 
        else if (provider === 'anthropic') {
             models = (json.data || [])
                .sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
                .map((m: any) => m.id);
        }
        else {
            // OpenAI Compatible (data: [{id: ...}])
            models = (json.data || [])
                .map((m: any) => m.id)
                .filter((id: string) => {
                    if (provider === 'openai') return id.includes('gpt-4') || id.includes('o1');
                    if (provider === 'deepseek') return id.includes('chat'); // deepseek-chat
                    if (provider === 'grok') return id.includes('grok');
                    return false;
                })
                .sort((a: string, b: string) => b.localeCompare(a)); // Newer versions usually higher
        }

        // Fallback if fetch returns empty but succeeds
        if (models.length === 0) throw new Error('No compatible models found');
        return models;

    } catch (e) {
        console.warn(`Fetch models failed for ${provider}, using hardcoded fallback.`);
        // Fallback constants if API list fails
        if (provider === 'openai') return ['gpt-4o', 'gpt-4-turbo'];
        if (provider === 'anthropic') return ['claude-3-5-sonnet-20241022', 'claude-3-5-sonnet-latest'];
        if (provider === 'gemini') return ['gemini-2.0-flash', 'gemini-1.5-pro'];
        if (provider === 'deepseek') return ['deepseek-chat'];
        if (provider === 'grok') return ['grok-2-latest'];
        return [];
    }
}

// ---  Callers ---

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    let url = 'https://api.openai.com/v1/chat/completions';
    if (provider === 'deepseek') url = 'https://api.deepseek.com/chat/completions';
    if (provider === 'grok') url = 'https://api.x.ai/v1/chat/completions';

    const prompt = buildPrompt(data);
    let messages: any[] = [
        { role: "system", content: "You are an executive AI. Output in Japanese." },
        { role: "user", content: prompt }
    ];
    let responseFormat = undefined;
    if (data.action.includes('json') || ['audit_subscriptions', 'hold_board_meeting', 'proactive_intervention'].includes(data.action)) {
        responseFormat = { type: "json_object" };
    }
    
    // Vision (OpenAI/Grok only)
    if (data.imageBase64 && (provider === 'openai' || provider === 'grok')) {
         messages = [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType||'image/jpeg'};base64,${data.imageBase64}` } }] }];
    }

    const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages, response_format: responseFormat, temperature: 0.7 })
    });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.choices?.[0]?.message?.content || '';
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let system = "Executive AI. Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting'].includes(data.action)) system += " Valid JSON only.";
    
    let messages: any[] = [{ role: "user", content: prompt }];
    if (data.imageBase64) {
        messages = [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: data.mimeType||"image/jpeg", data: data.imageBase64 } }, { type: "text", text: prompt }] }];
    }

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 4000, system, messages })
    });
    if (!resp.ok) throw new Error(`${resp.status} ${await resp.text()}`);
    const json = await resp.json();
    return json.content?.[0]?.text || '';
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const body: any = { generationConfig: { temperature: 0.7 }, contents: [] };
    if (data.imageBase64) {
        body.contents.push({ parts: [{ text: prompt }, { inline_data: { mime_type: data.mimeType||'image/jpeg', data: data.imageBase64 } }] });
    } else {
        body.contents.push({ parts: [{ text: prompt }] });
    }
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)
    });
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
        return `${jsonPrefix} Role: Chairman. Agenda: Activities(${notes}), Assets(${d.userStats?.total_points}pt). Simulate debate(Logic vs Vision vs Strategy). JSON: { "agenda": string, "discussion": string, "decision": string, "stock_price_impact": string }`;
    }
    if (action === 'proactive_intervention') {
        const d = boardData || {};
        let unaudited = d.paymentSources?.filter((s:any) => !s.last_audited_at).length || 0;
        return `${jsonPrefix} Time: ${currentTime}. Unaudited: ${unaudited}. Warn if >0. JSON: { "should_intervene": boolean, "role": string, "message": "60 chars max", "action_label": string }`;
    }
    if (action === 'audit_meal') return `${jsonPrefix} Audit meal image. JSON: { "menu_name": string, "calorie_estimate": number, "performance_score": number, "audit_result": string, "advice": string }`;
    
    // General
    if (action === 'mental_chat') return `Empathize & Advise:\n${content}`;
    if (action === 'improve') return `Refine:\n${content}`;
    
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
