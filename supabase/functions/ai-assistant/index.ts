// AI Assistant Edge Function: "The Five Emperors" (Full Business Logic + Vision Benchmark)
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

const VISION_TEST_IMAGE = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/Refrigerator_interior_filled_with_food.jpg/800px-Refrigerator_interior_filled_with_food.jpg";

interface AIRequest {
  action: string
  model?: string      // 死活監視・ベンチマーク対象
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

    // --- 2. 死活監視・ベンチマークテスト ---
    if (action === 'test_model') {
        if (!targetModel) throw new Error('Model name is required');
        const candidates = await gatherAllCandidates(requestData);
        const fighter = candidates.find(c => c.model === targetModel);
        if (!fighter) throw new Error(`Model ${targetModel} not found`);

        const benchmark = await runVisionBenchmark(fighter, KEYS);
        return new Response(JSON.stringify({ success: true, status: "active", benchmark }), { headers: corsHeaders });
    }

    // --- 3. Battle Mode (複数AIによる競演) ---
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

    // --- 4. Single Mode (フォールバック実行) ---
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

// --- 🔧 Core Logic Functions ---

async function runVisionBenchmark(fighter: any, keys: any) {
  const start = Date.now();
  const testData: AIRequest = {
    action: 'test_vision',
    content: `Analyze this image URL: ${VISION_TEST_IMAGE}. Identify if 'Milk', 'Eggs', and 'Bottles' are present. Output in Japanese.`
  };

  try {
    let text = "";
    if (fighter.provider === 'gemini') text = await callGemini(fighter.model, keys.gemini!, testData);
    else if (fighter.provider === 'anthropic') text = await callAnthropic(fighter.model, keys.anthropic!, testData);
    else text = await callOpenAICompatible(fighter.provider, fighter.model, keys.openai!, testData);

    const latency = Date.now() - start;
    const lowerText = text.toLowerCase();
    
    let matchCount = 0;
    if (lowerText.includes("milk") || lowerText.includes("牛乳")) matchCount++;
    if (lowerText.includes("egg") || lowerText.includes("卵")) matchCount++;
    if (lowerText.includes("bottle") || lowerText.includes("瓶")) matchCount++;

    return { score: Math.round((matchCount / 3) * 100), latency, detail: text.substring(0, 100) + "..." };
  } catch (e) {
    throw new Error(`Benchmark Error: ${e.message}`);
  }
}

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

// --- 🚀 API Call Wrappers ---

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ 
          model, 
          messages: [{ role: "user", content: prompt }],
          response_format: shouldParseJson(data.action) ? { type: "json_object" } : undefined
        })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`${provider} Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 1024, messages: [{ role: "user", content: prompt }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Anthropic Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Gemini Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.candidates[0].content.parts[0].text;
}

// --- 🧠 Business Prompt Logic ---

function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime, missionData, missionName } = data;
    const jsonPrefix = "Output purely valid JSON.";

    if (action === 'test' || action === 'test_vision') return content || "Hi";

    if (action === 'draft_press_release') {
        const stats = boardData?.userStats || {};
        return `${jsonPrefix} Role: CMO of 'Jibun Inc.' Language: Japanese. Achievements: Total Assets: ${stats.total_points || 0}. Task: Write inspiring press release. Output: { "title": "string", "body": "string", "hashtags": [] }`;
    }

    if (action === 'verify_mission_proof') return `${jsonPrefix} Role: Strict Inspector. Language: Japanese. Verify photo for "${missionName}". Output: { "verified": boolean, "comment": "string", "score": number }`;
    
    if (action === 'check_bedtime_permission') {
        return `${jsonPrefix} Role: Gatekeeper. Status: ${JSON.stringify(missionData)}. Output: { "permission_granted": boolean, "message": "string" }`;
    }
    
    if (action === 'suggest_next_meal') return `${jsonPrefix} Role: Chef. Context: ${currentTime}. Output: { "menu_name": "string", "reason": "string" }`;
    
    if (action === 'analyze_image') return `${jsonPrefix} Role: Toxic Coach. Output: { "result": "string", "keep_score": number }`;
    
    if (action === 'digital_danshari_chat') return `${jsonPrefix} Role: Digital Demon. User: "${content}". Output: { "message": "string" }`;
    
    if (action === 'proactive_intervention') return `${jsonPrefix} Time: ${currentTime}. Output: { "should_intervene": boolean, "message": "string" }`;
    
    if (action === 'hold_board_meeting') return `${jsonPrefix} Role: Chairman. Output: { "agenda": "string", "discussion": "string" }`;
    
    return content || 'No content provided.';
}

function parseJsonResult(result: string): any {
    try { return JSON.parse(result.replace(/```json/g, '').replace(/```/g, '').trim()); } 
    catch { return { error: "Parse Failed", raw: result }; }
}

async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try { await supabase.from('ai_request_logs').insert({ user_id: userId, action, provider, model, status_code: status, duration_ms: duration, error_message: errorMsg }); } catch {}
}