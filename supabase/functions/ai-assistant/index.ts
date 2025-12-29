// AI Assistant Edge Function: MAGI System (Gemini + OpenAI + Claude)
// "The Tri-Brain Governance"

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

// Models (The Magi)
const MODEL_MELCHIOR = 'gpt-4o'          // Logic & Finance
const MODEL_BALTHASAR = 'gemini-2.0-flash' // Speed & Vision
const MODEL_CASPER = 'claude-3-5-sonnet-20241022' // Strategy & Nuance

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

    // ---  MAGI Router ---
    let provider = 'gemini'; 
    let model = MODEL_BALTHASAR;

    // 1. MELCHIOR (OpenAI): 数字、監査、構造化データ
    if (['audit_subscriptions', 'extract_subscriptions_from_file'].includes(action)) {
       if (OPENAI_API_KEY) { provider = 'openai'; model = MODEL_MELCHIOR; }
    }
    
    // 2. CASPER (Claude): 戦略、人事、文章作成、議長
    else if (['hold_board_meeting', 'evaluate_performance', 'improve', 'expand', 'mental_chat'].includes(action)) {
       if (ANTHROPIC_API_KEY) { provider = 'anthropic'; model = MODEL_CASPER; }
    }

    // 3. BALTHASAR (Gemini): 画像認識、スピード、デフォルト
    else {
       // audit_meal, proactive_intervention, analyze_image are handled here
       provider = 'gemini'; model = MODEL_BALTHASAR;
    }

    console.log(` MAGI Activation: ${action} | Provider: ${provider} | Model: ${model}`);

    let finalResult = '';
    
    if (provider === 'openai') {
        finalResult = await callOpenAI(model, requestData);
    } else if (provider === 'anthropic') {
        finalResult = await callAnthropic(model, requestData);
    } else {
        finalResult = await callGemini(model, requestData);
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
      note: `MAGI: ${provider} (${model})`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider, used_model: model }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error("MAGI Error:", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// --- Claude Implementation (The Strategist) ---
async function callAnthropic(model: string, data: AIRequest): Promise<string> {
    if (!ANTHROPIC_API_KEY) throw new Error('Anthropic API key missing');
    const url = 'https://api.anthropic.com/v1/messages';

    const prompt = buildPrompt(data);
    
    // System Prompt for JSON enforcement where needed
    let systemPrompt = "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese.";
    if (data.action.includes('json') || ['hold_board_meeting', 'evaluate_performance'].includes(data.action)) {
        systemPrompt += " You MUST output strictly valid JSON only. No markdown, no commentary.";
    }

    const body = {
        model: model,
        max_tokens: 4000,
        system: systemPrompt,
        messages: [{ role: "user", content: prompt }]
    };

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'x-api-key': ANTHROPIC_API_KEY,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        },
        body: JSON.stringify(body)
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Anthropic API Error: ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.content?.[0]?.text || '';
}

// --- Gemini Implementation (The Visionary) ---
async function callGemini(model: string, data: AIRequest): Promise<string> {
    if (!GEMINI_API_KEY) throw new Error('Gemini API key missing');
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;
    
    const prompt = buildPrompt(data);
    const body: any = {
        generationConfig: { temperature: 0.7 },
        contents: []
    };

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
        throw new Error(`Gemini API Error: ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

// --- OpenAI Implementation (The Logician) ---
async function callOpenAI(model: string, data: AIRequest): Promise<string> {
    if (!OPENAI_API_KEY) throw new Error('OpenAI API key missing');
    const url = 'https://api.openai.com/v1/chat/completions';

    const prompt = buildPrompt(data);
    let messages: any[] = [
        { role: "system", content: "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese." },
        { role: "user", content: prompt }
    ];

    if (data.imageBase64) {
        messages = [
            { role: "system", content: "You are an executive AI assistant." },
            { 
                role: "user", 
                content: [
                    { type: "text", text: prompt },
                    { type: "image_url", image_url: { url: `data:image/jpeg;base64,${data.imageBase64}` } }
                ] 
            }
        ];
    }

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${OPENAI_API_KEY}`
        },
        body: JSON.stringify({
            model: model,
            messages: messages,
            temperature: 0.7,
            response_format: data.action.includes('json') || [
                'audit_subscriptions', 'extract_subscriptions_from_file'
            ].includes(data.action) ? { type: "json_object" } : undefined
        })
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`OpenAI API Error: ${response.status} - ${errText}`);
    }

    const json = await response.json();
    return json.choices?.[0]?.message?.content || '';
}

