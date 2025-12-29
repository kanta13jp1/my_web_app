// AI Assistant Edge Function with Google Gemini
// 14モデル総当たり & Morning Briefing & Share URL Support

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

const MODELS_TO_TRY = [
  'gemini-1.5-pro',
  'gemini-2.0-flash', 
  'gemini-flash-latest',
  'gemini-2.5-flash-lite', 
  'gemini-3-flash-preview', 
  'gemini-pro-latest',
  'gemini-3-pro-preview', 
  'gemini-2.5-flash-image', 
  'gemini-2.5-flash-preview-09-2025',
  'nano-banana-pro-preview', 
  'deep-research-pro-preview-12-2025'
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
  dailyStats?: any
  targetFormat?: string
  boardData?: {
    recentMeals: any[],
    recentNotes: any[],
    subscriptions: any[],
    userStats: any
  }
  context?: string //  新追加: 'morning_briefing' などの文脈
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
    const jsonActions = [
      'secretary_task_from_image', 'task_recommendations', 
      'extract_subscriptions_from_file', 'audit_meal', 
      'evaluate_performance', 'generate_press_release',
      'analyze_knowledge_assets', 'hold_board_meeting'
    ];
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
  const { action, content, title, imageBase64, fileBase64, mimeType, recentNotes, subscriptions, userStats, strategyType, hasPermit, dailyStats, targetFormat, boardData, context } = data
  let body: any = { generationConfig: { temperature: 0.7, maxOutputTokens: 3000 }, contents: [] }

  // --- AI Board Meeting / Morning Briefing ---
  if (action === 'hold_board_meeting') {
      const d = boardData!;
      const mealSummary = d.recentMeals?.slice(0, 3).map(m => `${m.menu_name}(${m.performance_score}点)`).join(', ') || 'なし';
      const noteSummary = d.recentNotes?.slice(0, 3).map(n => n.title).join(', ') || 'なし';
      const subTotal = d.subscriptions?.reduce((sum: number, s: any) => sum + Number(s.price), 0) || 0;
      const points = d.userStats?.total_points || 0;

      let promptText = "";

      if (context === 'morning_briefing') {
          //  モーニングブリーフィング用プロンプト
          promptText = `
            **Output JSON ONLY in Japanese.**
            あなたは「自分株式会社」のAI役員団（CSO, CFO, CHO, CHRO, CKO, CMO）です。
            CEO（ユーザー）が朝、アプリを開きました。昨日のデータに基づき、今日の経営指針（ブリーフィング）を行ってください。

            【現状データ】
            - 健康(CHO): 直近食事=[${mealSummary}]
            - 戦略(CSO): 直近タスク=[${noteSummary}]
            - 財務(CFO): 月次固定費=${subTotal}円
            - 資産(CHRO): ポイント=${points}pt

            【指示】
            - 親しみやすく、かつプロフェッショナルな「おはようございます」から始めてください。
            - 昨日の活動をポジティブに評価しつつ、今日一点だけ集中すべき「本日のミッション」を提示してください。
            - JSON形式:
            {
              "agenda": "おはようございます、CEO！ (挨拶タイトル)",
              "discussion": "昨日の分析コメント（例：昨日は断捨離が進みましたね。ただ食事が乱れ気味です）。役員たちが交互に話す形式で。",
              "decision": "本日の最優先ミッション（具体的な行動目標）",
              "stock_price_impact": "達成時の予想株価上昇率"
            }
          `;
      } else {
          // 通常の役員会議プロンプト
          promptText = `
            **Output JSON ONLY in Japanese.**
            あなたは「自分株式会社」の全CxOを兼任するAIです。
            CEOの経営状態を分析し、部門間連携した「緊急動議」を行ってください。
            (データ: 食事=[${mealSummary}], タスク=[${noteSummary}], 固定費=${subTotal}円, Pt=${points})
            
            JSON形式:
            {
              "agenda": "議題タイトル",
              "discussion": "役員たちの議論内容（クロスオーバーな会話）",
              "decision": "最終決定事項（Action Item）",
              "stock_price_impact": "株価への影響予測"
            }
          `;
      }
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  
  // --- その他の機能 (既存維持) ---
  else if (action === 'analyze_knowledge_assets') {
      const notesText = recentNotes && recentNotes.length > 0 ? recentNotes.map(n => `- ${n.title}`).join('\n') : 'なし';
      const promptText = `**Output JSON ONLY in Japanese.** CKOとしてメモ分析しJSON({core_interests, analysis_comment, next_learning_suggestion})出力。\n${notesText}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'generate_content_draft') {
      const promptText = `ゴーストライターとして「${title}」を${targetFormat}形式でMarkdown作成。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'generate_press_release') {
      const promptText = `**Output JSON ONLY in Japanese.** CMOとして実績(Task:${dailyStats?.task_count})からPR JSON({headline, body, market_analysis})作成。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'evaluate_performance') {
      const stats = userStats || { total_points: 0, notes_created: 0 };
      const promptText = `**Output JSON ONLY in Japanese.** CHROとして実績(Pt:${stats.total_points})評価JSON({rank, report_content, bonus_message})。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'mental_chat') {
      const promptText = `超優しいCHROとして愚痴「${content}」を全肯定せよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'audit_meal') {
      let instruction = hasPermit ? `許可証あり。100点満点で称賛せよ。` : `CHOとして厳しく監査せよ。`;
      const promptText = `**Output JSON ONLY in Japanese.** ${instruction} 画像からJSON({menu_name, calorie_estimate, performance_score, audit_result, advice})を出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  }
  else if (action === 'extract_subscriptions_from_file') {
      const aB64 = fileBase64 || imageBase64; const aMime = mimeType || 'image/jpeg';
      const promptText = `**Output JSON ONLY.** 画像から固定費抽出JSON配列。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: aMime, data: aB64 } }] }];
  }
  else if (action === 'audit_subscriptions') {
      const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}`).join('\n');
      const promptText = `**Output in Japanese.** CFOとして固定費監査Markdown。\n${subList}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'secretary_task_from_image') {
      const promptText = `**Output JSON in Japanese.** 秘書として画像からタスク抽出JSON。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }] }];
  } 
  else if (action === 'secretary_strategy') {
      const notesList = recentNotes && recentNotes.length > 0 ? recentNotes.map((n) => `- ${n.title}`).join('\n') : 'なし';
      const promptText = `**Output in Japanese.** 秘書としてタスク状況(${notesList})から${strategyType || '今日'}の戦略Markdown。`;
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
