// AI Assistant Edge Function with Google Gemini
// 14モデル総当たり & Full Company Structure (CSO, CFO, CHO, CHRO, CMO)

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
  hasPermit?: boolean
  dailyStats?: any //  新: CMO用データ
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

    let parsedResult = finalResult;
    // JSON解析が必要なアクション
    const jsonActions = ['secretary_task_from_image', 'task_recommendations', 'extract_subscriptions_from_file', 'audit_meal', 'evaluate_performance', 'generate_press_release'];
    if (jsonActions.includes(action)) parsedResult = parseJsonResult(finalResult);

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
  const { action, content, title, imageBase64, fileBase64, mimeType, recentNotes, subscriptions, userStats, strategyType, hasPermit, dailyStats } = data
  let body: any = { generationConfig: { temperature: 0.7, maxOutputTokens: 2000 }, contents: [] }

  // ---  CMO: プレスリリース生成 ---
  if (action === 'generate_press_release') {
      const promptText = `
        **Output JSON ONLY in Japanese.**
        あなたは「自分株式会社」のCMO（最高マーケティング責任者）です。
        CEO（ユーザー）の本日の活動実績をもとに、世界に向けて発信する「壮大なプレスリリース」を作成してください。
        
        【本日の実績データ】
        - 消化タスク数: ${dailyStats?.task_count || 0}件
        - 断捨離数: ${dailyStats?.danshari_count || 0}個
        - 獲得ポイント: ${dailyStats?.points_earned || 0}pt
        
        【指示】
        - 些細な成果でも、シリコンバレーのテック企業が革新的な発表をするかのような、**大げさでポジティブで意識高い系の文体**に変換してください。
        - 失敗や怠惰（0件など）があれば、「戦略的静観」「エネルギー充填期間」のように美しく言い換えてください。

        以下のJSON形式で出力してください。
        {
          "headline": "衝撃的な見出し（30文字以内）",
          "body": "プレスリリース本文（140文字程度。ハッシュタグ #自分株式会社 を含む）",
          "market_analysis": "市場（CEOのメンタル）への影響を一言で分析"
        }
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // --- CHRO ---
  else if (action === 'evaluate_performance') {
      const stats = userStats || { total_points: 0, notes_created: 0 };
      const promptText = `**Output JSON ONLY in Japanese.** CHROとして今月の実績(Pt:${stats.total_points}, Task:${stats.notes_created})をS/A/B/Cで評価しJSON({rank, report_content, bonus_message})で出力。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'mental_chat') {
      const promptText = `超優しいCHROとしてユーザーの愚痴「${content}」を全肯定し甘やかす返信をせよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // --- CHO ---
  else if (action === 'audit_meal') {
      let instruction = hasPermit 
        ? `ラーメン許可証あり。どんな食事も「福利厚生」として100点満点で称賛せよ。批判厳禁。` 
        : `CHOとして厳しく食事を監査せよ。`;
      const promptText = `**Output JSON ONLY in Japanese.** ${instruction} 画像からJSON({menu_name, calorie_estimate, performance_score, audit_result, advice})を出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  }
  // --- Other ---
  else if (action === 'extract_subscriptions_from_file') {
      const aB64 = fileBase64 || imageBase64; const aMime = mimeType || 'image/jpeg';
      const promptText = `**Output JSON ONLY.** 画像から固定費項目を抽出、JSON配列[{service_name, price, description}]で出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: aMime, data: aB64 } }] }];
  }
  else if (action === 'audit_subscriptions') {
      const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}`).join('\n');
      const promptText = `**Output in Japanese.** CFOとして固定費を監査し削減案をMarkdownで提示。\n${subList}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'secretary_task_from_image') {
      const promptText = `**Output JSON in Japanese.** 秘書として画像からタスク抽出、JSON({title, content, priority})で出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes && recentNotes.length > 0 ? recentNotes.map((n) => `- ${n.title}`).join('\n') : 'なし';
      const promptText = `**Output in Japanese.** 秘書としてタスク状況(${notesList})を踏まえ${strategyType || '今日'}の戦略をMarkdownで立案せよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'analyze_image') {
      const promptText = `**Output in Japanese.** 断捨離コーチとして画像判定【物体名】【判定】【助言】。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'analyze_note_text') {
      const promptText = `**Output in Japanese.** メモ判定 Title:${title} Content:${content} 回答形式:【判定】【理由】【助言】。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else if (action === 'translate') {
      const promptText = `Translate to Japanese:\n${content}`;
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
