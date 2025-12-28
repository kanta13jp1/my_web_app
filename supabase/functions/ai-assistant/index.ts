// AI Assistant Edge Function with Google Gemini
// 14種のモデル総当たり & AI秘書機能追加版

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

//  14種のモデル全てを試行リスト
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
  strategyType?: 'now' | 'today' | 'week' | 'month' | 'year' // 秘書機能用
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

    //  総当たり実行ループ
    let finalResult = ''
    let usedModel = ''
    let success = false
    let logMessages: string[] = []

    for (const model of MODELS_TO_TRY) {
      try {
        console.log(`Trying model: ${model}...`)
        const response = await fetch(
          `${BASE_URL}/${model}:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestBody),
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

    // JSONパースが必要なアクションの場合の処理
    let parsedResult = finalResult;
    if (action === 'secretary_task_from_image' || action === 'task_recommendations') {
        parsedResult = parseJsonResult(finalResult);
    }

    // ログ保存
    const inputLength = JSON.stringify(requestBody).length
    const outputLength = finalResult.length
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: Math.ceil(inputLength / 4),
      output_tokens: Math.ceil(outputLength / 4),
      total_tokens: Math.ceil((inputLength + outputLength) / 4),
      cost_estimate: 0,
      note: `Model: ${usedModel}`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, raw_text: finalResult, used_model: usedModel }),
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

  // 秘書機能: 画像からタスク生成
  if (action === 'secretary_task_from_image') {
      const promptText = `
        あなたは「自分株式会社」の優秀なAI秘書です。
        CEO（ユーザー）から送られてきた画像を分析し、会社経営（人生）において実行すべきタスクを抽出してください。
        
        以下のJSONフォーマットのみを出力してください。Markdown記法は不要です。
        {
          "title": "タスクのタイトル（短く具体的に）",
          "content": "タスクの詳細説明、なぜこれをやるべきか、具体的な手順",
          "priority": "高/中/低"
        }
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
      body.generationConfig.responseMimeType = 'application/json';
  } 
  // 秘書機能: 戦略立案
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes!.map((n, i) => `- ${n.title}: ${n.content}`).join('\n');
      let timeFrameText = '';
      switch(strategyType) {
          case 'now': timeFrameText = '「今この瞬間」'; break;
          case 'today': timeFrameText = '「今日1日」'; break;
          case 'week': timeFrameText = '「今週」'; break;
          case 'month': timeFrameText = '「今月」'; break;
          case 'year': timeFrameText = '「今年」'; break;
      }

      const promptText = `
        あなたは「自分株式会社」の最高戦略責任者（CSO）兼 秘書です。
        CEO（ユーザー）が現在抱えている以下のタスク（メモ）を分析し、
        ${timeFrameText}の最適なスケジュールと戦略を立案してください。

        【CEOの現在のタスク一覧】
        ${notesList || '（現在タスクなし）'}

        【指示】
        - あなたはプロフェッショナルな秘書として振る舞ってください。
        - 感情論ではなく、効率と成果（株式会社としての成功）を最優先してください。
        - 優先順位を明確にし、捨てるべきタスクがあれば指摘してください。
        - CEOを鼓舞するようなメッセージを含めてください。
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // 既存機能
  else if (action === 'analyze_image') {
      const promptText = `
        あなたは「断捨離の鬼コーチ」です。ユーザーがアップロードした写真の物体を見て、以下のフォーマットで回答してください。
        口調は少し厳しめで、ユーモアを交えて「捨てるべき理由」を力説してください。
        【物体名】（ここに物体名）
        【断捨離判定】（「即捨て推奨」または「保留」）
        【鬼コーチの助言】（なぜこれを捨てるべきか、過去の執着を断ち切るような短いアドバイス）
        【捨て方ヒント】（一般的に何ゴミになるか、どう処分すべきか）
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
  } else if (action === 'analyze_note_text') {
      const promptText = `
        あなたは「デジタルの断捨離鬼コーチ」です。
        ユーザーがため込んだ以下のメモを見て、今後この情報が必要か否かを厳しく判定してください。
        【メモタイトル】: ${title || '(なし)'}
        【メモ内容】: ${content || '(なし)'}
        以下のフォーマットで回答せよ。
        【判定】（「即アーカイブ推奨」または「保留」）
        【鬼コーチの理由】（なぜこの情報が不要か、デジタルゴミになっている理由を痛烈に指摘）
        【助言】（デジタル情報を整理するための短い一言）
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else {
      let prompt = ''
      switch (action) {
        case 'improve': prompt = `文章校正:\n${content}`; break;
        case 'summarize': prompt = `要約:\n${content}`; break;
        case 'expand': prompt = `アイデア展開:\n${content}`; break;
        case 'translate': prompt = `${targetLanguage}へ翻訳:\n${content}`; break;
        case 'suggest_title': prompt = `タイトル案3つ:\n${content}`; break;
        case 'task_recommendations':
          const notesContent = recentNotes!.map((note: any, i: number) => `メモ${i+1}: ${note.title}`).join('\n');
          prompt = `戦略参謀として、以下のユーザー状況に基づきJSONで助言せよ。\nレベル:${userStats.current_level}\nメモ:\n${notesContent}\n出力キー:daily,weekly,monthly,yearly,insights`;
          body.generationConfig.responseMimeType = 'application/json';
          break;
      }
      body.contents = [{ parts: [{ text: prompt }] }];
  }
  return body
}

function parseJsonResult(result: string): any {
    try {
      let cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
      // 配列で返ってきた場合、最初の一つを取り出すなどの処理が必要かも
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      return JSON.parse(jsonMatch ? jsonMatch[0] : cleaned)
    } catch (e) {
      console.error("JSON Parse Error", e)
      return { title: '解析エラー', content: 'AIの応答を解析できませんでした', priority: '低' }
    }
}