// --- Prompt Builder ---
function buildPrompt(data: AIRequest): string {
    const { action, content, title, recentNotes, subscriptions, userStats, boardData, paymentSources, currentTime } = data;
    const jsonPrefix = "Output purely valid JSON without Markdown code fences.";

    //  MAGI Board Meeting (Casper as Chairman)
    if (action === 'hold_board_meeting') {
        const d = boardData!;
        const notesSummary = d.recentNotes?.map((n:any) => n.title).join(', ') || 'なし';
        const subTotal = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
        
        return `
        ${jsonPrefix}
        あなたは「自分株式会社」の取締役会議長、CASPER（Claude）です。
        以下の議題について、MELCHIOR（論理財務）とBALTHASAR（情動戦略）の意見をシミュレーションし、最終的な合議結果（CASPERの決断）を出力してください。

        【議題データ】
        - 直近の活動: ${notesSummary}
        - 財務状況(月次固定費): ${subTotal}円
        - 経営者(CEO)資産: ${d.userStats?.total_points || 0}pt
        
        【出力JSONフォーマット】
        {
          "agenda": "議題タイトル",
          "discussion": "MELCHIOR『...』\n\nBALTHASAR『...』\n\nCASPER『...』",
          "decision": "最終決裁事項 (Action Item)",
          "stock_price_impact": "株価変動予測 (例: +5%)"
        }
        `;
    }

    if (action === 'proactive_intervention') {
        const d = boardData!;
        const points = d.userStats?.total_points || 0;
        const unAuditedSources = d.paymentSources?.filter((s: any) => {
             if(!s.last_audited_at) return true;
             const audit = new Date(s.last_audited_at);
             const now = new Date();
             return audit.getMonth() !== now.getMonth() || audit.getFullYear() !== now.getFullYear();
        }) || [];
        
        return `
        ${jsonPrefix}
        あなたは「自分株式会社」のAI役員団です。現在時刻: ${currentTime}。
        CEOの状況: 資産=${points}pt, 未監査の決済チャネル数=${unAuditedSources.length}。
        
        未監査チャネルがある場合、CFO(Melchior)として監査を要求せよ。
        深夜(23時以降)ならCHO(Balthasar)として就寝を要求せよ。
        それ以外はCSO(Casper)として戦略的助言を。
        
        JSON Schema:
        {
          "should_intervene": boolean,
          "role": "CFO" | "CHO" | "CSO" | "CHRO",
          "message": "CEOへの提言 (日本語, 60文字以内)",
          "action_label": "アクションボタン名"
        }
        `;
    }

    if (action === 'audit_subscriptions') {
        const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}円`).join('\n');
        return `CFO (Melchior/OpenAI) として、以下の固定費を厳格に監査し、無駄を指摘せよ。\n${subList}`;
    }

    if (action === 'audit_meal') {
        return `${jsonPrefix} 料理画像を栄養士(CHO/Gemini)として監査。JSON Schema: { "menu_name": string, "calorie_estimate": number, "performance_score": number (0-100), "audit_result": string, "advice": string }`;
    }

    if (action === 'extract_subscriptions_from_file') {
        return `${jsonPrefix} 画像/PDFから定期支払いを抽出。JSON Schema: [{ "service_name": string, "price": number, "description": string }]`;
    }

    if (action === 'improve') return `以下をビジネス文書として、Casper (Claude) のような洗練された文体で校正せよ:\n${content}`;
    if (action === 'mental_chat') return `CHRO (Casper/Claude) として、以下の愚痴に対し、深く共感しつつも建設的な視点を提供せよ:\n${content}`;

    if (action === 'summarize') return `以下を要約せよ:\n${content}`;
    if (action === 'expand') return `以下のアイデアを拡張せよ:\n${content}`;
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
