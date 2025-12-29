// AI Assistant Edge Function with Google Gemini
// 14モデル総当たり & CFO & CHO (Health) 機能搭載

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

//  14種のモデル全てを試行リスト
const MODELS_TO_TRY = [
  'gemini-2.0-flash',
  'gemini-1.5-pro',
  'gemini-1.5-flash',
  'gemini-flash-latest',
  'gemini-2.5-flash-lite',
  'gemini-3-flash-preview',
  'gemini-pro-latest',
  'gemini-3-pro-preview',
  'gemini-2.5-flash-image',
  'gemini-2.5-flash-preview-09-2025',
  'nano-banana-pro-preview',
  'deep-research-pro-preview-12-2025',
  'gemini-2.5-computer-use-preview-10-2025',
  'gemini-robotics-er-1.5-preview'
]

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

interface AIRequest {
  action: string
  content?: string
  title?: string
  imageBase64?: string
  fileBase64?: string
  mimeType?: string
  language?: string
  targetLanguage?: string
  userId?: string
  recentNotes?: any[]
  subscriptions?: any[]
  userStats?: any
  strategyType?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

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

    if (!action) throw new Error('Missing required parameters')
    if (!GEMINI_API_KEY) throw new Error('Google AI API key not configured')

    const requestBody = buildRequestBody(requestData)

    //  14モデル総当たりループ
    let finalResult = ''
    let usedModel = ''
    let success = false
    let logMessages: string[] = []

    for (const model of MODELS_TO_TRY) {
      try {
        console.log(`Trying model: ${model}...`)
        let currentBody = JSON.parse(JSON.stringify(requestBody));
        
        const response = await fetch(
          `${BASE_URL}/${model}:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(currentBody),
          }
        )

        if (response.ok) {
          const data = await response.json()
          const text = data.candidates?.[0]?.content?.parts?.[0]?.text
          if (text) {
            finalResult = text
            usedModel = model
            success = true
            console.log(` Success with ${model}`)
            break;
          }
        } else {
          const errorText = await response.text()
          logMessages.push(`${model}: ${response.status}`)
          await new Promise(r => setTimeout(r, 300))
        }
      } catch (e) {
        logMessages.push(`${model}: Exception`)
      }
    }

    if (!success) {
      throw new Error(`All models failed. Logs: ${logMessages.join(', ')}`)
    }

    // JSON解析が必要なアクションの処理
    let parsedResult = finalResult;
    const jsonActions = ['secretary_task_from_image', 'task_recommendations', 'extract_subscriptions_from_file', 'audit_meal'];
    if (jsonActions.includes(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    // ログ保存
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: 0,
      output_tokens: 0,
      total_tokens: 0,
      cost_estimate: 0,
      note: `Model: ${usedModel}`
    })

    return new Response(
      JSON.stringify({ 
        success: true, 
        result: parsedResult, 
        used_model: usedModel,
        attempt_logs: logMessages 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('AI Service Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

function buildRequestBody(data: AIRequest): any {
  const { action, content, title, imageBase64, fileBase64, mimeType, recentNotes, subscriptions, strategyType } = data
  
  let body: any = {
    generationConfig: {
      temperature: 0.5,
      maxOutputTokens: 2000,
    },
    contents: []
  }

  // ---  新機能: CHO 食事監査 ---
  if (action === 'audit_meal') {
      const promptText = `
        **IMPORTANT: Output JSON ONLY in Japanese.**

        あなたは「自分株式会社」のCHO（最高健康責任者）です。
        CEO（ユーザー）が摂取しようとしている食事の画像を分析し、
        「CEOのパフォーマンス（仕事の生産性、集中力、メンタル）」に与える影響を厳しく監査してください。
        
        以下のJSONフォーマットで出力してください。Markdownは不要です。

        {
          "menu_name": "料理名（推定）",
          "calorie_estimate": 0, (整数で推定カロリー)
          "performance_score": 0, (0〜100点。健康度ではなく『仕事のパフォーマンスへの貢献度』で採点。眠くなる炭水化物過多は減点、脳に良い栄養は加点)
          "audit_result": "監査コメント。なぜこの点数なのか、医学的栄養学的かつビジネス視点（株価、生産性）で解説。",
          "advice": "直近のアクション（例：『食後にコーヒーを飲め』『野菜を追加せよ』など）"
        }
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
  }
  // --- 既存機能: 明細書スキャン ---
  else if (action === 'extract_subscriptions_from_file') {
      const actualBase64 = fileBase64 || imageBase64;
      const actualMime = mimeType || 'image/jpeg';
      const promptText = `**IMPORTANT: Output JSON ONLY.**\nあなたは財務担当です。画像から固定費サブスク項目を抽出しJSON配列[{service_name, price, description}]で出力せよ。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: actualMime, data: actualBase64 } }] }];
  }
  // --- 既存機能: サブスク監査 ---
  else if (action === 'audit_subscriptions') {
      const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}円`).join('\n');
      const promptText = `**Output in Japanese.**\nあなたは冷徹なCFOです。以下の固定費リストを厳しく監査し、Markdownで削減案を提示せよ。\n\n${subList}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // --- 既存機能: 秘書タスク ---
  else if (action === 'secretary_task_from_image') {
      const promptText = `**Output in Japanese JSON.**\n優秀な秘書として画像からタスクを抽出しJSON({title, content, priority})で出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  // --- 既存機能: 戦略 ---
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes && recentNotes.length > 0 ? recentNotes.map((n) => `- ${n.title}`).join('\n') : 'なし';
      const promptText = `**Output in Japanese.**\n秘書として、タスク状況(${notesList})を踏まえ${strategyType || '今日'}の戦略をMarkdownで立案せよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // --- 既存機能: 断捨離 ---
  else if (action === 'analyze_image') {
      const promptText = `**Output in Japanese.**\n断捨離コーチとして画像を見て【物体名】【判定】【助言】を回答せよ。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'analyze_note_text') {
      const promptText = `**Output in Japanese.**\nメモ判定:\nタイトル:${title}\n内容:${content}\n回答形式:\n【判定】\n【理由】\n【助言】`;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else {
       body.contents = [{ parts: [{ text: content || '' }] }];
  }
  return body
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json/g, '').replace(/```/g, '').trim();
      const firstBrace = cleaned.indexOf(cleaned.startsWith('[') ? '[' : '{');
      const lastBrace = cleaned.lastIndexOf(cleaned.endsWith(']') ? ']' : '}');
      if (firstBrace !== -1 && lastBrace !== -1) {
          cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
      return JSON.parse(cleaned);
    } catch (e) {
      console.error("JSON Parse Error", e);
      return {}; 
    }
}
