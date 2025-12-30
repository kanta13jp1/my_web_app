// AI Assistant Edge Function: "The Five Emperors" (Stable Vision Benchmark)
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
 * テスト用画像 (瓶/ボトルが並んでいる画像)
 * 外部URLに依存しないよう、Base64形式で定義
 */
const STABLE_VISION_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAACXBIWXMAAAsTAAALEwEAmpwYAAAFmUlEQVR4nO2dS24bNxCGp0RKsh0nsZ08QIDkDn2K3CD3uUDuU+QGuU+RG+Q+RW6QG+QOuUHunMT2S7YkW7YpUiI5XAgMc8ghZ0iO9P8AhmIoaub7ZshhqBggICAQEBAICAQEAgIBAXGfAg7WpL7vM98P96n0tGZ9H0u/E3M+l34O9f009f089f0m9f0u9ePrfC69C3M+l34O9f009f089f0m9f0u9WPr/OfM+Vz6OdT309T389T3m9T3u9SPr7O09fW71I+vO+X6f86cz6WfQ30/TX0/T32/SX2/S/34OktbX79L/fi6U84eAkgEBAICAgEBAXGvAi7XpL7vM98P96n0tGZ9H0u/E3M+l34O9f009f089f0m9f0u9ePrfC69C3M+l34O9f009f089f0m9f0u9WPr/OfM+Vz6OdT309T389T3m9T3u9SPr7O09fW71I+vO+X6f86cz6WfQ30/TX0/T32/SX2/S/34OktbX79L/fi6U84eAsgFBAICAgEBca8CLtekvu8z3wf3qfS0Zn0fS78Tcz6Xfg71/TT1/Tz1/Sb1/S714+t8Lr0Lcz6Xfg71/TT1/Tz1/Sb1/S71Y+v858z5XPo51PfT1Pfz1Peb1Pe71I+vs7T19bvUj6875fp/zpzPpZ9DfT9NfT9Pfb9Jfb9L/fg6S1tfv0v9+LpTzh4CyAUEAgICAgFxrwIu16S+7zPfD/ep9LRmfR9LvxNzPpd+DvX9NPX9PPX9JvX9LvXj63wuvQtzPpd+DvX9NPX9PPX9JvX9LvVj6/znzPlc+jnU99PU9/PU95vU97vUj6+ztPX1u9SPrzvl+n/OnM+ln0N9P019P099v0l9v0v9+DpLW1+/S/34ulPOHgLIBQQCAgICAnGvAi7XpL7vM98P96n0tGZ9H0u/E3M+l34O9f009f089f0m9f0u9ePrfC69C3M+l34O9f009f089f0m9f0u9WPr/OfM+Vz6OdT309T389T3m9T3u9SPr7O09fW71I+vO+X6f86cz6WfQ30/TX0/T32/SX2/S/34OktbX79L/fi6U84eAsgFBAICAgEBca8CLtekvu8z3wf3qfS0Zn0fS78Tcz6Xfg71/TT1/Tz1/Sb1/S714+t8Lr0Lcz6Xfg71/TT1/Tz1/Sb1/S71Y+v858z5XPo51PfT1Pfz1Peb1Pe71I+vs7T19bvUj6875fp/zpzPpZ9DfT9NfT9Pfb9Jfb9L/fg6S1tfv0v9+LpTzh4CyAUEAgICAgFxrwIu16S+7zPfD/ep9LRmfR9LvxNzPpd+DvX9NPX9PPX9JvX9LvXj63wuvQtzPpd+DvX9NPX9PPX9JvX9LvVj6/znzPlc+jnU99PU9/PU95vU97vUj6+ztPX1u9SPrzvl+n/OnM+ln0N9P019P099v0l9v0v9+DpLW1+/S/34ulPOHgLIByD9fS89vVnfz9Pv3K9H96n0vH/P56XvS9+P96P9DkX8AwIBAfGPCLhcX1u/i3X/Wnp6Kz39n6Xn//v8f3/vX+rHe+mfD0F8AQGBgEBAICDgPkX6C/RmfVv6P9L9S/24Xz8E8RcEAgICAgEBcZ9Kv4v0v+n/pP/z6P7f3+vHP32f/p/W9/+k/0H8AwIBAfGPCPhXpOfT9OfpP9OfT1OfT/U/6M+nqf4H8Q8IBAQEAgL/AVq6n+o6FisEAAAAAElFTkSuQmCC";

