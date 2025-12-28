// AI Assistant Edge Function with Google Gemini
// 14モデル総当たり & 日本語強制強化版

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

//  14種のモデル全てを試行リスト (このアプリの最大の売り)
const MODELS_TO_TRY = [
  'gemini-3-flash-preview',
  'gemini-2.5-flash-lite',
  'gemini-flash-lite-latest',
  'gemini-2.5-flash-lite-preview-09-2025',
  'gemini-2.5-flash-preview-09-2025',
  'gemini-pro-latest',
  'gemini-3-pro-preview',
  'gemini-2.5-flash-image',
  'gemini-2.5-flash-image-preview',
  'gemini-3-pro-image-preview',
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
  language?: string
  targetLanguage?: string
  userId?: string
  recentNotes?: Array<{ id: string; title: string; content: string; created_at: string; updated_at: string }>
  userStats?: { current_level: number; total_points: number; current_streak: number; longest_streak: number; notes_created: number }
  strategyType?: 'now' | 'today' | 'week' | 'month' | 'year'
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

    //  14モデル総当たりループ実行
    let finalResult = ''
    let usedModel = ''
    let success = false
    let logMessages: string[] = []

    for (const model of MODELS_TO_TRY) {
      try {
        console.log(`Trying model: ${model}...`)
        
        // JSONモードは一部モデルのみ対応のため、エラー回避のためbodyをクローン
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
          console.warn(`Model ${model} failed: ${response.status}`)
          await new Promise(r => setTimeout(r, 500)) 
        }
      } catch (e) {
        logMessages.push(`${model}: Exception`)
        console.error(e)
      }
    }

    if (!success) {
      throw new Error(`All 14 models failed. Logs: ${logMessages.join(', ')}`)
    }

    // 結果の整形
    let parsedResult = finalResult;
    if (action === 'secretary_task_from_image' || action === 'task_recommendations') {
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
      JSON.stringify({ success: true, result: parsedResult, used_model: usedModel }),
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
  const { action, content, title, imageBase64, language, targetLanguage, recentNotes, userStats, strategyType } = data
  
  let body: any = {
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 2000,
    },
    contents: []
  }

  // 秘書機能: 画像からタスク生成 (日本語強制)
  if (action === 'secretary_task_from_image') {
      const promptText = `
        **IMPORTANT: Output MUST be in Japanese language.**
        
        あなたは優秀な日本人秘書です。
        CEO（ユーザー）から送られてきた画像を分析し、会社経営（人生）において実行すべきタスクを抽出してください。
        
        以下のJSONフォーマットのみを出力してください。Markdown記法や説明文は不要です。
        必ず日本語で記述してください。

        {
          "title": "タスクのタイトル（日本語で短く）",
          "content": "タスクの詳細説明、なぜこれをやるべきか（日本語で）",
          "priority": "高/中/低"
        }
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
  } 
  // 秘書機能: 戦略立案 (日本語強制)
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes && recentNotes.length > 0 
        ? recentNotes.map((n) => `- ${n.title}: ${n.content}`).join('\n')
        : '（現在タスクなし）';
      
      const promptText = `
        **IMPORTANT: Output MUST be in Japanese language.**

        あなたは「自分株式会社」の最高戦略責任者（CSO）兼 秘書です。
        CEO（ユーザー）のタスク状況を分析し、${strategyType || '今日'}の戦略スケジュールを立案してください。

        【CEOのタスク一覧】
        ${notesList}

        【指示】
        - ユーザーは「自分株式会社」のCEOです。
        - 感情論ではなく、効率と成果を最優先したプロフェッショナルな口調で話してください。
        - **必ず日本語で回答してください。英語は禁止です。**
        - 見出しや箇条書きを使い、Markdown形式で見やすく出力してください。
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // 既存機能: 断捨離判定 (日本語強制)
  else if (action === 'analyze_image') {
      const promptText = `
        **Output in Japanese.**
        あなたは「断捨離の鬼コーチ」です。
        口調は日本語で、少し厳しめに、ユーモアを交えて回答してください。

        【物体名】
        ...
        【断捨離判定】
        ...
        【鬼コーチの助言】
        ...
        【捨て方ヒント】
        ...
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
  } else if (action === 'analyze_note_text') {
      const promptText = `**Output in Japanese.**\n断捨離コーチとして、以下のメモが必要か判定せよ。\nタイトル:${title}\n内容:${content}\n回答形式:\n【判定】\n【鬼コーチの理由】\n【助言】`;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else {
       // その他
       body.contents = [{ parts: [{ text: content || '' }] }];
  }
  return body
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json/g, '').replace(/```/g, '').trim();
      const firstBrace = cleaned.indexOf('{');
      const lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace !== -1 && lastBrace !== -1) {
          cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
      return JSON.parse(cleaned);
    } catch (e) {
      console.error("JSON Parse Error", e);
      // JSONパースエラー時は、なんとか日本語で返す
      return { 
          title: '画像解析完了', 
          content: 'タスクの詳細を読み取れませんでした。内容を編集して保存してください。\n\n解析結果:\n' + result, 
          priority: '中' 
      };
    }
}
