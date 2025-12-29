// AI Assistant Edge Function with Google Gemini
// Full Company Structure including CKO (Chief Knowledge Officer)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

const MODELS_TO_TRY = [
  'gemini-1.5-pro', // 長文推論に強いモデルを優先
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
  targetFormat?: string // CKO用: blog, slide, book_plot etc.
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
      'analyze_knowledge_assets' //  CKO用JSON
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
  const { action, content, title, imageBase64, fileBase64, mimeType, recentNotes, subscriptions, userStats, strategyType, hasPermit, dailyStats, targetFormat } = data
  let body: any = { generationConfig: { temperature: 0.7, maxOutputTokens: 3000 }, contents: [] }

  // ---  CKO: 知的資産分析レポート ---
  if (action === 'analyze_knowledge_assets') {
      const notesText = recentNotes && recentNotes.length > 0 
        ? recentNotes.map(n => `- ${n.title}: ${n.content.substring(0, 100)}...`).join('\n')
        : '（データなし）';

      const promptText = `
        **Output JSON ONLY in Japanese.**
        あなたは「自分株式会社」のCKO（最高知識責任者）です。
        CEO（ユーザー）が最近蓄積した以下のメモデータを分析し、現在の「知的関心」や「専門性の方向性」をレポートしてください。

        【最近のメモ】
        ${notesText}

        以下のJSON形式で出力してください。
        {
          "core_interests": ["関心領域1", "関心領域2", "関心領域3"],
          "analysis_comment": "分析コメント。CEOが今、どのような分野に強みを持っているか、または何に関心があるかを専門的に解説。",
          "next_learning_suggestion": "次に学ぶべきトピックや、読むべき本のジャンルなどの具体的な提案。"
        }
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  // ---  CKO: ゴーストライター（コンテンツ生成） ---
  else if (action === 'generate_content_draft') {
      const formatInstruction = targetFormat === 'blog' ? '読みやすく共感を呼ぶブログ記事形式' :
                                targetFormat === 'slide' ? 'プレゼンテーションのアウトライン（スライド構成案）' :
                                targetFormat === 'book' ? '書籍の目次とプロット（あらすじ）' : 'ビジネスメール形式';

      const promptText = `
        あなたはプロのゴーストライター兼CKOです。
        CEOのメモ（アイデアの種）を元に、${formatInstruction}でコンテンツを作成してください。
        
        【メモ内容】
        タイトル: ${title}
        本文: ${content}

        【指示】
        - 読者を惹きつける魅力的なタイトルをつけてください。
        - 論理的かつエモーショナルな構成にしてください。
        - 専門用語があれば適宜補足し、わかりやすくしてください。
        - Markdown形式で出力してください。
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  
  // --- 既存機能群 (省略せず記述) ---
  else if (action === 'generate_press_release') {
      const promptText = `**Output JSON ONLY in Japanese.** CMOとして本日の実績(Task:${dailyStats?.task_count}, Danshari:${dailyStats?.danshari_count})から壮大なプレスリリースJSON({headline, body, market_analysis})を作成せよ。`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'evaluate_performance') {
      const stats = userStats || { total_points: 0, notes_created: 0 };
      const promptText = `**Output JSON ONLY in Japanese.** CHROとして実績(Pt:${stats.total_points})を評価しJSON({rank, report_content, bonus_message})を出力。`;
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
      const promptText = `**Output JSON ONLY.** 画像から固定費項目抽出、JSON配列[{service_name, price, description}]出力。`;
      body.contents = [{ parts: [{ text: promptText }, { inline_data: { mime_type: aMime, data: aB64 } }] }];
  }
  else if (action === 'audit_subscriptions') {
      const subList = subscriptions!.map(s => `- ${s.service_name}: ${s.price}`).join('\n');
      const promptText = `**Output in Japanese.** CFOとして固定費監査し削減案をMarkdownで提示。\n${subList}`;
      body.contents = [{ parts: [{ text: promptText }] }];
  }
  else if (action === 'secretary_task_from_image') {
      const promptText = `**Output JSON in Japanese.** 秘書として画像からタスク抽出、JSON({title, content, priority})出力。`;
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