interface AIRequest {
  action: string;
  model?: string;
  content?: string;
  imageBase64?: string;
  mimeType?: string;
  multi_response?: boolean;
  boardData?: any;
  currentTime?: string;
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

    // 1. モデル一覧取得
    if (action === 'get_models') {
        const models = await gatherAllCandidates(requestData);
        return new Response(JSON.stringify({ success: true, models }), { headers: corsHeaders });
    }

    // 2. 死活監視・ベンチマークテスト (Vision)
    if (action === 'test_model') {
        if (!targetModel) throw new Error('Model name is required');
        const candidates = await gatherAllCandidates(requestData);
        const fighter = candidates.find(c => c.model === targetModel);
        if (!fighter) throw new Error(`Model ${targetModel} not found`);

        const benchmark = await runVisionBenchmark(fighter, KEYS);
        return new Response(JSON.stringify({ success: true, status: "active", benchmark }), { headers: corsHeaders });
    }

    // 3. Battle Mode (複数AI回答)
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

    // 4. Single Mode
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
    content: "添付画像の内容を詳しく説明してください。特に『瓶 (Bottle)』が何本、またはどのような状態で写っているかを答えてください。日本語で出力してください。",
    imageBase64: STABLE_VISION_BASE64,
    mimeType: "image/png"
  };

  try {
    let text = "";
    if (fighter.provider === 'gemini') text = await callGemini(fighter.model, keys.gemini!, testData);
    else if (fighter.provider === 'anthropic') text = await callAnthropic(fighter.model, keys.anthropic!, testData);
    else text = await callOpenAICompatible(fighter.provider, fighter.model, keys.openai!, testData);

    const latency = Date.now() - start;
    const lowerText = text.toLowerCase();
    
    // キーワード判定 (精度スコア)
    let matchCount = 0;
    if (lowerText.includes("瓶") || lowerText.includes("bottle")) matchCount++;
    if (lowerText.includes("説明") || lowerText.includes("写って")) matchCount++; // 文脈理解の簡易チェック

    const score = Math.round((matchCount / 2) * 100);

    return { score, latency, detail: text.substring(0, 100) + "..." };
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

// --- API Wrappers with Vision Support ---

async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "user", content: prompt }];
    
    if (data.imageBase64) {
      messages = [{
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: `data:${data.mimeType || 'image/png'};base64,${data.imageBase64}` } }
        ]
      }];
    }

    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model, messages })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`${provider} Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.choices[0].message.content;
}

async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "user", content: prompt }];

    if (data.imageBase64) {
      messages = [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: data.mimeType || "image/png", data: data.imageBase64 } },
          { type: "text", text: prompt }
        ]
      }];
    }

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify({ model, max_tokens: 1024, messages })
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Anthropic Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.content[0].text;
}

async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const body: any = { contents: [{ parts: [{ text: prompt }] }] };

    if (data.imageBase64) {
      body.contents[0].parts.push({
        inline_data: { mime_type: data.mimeType || 'image/png', data: data.imageBase64 }
      });
    }

    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    });
    const json = await resp.json();
    if (!resp.ok) throw new Error(`Gemini Error (${resp.status}): ${json.error?.message || JSON.stringify(json)}`);
    return json.candidates[0].content.parts[0].text;
}

function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime } = data;
    if (action === 'test_vision') return content || "Analyze image.";
    if (action === 'test') return "OK";
    // ... 他の業務プロンプト (略) ...
    return content || "Hello";
}

function parseJsonResult(result: string): any {
    try { return JSON.parse(result.replace(/```json/g, '').replace(/```/g, '').trim()); } 
    catch { return { error: "Parse Failed", raw: result }; }
}

async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try { await supabase.from('ai_request_logs').insert({ user_id: userId, action, provider, model, status_code: status, duration_ms: duration, error_message: errorMsg }); } catch {}
}