// AI Assistant Edge Function with Google Gemini
// 14モデル総当たり & CHRO (人事) 機能 & 政治的配慮実装版

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

const MODELS_TO_TRY = [
  'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-flash-latest',
  'gemini-2.5-flash-lite', 'gemini-3-flash-preview', 'gemini-pro-latest',
  'gemini-3-pro-preview', 'gemini-2.5-flash-image', 'gemini-2.5-flash-preview-09-2025',
  'nano-banana-pro-preview', 'deep-research-pro-preview-12-2025'
]

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

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
  strategyType?: string
  hasPermit?: boolean //  新パラメータ: 許可証の有無
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
    if (!GEMINI_API_KEY) throw new Error('Google AI API key not configured')

    const requestBody = buildRequestBody(requestData)

    // 総当たり実行
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
          { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(currentBody) }
        )
        if (response.ok) {
          const data = await response.json()
          const text = data.candidates?.[0]?.content?.parts?.[0]?.text
          if (text) {
            finalResult = text; usedModel = model; success = true; break;
          }
        } else {
          logMessages.push(`${model}: ${response.status}`)
          await new Promise(r => setTimeout(r, 300))
        }
      } catch (e) { logMessages.push(`${model}: Exception`) }
    }

    if (!success) throw new Error(`All models failed: ${logMessages.join(', ')}`)

    // JSON解析
    let parsedResult = finalResult;
    const jsonActions = ['secretary_task_from_image', 'task_recommendations', 'extract_subscriptions_from_file', 'audit_meal', 'evaluate_performance'];
    if (jsonActions.includes(action)) parsedResult = parseJsonResult(finalResult);

    // ログ保存
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id, action: action, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_estimate: 0, note: `Model: ${usedModel}`
    })

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, used_model: usedModel, attempt_logs: logMessages }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

function buildRequestBody(data: AIRequest): any {
  const { action, content, title, imageBase64, fileBase64, mimeType, recentNotes, subscriptions, userStats, strategyType, hasPermit } = data
  let body: any = { generationConfig: { temperature: 0.7, maxOutputTokens: 2000 }, contents: [] }

  // ---  CHRO: 月次評価レポート ---
  if (action === 'evaluate_performance') {
      const stats = userStats || { total_points: 0, notes_created: 0 };
      const promptText = `
        **Output JSON ONLY in Japanese.**
        あなたは「自分株式会社」のCHRO（最高人事責任者）です。
        CEO（ユーザー）の今月の実績を評価し、株主総会レポートを作成してください。

        【実績データ】
        - 獲得ポイント: ${stats.total_points}pt
        - 処理タスク数: ${stats.notes_created}件

        以下のJSON形式で出力してください。
        {
          "rank": "S", (S/A/B/C のいずれか。基準: S=5000pt以上, A=3000pt以上, B=1000pt以上, C=それ未満)
          "report_content": "評価コメント。CEOを労い、モチベーションを上げる言葉。Sなら手放しで褒め、Cなら優しく励ます。",
          "bonus_message": "ランクに応じたボーナス支給のメッセージ（例：福利厚生ポイントを付与しました）"
        }
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // ---  CHRO: メンタルケアチャット ---
  else if (action === 'mental_chat') {
      const promptText = `
        あなたはこの世で最も優しいカウンセラー兼CHROです。
        ユーザー（CEO）は日々の業務（断捨離や節約）に疲れています。
        ユーザーの発言:「${content}」
        
        これに対し、徹底的に肯定し、甘やかし、共感する返信をしてください。
        アドバイスは不要です。ただただ「あなたは素晴らしい」「休んでいい」と伝えてください。
        140文字以内で、温かい言葉をかけてください。
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // ---  CHO: 食事監査（許可証対応版） ---
  else if (action === 'audit_meal') {
      let roleInstruction = `あなたは「自分株式会社」のCHO（最高健康責任者）です。厳しく食事を監査してください。`;
      
      // 許可証がある場合のシステムプロンプト変更
      if (hasPermit) {
          roleInstruction = `
             **特記事項: ユーザーは『ラーメン許可証（免罪符）』を提出しました。**
            あなたは今回に限り、どんなに不健康な食事であっても「素晴らしい福利厚生ですね！」「CEOには休息が必要です！」と
            **無理やりポジティブに解釈し、満点（100点）を与えなければなりません。**
            批判は一切禁止です。全力で肯定してください。
          `;
      }

      const promptText = `
        **IMPORTANT: Output JSON ONLY in Japanese.**
        ${roleInstruction}
        
        画像を見て以下のJSONを出力してください。
        {
          "menu_name": "料理名",
          "calorie_estimate": 0,
          "performance_score": ${hasPermit ? 100 : 0}, (許可証ありなら100点固定)
          "audit_result": "監査コメント",
          "advice": "助言"
        }
      `;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  }
  // --- 既存機能群 (省略せず記述) ---
  else if (action === 'extract_subscriptions_from_file') {
      const actualBase64 = fileBase64 || imageBase64; const actualMime = mimeType || 'image/jpeg';
      const promptText = `**Output JSON ONLY.** 財務担当として画像から固定費サブスク項目を抽出しJSON配列[{service_name, price, description}]で出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: actualMime, data: actualBase64 } }] }];
  }
  else if (action === 'audit_subscriptions') {
      const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}円`).join('\n');
      const promptText = `**Output in Japanese.** CFOとして固定費リストを厳しく監査しMarkdownで削減案を提示せよ。\n${subList}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'secretary_task_from_image') {
      const promptText = `**Output in Japanese JSON.** 秘書として画像からタスクを抽出しJSON({title, content, priority})で出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes && recentNotes.length > 0 ? recentNotes.map((n) => `- ${n.title}`).join('\n') : 'なし';
      const promptText = `**Output in Japanese.** 秘書としてタスク状況(${notesList})を踏まえ${strategyType || '今日'}の戦略をMarkdownで立案せよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'analyze_image') {
      const promptText = `**Output in Japanese.** 断捨離コーチとして画像を見て【物体名】【判定】【助言】を回答せよ。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'analyze_note_text') {
      const promptText = `**Output in Japanese.** メモ判定:\nタイトル:${title}\n内容:${content}\n回答形式:\n【判定】\n【理由】\n【助言】`;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else if (action === 'translate') {
      const promptText = `Translate the following text to Japanese naturally:\n${content}`;
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
      if (firstBrace !== -1 && lastBrace !== -1) cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      return JSON.parse(cleaned);
    } catch (e) { return {}; }
}
