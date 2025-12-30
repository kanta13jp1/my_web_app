// AI Assistant Edge Function: "The Five Emperors" (CMO Upgrade / Battle Mode)
// 概要: 複数の次世代AIモデルを統合制御し、単独実行または死活監視を行うシステム。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS設定
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// APIキー管理
const KEYS = {
  gemini: Deno.env.get('GEMINI_API_KEY'),
  openai: Deno.env.get('OPENAI_API_KEY'),
  anthropic: Deno.env.get('ANTHROPIC_API_KEY'),
  deepseek: Deno.env.get('DEEPSEEK_API_KEY'),
  grok: Deno.env.get('XAI_API_KEY'),
};

interface AIRequest {
  action: string
  model?: string      // 死活監視対象のモデル名
  content?: string
  imageBase64?: string
  mimeType?: string
  multi_response?: boolean
  boardData?: any
  currentTime?: string
  missionData?: any
  missionName?: string
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
    const { action, model: targetModel, multi_response } = requestData

    // --- 1. モデル一覧取得 ---
    if (action === 'get_models') {
        const models = await gatherAllCandidates(requestData);
        return new Response(JSON.stringify({ success: true, models }), { headers: corsHeaders });
    }

    // --- 2. 死活監視テスト ---
    if (action === 'test_model') {
        if (!targetModel) throw new Error('Model name is required');
        const candidates = await gatherAllCandidates(requestData);
        const fighter = candidates.find(c => c.model === targetModel);
        
        if (!fighter) throw new Error(`Model ${targetModel} not found`);

        const testData: AIRequest = { action: 'test', content: 'Ping' };
        if (fighter.provider === 'gemini') await callGemini(fighter.model, KEYS.gemini!, testData);
        else if (fighter.provider === 'anthropic') await callAnthropic(fighter.model, KEYS.anthropic!, testData);
        else await callOpenAICompatible(fighter.provider, fighter.model, KEYS[fighter.provider as keyof typeof KEYS]!, testData);

        return new Response(JSON.stringify({ success: true, status: "active" }), { headers: corsHeaders });
    }

    // --- 3. Battle Mode ---
    if (multi_response) {
        let candidates = await gatherAllCandidates(requestData);
        candidates.sort((a, b) => b.score - a.score);
        const providers = ['anthropic', 'gemini', 'openai'];
        const champions = providers.map(p => candidates.find(c => c.provider === p)).filter(Boolean);
        const fighters = champions.slice(0, 2); 
        
        const results = await Promise.all(fighters.map(async (fighter) => {
            const start = Date.now();
            try {
                let text = '';
                if (fighter.provider === 'gemini') text = await callGemini(fighter.model, KEYS.gemini!, requestData);
                else if (fighter.provider === 'anthropic') text = await callAnthropic(fighter.model, KEYS.anthropic!, requestData);
                else text = await callOpenAICompatible(fighter.provider, fighter.model, KEYS[fighter.provider as keyof typeof KEYS]!, requestData);
                
                await logRequest(supabaseClient, user.id, action, fighter.provider, fighter.model, 200, Date.now() - start);
                return { success: true, provider: fighter.provider, model: fighter.model, result: shouldParseJson(action) ? parseJsonResult(text) : text };
            } catch (e) {
                return { success: false, provider: fighter.provider, error: e.message };
            }
        }));
        return new Response(JSON.stringify({ success: true, is_multi: true, results: results.filter(r => r.success) }), { headers: corsHeaders });
    }

    // --- 4. Single Mode ---
    let candidates = await gatherAllCandidates(requestData);
    candidates.sort((a, b) => b.score - a.score);
    let finalResult = '';
    let winner = null;

    for (const candidate of candidates) {
        const startTime = Date.now();
        try {
            if (candidate.provider === 'gemini') finalResult = await callGemini(candidate.model, KEYS.gemini!, requestData);
            else if (candidate.provider === 'anthropic') finalResult = await callAnthropic(candidate.model, KEYS.anthropic!, requestData);
            else finalResult = await callOpenAICompatible(candidate.provider, candidate.model, KEYS[candidate.provider as keyof typeof KEYS]!, requestData);
            winner = candidate;
            await logRequest(supabaseClient, user.id, action, candidate.provider, candidate.model, 200, Date.now() - startTime);
            break;
        } catch (e) {
            await logRequest(supabaseClient, user.id, action, candidate.provider, candidate.model, 500, Date.now() - startTime, e.message);
        }
    }

    if (!winner) throw new Error('All models failed');
    return new Response(JSON.stringify({ success: true, result: shouldParseJson(action) ? parseJsonResult(finalResult) : finalResult, provider: winner.provider, used_model: winner.model }), { headers: corsHeaders });

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: corsHeaders, status: 400 });
  }
});

// --- Helpers ---

function shouldParseJson(action: string): boolean {
    return ['hold_board_meeting', 'suggest_next_meal', 'proactive_intervention', 'analyze_image', 'audit_meal', 'digital_danshari_chat', 'check_bedtime_permission', 'verify_mission_proof', 'draft_press_release'].includes(action);
}

function calculateModelScore(provider: string, modelId: string, isVision: boolean): number {
    const id = modelId.toLowerCase();
    if (id.includes('gemma') || id.includes('nano') || id.includes('lite')) return -1;
    if (id.includes('claude-opus-4-5') || id.includes('claude-sonnet-4-5')) return 1200;
    if (id.includes('gemini-3')) return 1150;
    if (id.includes('gpt-5')) return 1140;
    if (id.includes('claude-3-7')) return 1120;
    if (id.includes('gemini-2.5-pro')) return 1050;
    if (id.includes('gpt-4o') && !id.includes('mini')) return 950;
    if (id.includes('gemini-2.0-flash')) return 840;
    if (id.includes('gpt-4o-mini')) return 700;
    return 500;
}

async function gatherAllCandidates(data: AIRequest): Promise<any[]> {
    const isVision = !!(data.imageBase64);
    const promises = Object.entries(KEYS).map(async ([provider, key]) => {
        if (!key) return [];
        try {
            const models = await fetchDynamicModels(provider, key);
            return models.map(m => ({ provider, model: m, score: calculateModelScore(provider, m, isVision) })).filter(c => c.score > 0);
        } catch { return []; }
    });
    return (await Promise.all(promises)).flat();
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

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages: [{ role: "user", content: buildPrompt(data) }] })
    });
    
    const json = await resp.json();
    if (!resp.ok) throw new Error(`${provider} Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    if (!json.choices || !json.choices[0]) throw new Error(`${provider} returned empty choices`);
    
    return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 1024, messages: [{ role: "user", content: buildPrompt(data) }] })
    });
    
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Anthropic Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    if (!json.content || !json.content[0]) throw new Error(`Anthropic returned empty content`);
    
    return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ contents: [{ parts: [{ text: buildPrompt(data) }] }] })
    });
    
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Gemini Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    if (!json.candidates || !json.candidates[0]?.content?.parts?.[0]?.text) {
        throw new Error(`Gemini returned empty result. Check if model "${model}" is available.`);
    }
    
    return json.candidates[0].content.parts[0].text;
}

function buildPrompt(data: AIRequest): string {
    if (data.action === 'test') return "Respond only with 'OK'.";
    return data.content || "Hello";
}

function parseJsonResult(result: string): any {
    try { return JSON.parse(result.replace(/```json/g, '').replace(/```/g, '').trim()); } 
    catch { return { error: "Parse Failed", raw: result }; }
}

async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try { await supabase.from('ai_request_logs').insert({ user_id: userId, action, provider, model, status_code: status, duration_ms: duration, error_message: errorMsg }); } catch {}
}