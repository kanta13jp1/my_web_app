// AI Assistant Edge Function: The Five Emperors (Failover System)
// "Unsinkable Governance"

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

// Models & Endpoints Configuration
const PROVIDERS = {
    // 1. DeepSeek: Cost-effective & Smart (V3)
    deepseek: { model: 'deepseek-chat', url: 'https://api.deepseek.com/chat/completions', key: DEEPSEEK_API_KEY },
    // 2. Gemini: Fast & Multimodal (2.0 Flash)
    gemini:   { model: 'gemini-2.0-flash', url: 'https://generativelanguage.googleapis.com/v1beta/models/', key: GEMINI_API_KEY },
    // 3. OpenAI: Reliable Standard (GPT-4o)
    openai:   { model: 'gpt-4o', url: 'https://api.openai.com/v1/chat/completions', key: OPENAI_API_KEY },
    // 4. Grok: Creative (Grok-2)
    grok:     { model: 'grok-2-latest', url: 'https://api.x.ai/v1/chat/completions', key: XAI_API_KEY },
    // 5. Anthropic: High Context (Claude 3.5)
    anthropic:{ model: 'claude-3-5-sonnet-20241022', url: 'https://api.anthropic.com/v1/messages', key: ANTHROPIC_API_KEY },
};

interface AIRequest {
  action: string
  content?: string
  title?: string
  imageBase64?: string
  fileBase64?: string
  mimeType?: string
  userId?: string
  recentNotes?: any[]
  subscriptions?: any[]
  userStats?: any
  paymentSources?: any[]
  boardData?: any
  context?: string
  currentTime?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // Auth Check
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

    // ---  The Failover Strategy ---
    // 優先順位リストを作成 (DeepSeekを先頭に配置してコスト削減と負荷分散を狙う)
    let providerQueue: string[] = [];

    // 画像処理が含まれる場合 (Gemini, OpenAI, Claudeが強い)
    if (requestData.imageBase64 || requestData.fileBase64) {
        providerQueue = ['gemini', 'openai', 'anthropic', 'grok'];
    } 
    // 通常のテキスト/JSON処理
    else {
        // DeepSeek -> Gemini -> OpenAI -> Grok -> Claude
        providerQueue = ['deepseek', 'gemini', 'openai', 'grok', 'anthropic'];
    }

    // キーが設定されていないプロバイダは除外
    providerQueue = providerQueue.filter(p => !!PROVIDERS[p as keyof typeof PROVIDERS].key);

    if (providerQueue.length === 0) {
        throw new Error('No available AI providers. Please set DEEPSEEK_API_KEY, GEMINI_API_KEY, or others in Supabase Secrets.');
    }

    let finalResult = '';
    let usedProvider = '';
    let usedModel = '';
    let attemptLogs: string[] = [];

    // ---  Execution Loop ---
    for (const provider of providerQueue) {
        try {
            console.log(` Attempting: ${action} via ${provider}...`);
            const conf = PROVIDERS[provider as keyof typeof PROVIDERS];
            
            if (provider === 'gemini') {
                finalResult = await callGemini(conf.model, conf.key!, requestData);
            } else if (provider === 'anthropic') {
                finalResult = await callAnthropic(conf.model, conf.key!, requestData);
            } else {
                // OpenAI, DeepSeek, Grok share the same interface
                finalResult = await callOpenAICompatible(conf.url, conf.model, conf.key!, requestData);
            }

            usedProvider = provider;
            usedModel = conf.model;
            console.log(` Success with ${provider}`);
            break; // 成功したらループを抜ける

        } catch (e) {
            console.error(` Failed with ${provider}: ${e.message}`);
            attemptLogs.push(`${provider}: ${e.message}`);
            // 失敗したら次のループへ (Failover)
        }
    }

    // 全滅判定
    if (!usedProvider) {
        throw new Error(`All providers failed. Logs: ${attemptLogs.join(' | ')}`);
    }

    // JSON Parsing (if needed)
    let parsedResult = finalResult;
    const jsonActions = [
      'secretary_task_from_image', 'extract_subscriptions_from_file', 
      'audit_meal', 'evaluate_performance', 'generate_press_release',
      'analyze_knowledge_assets', 'hold_board_meeting',
      'proactive_intervention'
    ];
    
