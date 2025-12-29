// AI Assistant Edge Function: The Five Emperors (Gemini, OpenAI, Claude, DeepSeek, Grok)
// "Unsinkable Governance System"

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

// Models & Endpoints
const PROVIDERS = {
    openai:   { model: 'gpt-4o',              url: 'https://api.openai.com/v1/chat/completions', key: OPENAI_API_KEY },
    anthropic:{ model: 'claude-3-5-sonnet-20241022', url: 'https://api.anthropic.com/v1/messages', key: ANTHROPIC_API_KEY },
    gemini:   { model: 'gemini-2.0-flash',    url: 'https://generativelanguage.googleapis.com/v1beta/models/', key: GEMINI_API_KEY },
    deepseek: { model: 'deepseek-chat',       url: 'https://api.deepseek.com/chat/completions', key: DEEPSEEK_API_KEY },
    grok:     { model: 'grok-2-latest',       url: 'https://api.x.ai/v1/chat/completions', key: XAI_API_KEY },
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
  language?: string
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

    // ---  The Five Emperors Router ---
    // 戦略的リレー順序の決定
    let providerQueue: string[] = [];

    // 1. Logic & Finance (数字、監査) 
    // DeepSeek(安価高速) -> OpenAI(王道) -> Claude(賢明) -> Grok(打開)
    if (['audit_subscriptions', 'extract_subscriptions_from_file'].includes(action)) {
        providerQueue = ['deepseek', 'openai', 'anthropic', 'grok', 'gemini'];
    }
    
    // 2. Strategy & Board Meeting (戦略、議長)
    // Claude(議長) -> OpenAI(顧問) -> DeepSeek(実務) -> Gemini
    else if (['hold_board_meeting', 'evaluate_performance'].includes(action)) {
        providerQueue = ['anthropic', 'openai', 'deepseek', 'grok', 'gemini'];
    }

    // 3. Creative & Chat (アイデア、会話)
    // Grok(ユニーク) -> Gemini(高速) -> Claude -> OpenAI
    else if (['expand', 'suggest_title', 'mental_chat'].includes(action)) {
        providerQueue = ['grok', 'gemini', 'anthropic', 'openai'];
    }

    // 4. Vision (画像認識)
    // Gemini(ネイティブ) -> OpenAI -> Claude
    //  DeepSeek/Grokの画像対応状況によるが、現状はGemini/GPT/Claudeが安定
    else if (requestData.imageBase64 || requestData.fileBase64) {
        providerQueue = ['gemini', 'openai', 'anthropic'];
    }

    // Default Fallback
    else {
        providerQueue = ['gemini', 'deepseek', 'openai', 'anthropic'];
    }

    // 利用可能なAPIキーがあるものだけを残す
    providerQueue = providerQueue.filter(p => !!PROVIDERS[p as keyof typeof PROVIDERS].key);

    if (providerQueue.length === 0) throw new Error('No available AI providers configured with API keys.');

    let finalResult = '';
    let usedProvider = '';
    let usedModel = '';
    let attemptLogs: string[] = [];

    // ---  The Failover Loop ---
    for (const provider of providerQueue) {
        try {
            console.log(` Attempting: ${action} via ${provider}...`);
            const conf = PROVIDERS[provider as keyof typeof PROVIDERS];
            
            if (provider === 'gemini') {
                finalResult = await callGemini(conf.model, conf.key!, requestData);
            } else if (provider === 'anthropic') {
                finalResult = await callAnthropic(conf.model, conf.key!, requestData);
            } else {
                // OpenAI, DeepSeek, Grok share the same interface!
                finalResult = await callOpenAICompatible(conf.url, conf.model, conf.key!, requestData);
            }

            usedProvider = provider;
            usedModel = conf.model;
            console.log(` Success with ${provider}`);
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
      'audit_meal', 'evaluate_performance', 'generate_press_release',
      'analyze_knowledge_assets', 'hold_board_meeting',
      'proactive_intervention'
    ];
    
    if (jsonActions.includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    // Log usage
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

// --- Universal OpenAI-Compatible Client (OpenAI, DeepSeek, Grok) ---
async function callOpenAICompatible(endpoint: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    
    let messages: any[] = [
        { role: "system", content: "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese." },
        { role: "user", content: prompt }
    ];

    // Force JSON output for data tasks
    let responseFormat = undefined;
    if (data.action.includes('json') || ['audit_subscriptions', 'extract_subscriptions_from_file', 'proactive_intervention', 'audit_meal', 'hold_board_meeting'].includes(data.action)) {
        responseFormat = { type: "json_object" };
        // DeepSeek/Grok sometimes need explicit instruction in system prompt for JSON, which buildPrompt handles.
    }

    // Vision Support (Only for OpenAI currently in this unified function to be safe, others might vary)
    if (data.imageBase64 && endpoint.includes('openai.com')) {
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
    } else if (data.imageBase64) {
        // Fallback for non-vision models in this path: Just send text
        // (Ideally, the router shouldn't send vision tasks here unless the model supports it)
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

// --- Anthropic Client ---
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

// --- Gemini Client ---
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

// --- Prompt Builder ---
function buildPrompt(data: AIRequest): string {
    const { action, content, title, recentNotes, subscriptions, userStats, boardData, paymentSources, currentTime } = data;
    const jsonPrefix = "Output purely valid JSON without Markdown code fences.";

    if (action === 'hold_board_meeting') {
        const d = boardData!;
        const notesSummary = d.recentNotes?.map((n:any) => n.title).join(', ') || 'なし';
        const subTotal = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
        
        return `
        ${jsonPrefix}
        あなたは「自分株式会社」の取締役会議長です。
        以下の議題について、DeepSeek（財務論理）、Grok（革新）、Gemini（直感）の意見をシミュレーションし、最終的な合議結果（Claudeとしての決断）を出力してください。

        【議題データ】
        - 直近の活動: ${notesSummary}
        - 財務状況(月次固定費): ${subTotal}円
        - 経営者(CEO)資産: ${d.userStats?.total_points || 0}pt
        
        【出力JSONフォーマット】
        {
          "agenda": "議題タイトル",
          "discussion": "各AI役員（DeepSeek, Grok, Gemini）の議論要約",
          "decision": "最終決裁事項 (Action Item)",
          "stock_price_impact": "株価変動予測 (例: +5%)"
        }
        `;
    }

    if (action === 'proactive_intervention') {
        const d = boardData!;
        // 安全にパース
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
        あなたは「自分株式会社」のAI役員団です。現在時刻: ${currentTime}。
        未監査チャネル数=${unAuditedCount}。
        
        未監査がある場合はDeepSeek(CFO)として監査を要求。
        それ以外はGrok(CTO)やGemini(CHO)として気の利いた助言を。
        
        JSON Schema:
        {
          "should_intervene": boolean,
          "role": "CFO" | "CHO" | "CSO" | "CHRO" | "CTO",
          "message": "CEOへの提言 (日本語, 60文字以内)",
          "action_label": "アクションボタン名"
        }
        `;
    }

    if (action === 'audit_subscriptions') {
        const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}円`).join('\n');
        return `CFO (DeepSeek/OpenAI) として、以下の固定費を厳格に監査し、無駄を指摘せよ。\n${subList}`;
    }

    if (action === 'audit_meal') return `${jsonPrefix} 料理画像を栄養士(CHO)として監査。JSON Schema: { "menu_name": string, "calorie_estimate": number, "performance_score": number (0-100), "audit_result": string, "advice": string }`;
    
    if (action === 'extract_subscriptions_from_file') return `${jsonPrefix} 画像/PDFから定期支払いを抽出。JSON Schema: [{ "service_name": string, "price": number, "description": string }]`;

    if (action === 'improve') return `以下をビジネス文書として洗練された文体で校正せよ:\n${content}`;
    if (action === 'mental_chat') return `CHROとして、以下の愚痴に対し、深く共感しつつも建設的な視点を提供せよ:\n${content}`;
    if (action === 'expand') return `Grokのように、以下を大胆かつユニークに拡張せよ:\n${content}`;
    if (action === 'suggest_title') return `以下の内容にふさわしいプロジェクト名を5つ提案せよ:\n${content}`;

    return content || '';
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json/g, '').replace(/```/g, '').trim();
      const firstBrace = cleaned.indexOf(cleaned.startsWith('[') ? '[' : '{');
      const lastBrace = cleaned.lastIndexOf(cleaned.endsWith(']') ? ']' : '}');
      if (firstBrace !== -1 && lastBrace !== -1) cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      return JSON.parse(cleaned);
    } catch (e) { 
        console.error("JSON Parse Error:", e);
        return {}; 
    }
}
