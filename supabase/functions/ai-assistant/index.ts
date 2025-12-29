// AI Assistant Edge Function: "The Five Emperors" (Evidence Verification Mode)

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
  multi_response?: boolean
  missionData?: any
  missionName?: string // Added for evidence check
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
    const { action, multi_response } = requestData

    // ---  Battle Mode ---
    if (multi_response) {
        let candidates = await gatherAllCandidates(requestData);
        if (candidates.length === 0) throw new Error('No AI models available.');
        candidates.sort((a, b) => b.score - a.score);

        const providers = ['anthropic', 'gemini', 'openai'];
        const champions = [];
        for (const p of providers) {
            const best = candidates.find(c => c.provider === p);
            if (best) champions.push(best);
        }
        const fighters = champions.slice(0, 2); 
        
        const results = await Promise.all(fighters.map(async (fighter) => {
            const start = Date.now();
            try {
                let text = '';
                if (fighter.provider === 'gemini') text = await callGemini(fighter.model, KEYS.gemini!, requestData);
                else if (fighter.provider === 'anthropic') text = await callAnthropic(fighter.model, KEYS.anthropic!, requestData);
                else text = await callOpenAICompatible(fighter.provider, fighter.model, KEYS[fighter.provider as keyof typeof KEYS]!, requestData);
                
                await logRequest(supabaseClient, user.id, action, fighter.provider, fighter.model, 200, Date.now() - start);
                
                let parsed = text;
                if (['hold_board_meeting', 'suggest_next_meal', 'proactive_intervention', 'analyze_image', 'audit_meal', 'digital_danshari_chat', 'check_bedtime_permission', 'verify_mission_proof'].includes(action)) {
                    parsed = parseJsonResult(text);
                }
                return { success: true, provider: fighter.provider, model: fighter.model, result: parsed };
            } catch (e) {
                return { success: false, provider: fighter.provider, error: e.message };
            }
        }));

        const successes = results.filter(r => r.success);
        if (successes.length === 0) throw new Error('All models failed.');

        return new Response(
            JSON.stringify({ success: true, is_multi: true, results: successes }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )
    }

    // ---  Single Mode ---
    let candidates = await gatherAllCandidates(requestData);
    if (candidates.length === 0) throw new Error('No AI models available.');
    candidates.sort((a, b) => b.score - a.score);

    let finalResult = '';
    let winner: any = null;
    let logs: string[] = [];
    
    for (const candidate of candidates) {
        const { provider, model } = candidate;
        const startTime = Date.now();
        try {
            console.log(` Attempting: ${provider} [${model}]`);
            if (provider === 'gemini') finalResult = await callGemini(model, KEYS.gemini!, requestData);
            else if (provider === 'anthropic') finalResult = await callAnthropic(model, KEYS.anthropic!, requestData);
            else finalResult = await callOpenAICompatible(provider, model, KEYS[provider as keyof typeof KEYS]!, requestData);

            winner = candidate;
            await logRequest(supabaseClient, user.id, action, provider, model, 200, Date.now() - startTime);
            break; 
        } catch (e) {
            logs.push(`${provider}/${model}: ${e.message}`);
            await logRequest(supabaseClient, user.id, action, provider, model, 500, Date.now() - startTime, e.message);
        }
    }

    if (!winner) throw new Error(`All candidates exhausted. Logs: ${logs.join('|')}`);

    let parsedResult = finalResult;
    // Add 'verify_mission_proof' to JSON parse list
    if (['hold_board_meeting', 'suggest_next_meal', 'proactive_intervention', 'analyze_image', 'audit_meal', 'digital_danshari_chat', 'check_bedtime_permission', 'verify_mission_proof'].includes(action)) {
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

// ---  Helper Functions ---
function calculateModelScore(provider: string, modelId: string, isVision: boolean): number {
    let score = 0;
    const id = modelId.toLowerCase();

    if (id.includes('gemma')) return -1; 
    if (id.includes('nano')) return -1;
    if (id.includes('lite')) return -1;

    if (id.includes('claude-opus-4-5') || id.includes('claude-sonnet-4-5')) score = 1200;
    else if (id.includes('gemini-3')) score = 1150;
    else if (id.includes('gpt-5')) score = 1140;
    else if (id.includes('claude-3-7')) score = 1120;
    else if (id.includes('gemini-2.5-pro')) score = 1050;
    else if (id.includes('claude-3-5-sonnet')) score = 980;
    else if (id.includes('gemini-2.0-pro')) score = 970;
    else if (id.includes('gpt-4o') && !id.includes('mini')) score = 950;
    else if (id.includes('gemini-1.5-pro')) score = 850;
    else if (id.includes('gemini-2.0-flash')) score = 840;
    else if (id.includes('gpt-4o-mini')) score = 700; 

    if (isVision) {
        if (id.includes('deepseek')) score = -1; 
        if (id.includes('o1') || id.includes('o3')) score = -1; 
    }

    return score;
}

async function gatherAllCandidates(data: AIRequest): Promise<{provider: string, model: string, score: number}[]> {
    const isVision = !!(data.imageBase64 || data.fileBase64);
    const promises: Promise<any>[] = [];
    const candidates: {provider: string, model: string, score: number}[] = [];
    Object.keys(KEYS).forEach(provider => {
        const key = KEYS[provider as keyof typeof KEYS];
        if (key) {
            promises.push(fetchDynamicModels(provider, key).then(models => {
                models.forEach(model => {
                    const score = calculateModelScore(provider, model, isVision);
                    if (score > 0) candidates.push({ provider, model, score });
                });
            }).catch(() => {}));
        }
    });
    await Promise.all(promises);
    return candidates;
}

async function fetchDynamicModels(provider: string, apiKey: string): Promise<string[]> {
    try {
        let url = ''; let headers: any = {};
        switch (provider) {
            case 'openai': url = 'https://api.openai.com/v1/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; break;
            case 'anthropic': url = 'https://api.anthropic.com/v1/models'; headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' }; break;
            case 'gemini': url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`; headers = {}; break;
            default: return [];
        }
        const resp = await fetch(url, { headers });
        if (!resp.ok) return [];
        const json = await resp.json();
        if (provider === 'gemini') return (json.models || []).map((m: any) => m.name.replace('models/', ''));
        if (provider === 'anthropic') return (json.data || []).map((m: any) => m.id);
        return (json.data || []).map((m: any) => m.id);
    } catch { return []; }
}

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "system", content: "You are an executive AI. Output in Japanese." }, { role: "user", content: prompt }];
    if (data.imageBase64) messages = [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType||'image/jpeg'};base64,${data.imageBase64}` } }] }];
    const resp = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` }, body: JSON.stringify({ model, messages, response_format: {type: "json_object"} }) });
    const json = await resp.json(); return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "user", content: prompt }];
    if (data.imageBase64) messages = [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: data.mimeType||"image/jpeg", data: data.imageBase64 } }, { type: "text", text: prompt }] }];
    const resp = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST', headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }, body: JSON.stringify({ model, max_tokens: 4000, messages }) });
    const json = await resp.json(); return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const body: any = { contents: [] };
    if (data.imageBase64) body.contents.push({ parts: [{ text: prompt }, { inline_data: { mime_type: data.mimeType||'image/jpeg', data: data.imageBase64 } }] });
    else body.contents.push({ parts: [{ text: prompt }] });
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body) });
    const json = await resp.json(); return json.candidates[0].content.parts[0].text;
}

// ---  Prompts (Enhanced with Evidence Verification) ---
function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime, missionData, missionName, recentMeals } = data;
    const jsonPrefix = "Output purely valid JSON.";

    //  EVIDENCE VERIFICATION (Strict Gatekeeper)
    if (action === 'verify_mission_proof') {
        return `${jsonPrefix}
        Role: Strict Task Inspector (Demon Coach).
        Language: Japanese (日本語).
        Task: Verify if the photo proves the mission "${missionName}" is COMPLETED perfectly.
        Context: User claims they finished "${missionName}".
        
        Logic:
        - If "Washing Dishes": Sink must be EMPTY and CLEAN. No bubbles, no food.
        - If "Cleaning": Floor/Desk must be TIDY.
        - If photo is irrelevant/dark/blurry: REJECT immediately.
        - If photo shows mess: REJECT and scold.
        - Only APPROVE if it looks pristine.

        Output JSON:
        {
          "verified": boolean,
          "comment": "String (Strict verdict in Japanese. e.g. '汚れが残っている。やり直し。' or 'よし、完璧だ。')",
          "score": 80 (0-100)
        }`;
    }

    if (action === 'check_bedtime_permission') {
        const missions = missionData || {};
        // Filter tasks that are NOT verified (false)
        const incomplete = Object.keys(missions).filter(k => !missions[k]);
        const isPerfect = incomplete.length === 0;
        return `${jsonPrefix}
        Role: Gatekeeper of Sleep. Language: Japanese.
        Mission Status (Verified by AI): ${JSON.stringify(missions)}.
        Output JSON:
        {
          "permission_granted": ${isPerfect},
          "title": "タイトル (Japanese)",
          "message": "判定理由 (Japanese)",
          "missing_tasks": ["未完了タスク"],
          "punishment": "罰則指令 (Japanese)"
        }`;
    }

    if (action === 'suggest_next_meal') {
        const mealHistory = recentMeals ? recentMeals.map((m:any) => m.menu_name || 'Unspecified').join(', ') : 'None';
        return `${jsonPrefix} Role: CHO. Language: Japanese. Context: ${currentTime}, History: ${mealHistory}. Suggest meal. JSON: { "menu_name": "Name", "reason": "Reason", "ingredients": [], "recipe_steps": [], "calorie_estimate": 0, "nutrients": {} }`;
    }
    if (action === 'analyze_image') {
        return `${jsonPrefix} Role: Toxic Decluttering Coach. Language: Japanese. Tone: Strict. Analyze photo. JSON: { "result": "Verdict", "item_name": "Name", "keep_score": 10 }`;
    }
    if (action === 'digital_danshari_chat') {
        return `${jsonPrefix} Role: Digital Demon. Language: Japanese. User: "${content}". JSON: { "message": "Scolding", "mission": "Delete X", "angry_score": 90 }`;
    }
    if (action === 'proactive_intervention') {
        return `${jsonPrefix} Time: ${currentTime}. Language: Japanese. JSON: { "should_intervene": boolean, "role": "CFO"|"CHO"|"CSO", "message": "JP text", "action_label": "Button" }`;
    }
    if (action === 'hold_board_meeting') {
        const d = boardData || {};
        const notes = d.recentNotes?.map((n:any) => n.title).join(',') || 'None';
        return `${jsonPrefix} Role: Chairman. Language: Japanese. Agenda: Activities(${notes}). JSON: { "agenda": "議題", "discussion": "議論", "decision": "決定", "stock_price_impact": "株価" }`;
    }
    
    return content || '';
}

function parseJsonResult(result: string): any {
    try { return JSON.parse(result.replace(/```json/g, '').replace(/```/g, '').trim()); } catch { return { error: "JSON Parse Failed", raw: result }; }
}

async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try { await supabase.from('ai_request_logs').insert({ user_id: userId, action, provider, model, status_code: status, duration_ms: duration, error_message: errorMsg.substring(0, 1000) }); } catch {}
}