    if (jsonActions.includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    // Log Usage
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id, 
      action: action, 
      note: `Winner: ${usedProvider} (${usedModel}) / Failures: ${attemptLogs.length}`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: usedProvider, used_model: usedModel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// ---  Universal Client (OpenAI, DeepSeek, Grok) ---
async function callOpenAICompatible(endpoint: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    
    let messages: any[] = [
        { role: "system", content: "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese." },
        { role: "user", content: prompt }
    ];

    // Force JSON output
    let responseFormat = undefined;
    if (data.action.includes('json') || ['audit_subscriptions', 'extract_subscriptions_from_file', 'proactive_intervention', 'audit_meal', 'hold_board_meeting'].includes(data.action)) {
        responseFormat = { type: "json_object" };
    }

    // Vision Support (for OpenAI/Grok if supported)
    if (data.imageBase64 && (endpoint.includes('openai') || endpoint.includes('x.ai'))) {
        messages = [
            { role: "system", content: "You are an executive AI assistant." },
            { 
                role: "user", 
                content: [
                    { type: "text", text: prompt },
                    { type: "image_url", image_url: { url: `data:${data.mimeType || 'image/jpeg'};base64,${data.imageBase64}` } }
                ] 
            }
        ];
    }

    const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
            model: model,
            messages: messages,
            temperature: 0.7,
            response_format: responseFormat
        })
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`API Error (${model}): ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.choices?.[0]?.message?.content || '';
}

// ---  Anthropic Client ---
async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const url = 'https://api.anthropic.com/v1/messages';
    const prompt = buildPrompt(data);
    
    let systemPrompt = "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting', 'evaluate_performance', 'proactive_intervention', 'extract_subscriptions_from_file', 'audit_meal'].includes(data.action)) {
        systemPrompt += " You MUST output strictly valid JSON only. No markdown, no commentary.";
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
        throw new Error(`Anthropic Error: ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.content?.[0]?.text || '';
}

// ---  Gemini Client ---
async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const prompt = buildPrompt(data);
    const body: any = { generationConfig: { temperature: 0.7 }, contents: [] };

    if (data.imageBase64 || data.fileBase64) {
        const imgData = data.imageBase64 || data.fileBase64;
        const mime = data.mimeType || 'image/jpeg';
        body.contents.push({
            parts: [{ text: prompt }, { inline_data: { mime_type: mime, data: imgData } }]
        });
    } else {
        body.contents.push({ parts: [{ text: prompt }] });
    }

    const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Gemini Error: ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

// ---  Prompt Builder ---
function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, paymentSources, currentTime, subscriptions } = data;
    const jsonPrefix = "Output purely valid JSON without Markdown code fences.";

    if (action === 'hold_board_meeting') {
        const d = boardData || {};
        const notesSummary = d.recentNotes?.map((n:any) => n.title).join(', ') || 'なし';
        const subTotal = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
        
        return `
        ${jsonPrefix}
        あなたは「自分株式会社」のAI役員です。
        議題: 直近の活動(${notesSummary})と財務状況(固定費月額:${subTotal})。
        
        JSON Schema:
        {
          "agenda": "議題タイトル",
          "discussion": "各役員(DeepSeek, Grok, Gemini)の議論",
          "decision": "最終決裁事項",
          "stock_price_impact": "株価変動予測"
        }
        `;
    }

    if (action === 'proactive_intervention') {
        const d = boardData || {};
        const points = d.userStats?.total_points || 0;
        let unAuditedCount = 0;
        if (d.paymentSources && Array.isArray(d.paymentSources)) {
             unAuditedCount = d.paymentSources.filter((s: any) => {
                 if(!s.last_audited_at) return true;
                 const audit = new Date(s.last_audited_at);
                 const now = new Date();
                 return audit.getMonth() !== now.getMonth() || audit.getFullYear() !== now.getFullYear();
            }).length;
        }
        
        return `
        ${jsonPrefix}
        現在時刻: ${currentTime}。CEO資産=${points}pt, 未監査決済=${unAuditedCount}件。
        未監査ならCFOとして警告。深夜ならCHOとして就寝勧告。それ以外はCSOとして助言。
        
        JSON Schema:
        {
          "should_intervene": boolean,
          "role": "CFO" | "CHO" | "CSO" | "CHRO",
          "message": "CEOへの提言(60文字以内)",
          "action_label": "ボタン名"
        }
        `;
    }

    if (action === 'audit_subscriptions') {
        const subList = subscriptions ? subscriptions.map((s:any) => `- ${s.service_name}: ${s.price}円`).join('\n') : '';
        return `CFOとして以下の固定費を監査せよ。\n${subList}`;
    }

    if (action === 'audit_meal') return `${jsonPrefix} 画像の食事を栄養士として監査。JSON Schema: { "menu_name": string, "calorie_estimate": number, "performance_score": number, "audit_result": string, "advice": string }`;
    
    if (action === 'extract_subscriptions_from_file') return `${jsonPrefix} 画像/PDFから定期支払いを抽出。JSON Schema: [{ "service_name": string, "price": number, "description": string }]`;

    if (action === 'improve') return `以下をビジネス文書として校正:\n${content}`;
    if (action === 'mental_chat') return `CHROとして、以下の発言に共感し助言せよ:\n${content}`;
    if (action === 'expand') return `Grokのように、以下をユニークに拡張せよ:\n${content}`;
    if (action === 'suggest_title') return `以下の内容に合うプロジェクト名を5つ提案:\n${content}`;

    return content || '';
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json/g, '').replace(/```/g, '').trim();
      const firstBrace = cleaned.indexOf(cleaned.startsWith('[') ? '[' : '{');
      const lastBrace = cleaned.lastIndexOf(cleaned.endsWith(']') ? ']' : '}');
      if (firstBrace !== -1 && lastBrace !== -1) cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      return JSON.parse(cleaned);
    } catch (e) { return {}; }
}
