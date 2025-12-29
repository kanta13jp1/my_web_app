// AI Assistant Edge Function: Hybrid Intelligence (Gemini + OpenAI)
// "The Council of AIs"

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// API Keys
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

// Models
const GEMINI_MODELS = ['gemini-2.0-flash', 'gemini-1.5-pro']
const OPENAI_MODELS = ['gpt-4o', 'gpt-4-turbo']

// Interface
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
    
    // Supabase Auth Check
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const requestData: AIRequest = await req.json()
    const { action } = requestData

    // ---  AI Router (The Brain) ---
    // 役割に応じて最適な脳（プロバイダー）を選択する
    let provider = 'gemini'; // Default
    let model = GEMINI_MODELS[0];

    // OpenAI (Logic & Finance Specialist)
    if (['audit_subscriptions', 'hold_board_meeting', 'evaluate_performance'].includes(action)) {
       if (OPENAI_API_KEY) {
         provider = 'openai';
         model = 'gpt-4o';
       }
    }
    
    // Gemini (Creative & Multimodal Specialist)
    if (['audit_meal', 'analyze_image', 'mental_chat', 'proactive_intervention'].includes(action)) {
       provider = 'gemini'; // Force Gemini for these
    }

    console.log(` AI Request: ${action} | Provider: ${provider} | Model: ${model}`);

    let finalResult = '';
    
    if (provider === 'openai') {
        finalResult = await callOpenAI(model, requestData);
    } else {
        finalResult = await callGemini(model, requestData);
    }

    // JSON Parsing for structured tasks
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
      note: `Provider: ${provider} / Model: ${model}`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider, used_model: model }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error("AI Error:", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// --- Gemini Implementation ---
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

// --- OpenAI Implementation ---
async function callOpenAI(model: string, data: AIRequest): Promise<string> {
    if (!OPENAI_API_KEY) throw new Error('OpenAI API key missing');
    const url = 'https://api.openai.com/v1/chat/completions';

    const prompt = buildPrompt(data);
    let messages: any[] = [
        { role: "system", content: "You are an executive AI assistant for 'Jibun Inc.' (自分株式会社). Output in Japanese." },
        { role: "user", content: prompt }
    ];

    // Vision Support for OpenAI
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
                'audit_meal', 'hold_board_meeting', 'proactive_intervention', 'extract_subscriptions_from_file'
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

// --- Prompt Builder (Common) ---
function buildPrompt(data: AIRequest): string {
    const { action, content, title, recentNotes, subscriptions, userStats, boardData, paymentSources, currentTime } = data;

    // Common Prefix for JSON output
    const jsonPrefix = "Output purely valid JSON without Markdown code fences.";

    if (action === 'proactive_intervention') {
        const d = boardData!;
        const points = d.userStats?.total_points || 0;
        const taskCount = d.recentNotes?.length || 0;
        const unAuditedSources = d.paymentSources?.filter((s: any) => {
             if(!s.last_audited_at) return true;
             const audit = new Date(s.last_audited_at);
             const now = new Date();
             return audit.getMonth() !== now.getMonth() || audit.getFullYear() !== now.getFullYear();
        }) || [];
        
        return `
        ${jsonPrefix}
        あなたは「自分株式会社」のAI役員団です。現在時刻: ${currentTime}。
        CEOの状況: 資産=${points}pt, 直近タスク=${taskCount}, 未監査の決済チャネル数=${unAuditedSources.length}。
        
        未監査の決済チャネルがある場合、CFOとして「監査の催促」を優先的に行ってください。
        それ以外は、時間帯に応じた健康(CHO)や戦略(CSO)のアドバイスを。
        
        JSON Schema:
        {
          "should_intervene": boolean,
          "role": "CFO" | "CHO" | "CSO" | "CHRO",
          "message": "CEOへの提言 (日本語, 60文字以内)",
          "action_label": "アクションボタン名"
        }
        `;
    }

    if (action === 'hold_board_meeting') {
        const d = boardData!;
        const notesSummary = d.recentNotes?.map((n:any) => n.title).join(', ') || 'なし';
        const subTotal = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
        
        return `
        ${jsonPrefix}
        緊急役員会議を開催せよ。
        議題: 直近の活動(${notesSummary})と財務状況(固定費月額:${subTotal})について。
        
        JSON Schema:
        {
          "agenda": "議題",
          "discussion": "役員間(CFO, CSO, CKO)の議論要約",
          "decision": "決定事項",
          "stock_price_impact": "株価予測"
        }
        `;
    }

    if (action === 'audit_subscriptions') {
        const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}円`).join('\n');
        return `CFOとして以下の固定費を鬼のような厳しさで監査し、削減案を提示せよ。\n${subList}`;
    }

    if (action === 'audit_meal') {
        return `${jsonPrefix} 料理画像を栄養士(CHO)として監査。JSON Schema: { "menu_name": string, "calorie_estimate": number, "performance_score": number (0-100), "audit_result": string, "advice": string }`;
    }

    if (action === 'extract_subscriptions_from_file') {
        return `${jsonPrefix} 画像/PDFから定期支払いを抽出。JSON Schema: [{ "service_name": string, "price": number, "description": string }]`;
    }

    if (action === 'ai_chat' || action === 'mental_chat') return content || '';
    if (action === 'improve') return `以下をビジネス文書として校正せよ:\n${content}`;
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
