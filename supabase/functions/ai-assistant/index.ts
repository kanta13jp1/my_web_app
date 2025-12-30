// AI Assistant Edge Function: "The Five Emperors" (CMO Upgrade / Battle Mode)
// 概要: 複数の次世代AIモデル（GPT-5, Claude 4.5, Gemini 3等）を統合制御し、
// 単独実行（Single Mode）または競演（Battle Mode）により最適な回答を生成するシステム。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS設定: ブラウザ（Flutter Web）からのアクセスを許可するためのヘッダー
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// APIキー管理: 各AIプロバイダーの鍵を環境変数から取得
const KEYS = {
  gemini: Deno.env.get('GEMINI_API_KEY'),
  openai: Deno.env.get('OPENAI_API_KEY'),
  anthropic: Deno.env.get('ANTHROPIC_API_KEY'),
  deepseek: Deno.env.get('DEEPSEEK_API_KEY'),
  grok: Deno.env.get('XAI_API_KEY'),
};

// リクエストデータの型定義
interface AIRequest {
  action: string          // 実行する業務（例: 'audit_meal', 'draft_press_release'）
  content?: string        // ユーザーの入力テキスト
  imageBase64?: string    // 画像データ（Base64形式）
  fileBase64?: string     // その他ファイル
  mimeType?: string       // ファイル形式
  boardData?: any         // 役員会議や広報用のコンテキストデータ
  subscriptions?: any[]   // 財務データ
  userStats?: any         // ユーザー統計（資産など）
  paymentSources?: any[]  // 決済情報
  currentTime?: string    // 現在時刻（コンテキスト用）
  recentMeals?: any[]     // 食事履歴
  multi_response?: boolean // 🔥 バトルモード（複数AI回答）の有効化フラグ
  missionData?: any       // ミッション進捗（就寝許可などで使用）
  missionName?: string    // 特定のタスク名
}

serve(async (req) => {
  // 1. CORSプリフライトリクエスト（OPTIONS）への即時応答
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // 2. 認証チェック: Supabaseの認証ヘッダーが必須
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing authorization header')
    
    // Supabaseクライアント作成（DB操作やログ記録に使用）
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    // ユーザー情報の検証
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    // 3. リクエストボディの取得
        const requestData: AIRequest = await req.json()
    const { action, multi_response } = requestData

    //  AI稼働モニター用：利用可能モデル一覧を返すアクション
    if (action === 'get_models') {
        const models = await gatherAllCandidates(requestData);
        return new Response(JSON.stringify({ success: true, models }), { headers: corsHeaders });
    }

    // ============================================================
    // ⚔️ Battle Mode (複数AIによる競演・並列処理)
    // ============================================================
    if (multi_response) {
        // [Step 1] 全プロバイダーから利用可能なモデル候補を収集・スコアリング
        let candidates = await gatherAllCandidates(requestData);
        if (candidates.length === 0) throw new Error('No AI models available.');
        
        // [Step 2] スコア順（賢い順）にソート
        candidates.sort((a, b) => b.score - a.score);

        // [Step 3] "五賢帝"選抜ロジック
        // 各プロバイダー（OpenAI, Anthropic, Gemini）から「最強の1体」を選出
        const providers = ['anthropic', 'gemini', 'openai'];
        const champions = [];
        for (const p of providers) {
            const best = candidates.find(c => c.provider === p);
            if (best) champions.push(best);
        }
        // 上位2名を「対戦者（Fighters）」として採用（例: Claude 4.5 vs GPT-5）
        const fighters = champions.slice(0, 2); 
        
        // [Step 4] 並列実行（Promise.all）
        const results = await Promise.all(fighters.map(async (fighter) => {
            const start = Date.now();
            try {
                let text = '';
                // プロバイダーごとのAPI呼び出し分岐
                if (fighter.provider === 'gemini') text = await callGemini(fighter.model, KEYS.gemini!, requestData);
                else if (fighter.provider === 'anthropic') text = await callAnthropic(fighter.model, KEYS.anthropic!, requestData);
                else text = await callOpenAICompatible(fighter.provider, fighter.model, KEYS[fighter.provider as keyof typeof KEYS]!, requestData);
                
                // 実行ログの保存（DBへ）
                await logRequest(supabaseClient, user.id, action, fighter.provider, fighter.model, 200, Date.now() - start);
                
                // JSONパースが必要なアクションならパースして返す
                let parsed = text;
                if (shouldParseJson(action)) {
                    parsed = parseJsonResult(text);
                }
                return { success: true, provider: fighter.provider, model: fighter.model, result: parsed };
            } catch (e) {
                // エラー時も他を止めないよう失敗情報を返す
                return { success: false, provider: fighter.provider, error: e.message };
            }
        }));

        // 成功した結果のみを抽出
        const successes = results.filter(r => r.success);
        if (successes.length === 0) throw new Error('All models failed.');

        // 結果を返却（フロントエンドで2つの回答を比較表示する）
        return new Response(
            JSON.stringify({ success: true, is_multi: true, results: successes }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )
    }

    // ============================================================
    // 🛡️ Single Mode (単一AIによる確実な処理)
    // ============================================================
    
    // [Step 1] 候補収集とソート
    let candidates = await gatherAllCandidates(requestData);
    if (candidates.length === 0) throw new Error('No AI models available.');
    candidates.sort((a, b) => b.score - a.score);

    let finalResult = '';
    let winner: any = null;
    let logs: string[] = [];
    
    // [Step 2] フォールバック実行ループ
    // 最強モデルから順に試し、成功したら即終了。失敗したら次のモデルへ（冗長化構成）
    for (const candidate of candidates) {
        const { provider, model } = candidate;
        const startTime = Date.now();
        try {
            console.log(` Attempting: ${provider} [${model}]`);
            
            if (provider === 'gemini') finalResult = await callGemini(model, KEYS.gemini!, requestData);
            else if (provider === 'anthropic') finalResult = await callAnthropic(model, KEYS.anthropic!, requestData);
            else finalResult = await callOpenAICompatible(provider, model, KEYS[provider as keyof typeof KEYS]!, requestData);

            winner = candidate;
            await logRequest(supabaseClient, user.id, action, provider, model, 200, Date.now() - startTime);
            break; // 成功！脱出
        } catch (e) {
            logs.push(`${provider}/${model}: ${e.message}`);
            // 失敗ログを残して次へ
            await logRequest(supabaseClient, user.id, action, provider, model, 500, Date.now() - startTime, e.message);
        }
    }

    if (!winner) throw new Error(`All candidates exhausted. Logs: ${logs.join('|')}`);

    // [Step 3] 結果の整形
    let parsedResult = finalResult;
    if (shouldParseJson(action)) {
        parsedResult = parseJsonResult(finalResult);
    }

    return new Response(
      JSON.stringify({ success: true, result: parsedResult, provider: winner.provider, used_model: winner.model }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    // 致命的エラー時のレスポンス
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

// --- 🔧 Helper Functions ---

// JSON形式での出力を期待するアクションリスト
function shouldParseJson(action: string): boolean {
    return [
        'hold_board_meeting',        // 役員会議
        'suggest_next_meal',         // 食事提案
        'proactive_intervention',    // AI介入
        'analyze_image',             // 画像解析（リアル断捨離）
        'audit_meal',                // 検食
        'digital_danshari_chat',     // デジタル断捨離コーチ
        'check_bedtime_permission',  // 就寝許可
        'verify_mission_proof',      // 証拠写真検証
        'draft_press_release'        // プレスリリース作成
    ].includes(action);
}

// モデルのスコアリングロジック（ここが五賢帝の選定基準）
function calculateModelScore(provider: string, modelId: string, isVision: boolean): number {
    let score = 0;
    const id = modelId.toLowerCase();

    // 禁止リスト: 能力不足の軽量モデルは除外 (-1)
    if (id.includes('gemma')) return -1; 
    if (id.includes('nano')) return -1;
    if (id.includes('lite')) return -1;

    // スコアリング: モデル名に含まれるキーワードで能力値を決定
    // 2025年基準の次世代モデルを高く評価
    if (id.includes('claude-opus-4-5') || id.includes('claude-sonnet-4-5')) score = 1200; // 最強
    else if (id.includes('gemini-3')) score = 1150;
    else if (id.includes('gpt-5')) score = 1140;
    else if (id.includes('claude-3-7')) score = 1120;
    else if (id.includes('gemini-2.5-pro')) score = 1050;
    else if (id.includes('claude-3-5-sonnet')) score = 980;
    else if (id.includes('gemini-2.0-pro')) score = 970;
    else if (id.includes('gpt-4o') && !id.includes('mini')) score = 950;
    else if (id.includes('gemini-1.5-pro')) score = 850;
    else if (id.includes('gemini-2.0-flash')) score = 840;
    else if (id.includes('gpt-4o-mini')) score = 700; 

    // ビジョン（画像）対応のフィルタリング
    if (isVision) {
        if (id.includes('deepseek')) score = -1; // 特定プロバイダの画像認識除外など
        if (id.includes('o1') || id.includes('o3')) score = -1; 
    }

    return score;
}

// 利用可能な全モデル候補を収集する
async function gatherAllCandidates(data: AIRequest): Promise<{provider: string, model: string, score: number}[]> {
    const isVision = !!(data.imageBase64 || data.fileBase64);
    const promises: Promise<any>[] = [];
    const candidates: {provider: string, model: string, score: number}[] = [];
    
    // APIキーが存在するプロバイダーに対してモデルリスト取得を実行
    Object.keys(KEYS).forEach(provider => {
        const key = KEYS[provider as keyof typeof KEYS];
        if (key) {
            promises.push(fetchDynamicModels(provider, key).then(models => {
                models.forEach(model => {
                    const score = calculateModelScore(provider, model, isVision);
                    if (score > 0) candidates.push({ provider, model, score });
                });
            }).catch((err) => {
                console.error(`Error fetching models for ${provider}:`, err); // エラーログも追加推奨
            }));
        }
    });
    await Promise.all(promises);

    // 🔥【追加】ここで全候補をログ出力します
    console.log("=== GATHERED CANDIDATES ===");
    console.log(JSON.stringify(candidates, null, 2)); // 見やすく整形して出力
    console.log("===========================");

    return candidates;
}

// 各プロバイダーから動的にモデルリストを取得
async function fetchDynamicModels(provider: string, apiKey: string): Promise<string[]> {
    try {
        let url = ''; let headers: any = {};
        switch (provider) {
            case 'openai': url = 'https://api.openai.com/v1/models'; headers = { 'Authorization': `Bearer ${apiKey}` }; break;
            case 'anthropic': url = 'https://api.anthropic.com/v1/models'; headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' }; break;
            case 'gemini': url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`; headers = {}; break;
            default: return [];
        }
        const resp = await fetch(url, { headers });
        if (!resp.ok) return [];
        const json = await resp.json();
        // プロバイダーごとのレスポンス形式に合わせてモデルIDを抽出
        if (provider === 'gemini') return (json.models || []).map((m: any) => m.name.replace('models/', ''));
        if (provider === 'anthropic') return (json.data || []).map((m: any) => m.id);
        return (json.data || []).map((m: any) => m.id);
    } catch { return []; }
}

// OpenAI互換APIの呼び出し
async function callOpenAICompatible(provider: string, model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "system", content: "You are an executive AI. Output in Japanese." }, { role: "user", content: prompt }];
    
    // 画像がある場合はメッセージ形式を変更
    if (data.imageBase64) messages = [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${data.mimeType||'image/jpeg'};base64,${data.imageBase64}` } }] }];
    
    const resp = await fetch('https://api.openai.com/v1/chat/completions', { 
        method: 'POST', 
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` }, 
        body: JSON.stringify({ model, messages, response_format: {type: "json_object"} }) 
    });
    
    if (!resp.ok) { const txt = await resp.text(); throw new Error(`OpenAI Error: ${txt}`); }
    const json = await resp.json(); return json.choices[0].message.content;
}

// Anthropic APIの呼び出し
async function callAnthropic(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    let messages: any[] = [{ role: "user", content: prompt }];
    
    // 画像がある場合はメッセージ形式を変更
    if (data.imageBase64) messages = [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: data.mimeType||"image/jpeg", data: data.imageBase64 } }, { type: "text", text: prompt }] }];
    
    const resp = await fetch('https://api.anthropic.com/v1/messages', { 
        method: 'POST', 
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }, 
        body: JSON.stringify({ model, max_tokens: 4000, messages }) 
    });
    
    if (!resp.ok) { const txt = await resp.text(); throw new Error(`Anthropic Error: ${txt}`); }
    const json = await resp.json(); return json.content[0].text;
}

// Gemini APIの呼び出し
async function callGemini(model: string, apiKey: string, data: AIRequest): Promise<string> {
    const prompt = buildPrompt(data);
    const body: any = { contents: [] };
    
    // 画像がある場合はinline_dataとして追加
    if (data.imageBase64) body.contents.push({ parts: [{ text: prompt }, { inline_data: { mime_type: data.mimeType||'image/jpeg', data: data.imageBase64 } }] });
    else body.contents.push({ parts: [{ text: prompt }] });
    
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, { 
        method: 'POST', 
        headers: {'Content-Type': 'application/json'}, 
        body: JSON.stringify(body) 
    });
    
    if (!resp.ok) { const txt = await resp.text(); throw new Error(`Gemini Error: ${txt}`); }
    const json = await resp.json(); return json.candidates[0].content.parts[0].text;
}

// アクションに応じたプロンプト生成
function buildPrompt(data: AIRequest): string {
    const { action, content, boardData, currentTime, missionData, missionName, recentMeals } = data;
    const jsonPrefix = "Output purely valid JSON.";

    // プレスリリース作成（CMO）用のプロンプト
    if (action === 'draft_press_release') {
        const stats = boardData?.userStats || {};
        const points = stats.total_points || 0;
        const notes = boardData?.recentNotes?.map((n:any) => n.title).join(', ') || '特になし';
        
        return `${jsonPrefix}
        Role: CMO (Chief Marketing Officer) of 'Jibun Inc.'
        Language: Japanese.
        Context: The user (CEO) wants to announce their recent achievements to the world.
        Achievements: Total Assets: ${points} Pt. Recent Projects: ${notes}.
        Task: Write a professional, slightly exaggerated, inspiring press release.
        
        Output JSON:
        {
          "title": "String (Catchy Title)",
          "body": "String (Main content, 300 chars max)",
          "hashtags": ["#JibunInc", "#AI", "#Growth"]
        }`;
    }

    // 証拠写真の検証（厳格な検査官）
    if (action === 'verify_mission_proof') return `${jsonPrefix} Role: Strict Inspector. Language: Japanese. Verify photo for "${missionName}". Logic: Messy->REJECT. Clean->APPROVE. Output: { "verified": boolean, "comment": "string", "score": number }`;
    
    // 就寝許可判定（門番）
    if (action === 'check_bedtime_permission') {
        const missions = missionData || {};
        const incomplete = Object.keys(missions).filter(k => !missions[k]);
        return `${jsonPrefix} Role: Gatekeeper. Language: Japanese. Status: ${JSON.stringify(missions)}. Output: { "permission_granted": ${incomplete.length === 0}, "title": "string", "message": "string", "missing_tasks": [], "punishment": "string" }`;
    }
    
    // 食事提案（CHO）
    if (action === 'suggest_next_meal') return `${jsonPrefix} Role: Chef. Language: Japanese. Context: ${currentTime}. Output: { "menu_name": "string", "reason": "string", "ingredients": [], "recipe_steps": [], "calorie_estimate": number, "nutrients": {} }`;
    
    // 画像分析（断捨離コーチ）
    if (action === 'analyze_image') return `${jsonPrefix} Role: Toxic Coach. Language: Japanese. Analyze photo. Output: { "result": "string", "item_name": "string", "keep_score": number }`;
    
    // デジタル断捨離チャット（鬼コーチ）
    if (action === 'digital_danshari_chat') return `${jsonPrefix} Role: Digital Demon. Language: Japanese. User: "${content}". Output: { "message": "string", "mission": "string", "angry_score": number }`;
    
    // プロアクティブ介入（全社横断）
    if (action === 'proactive_intervention') return `${jsonPrefix} Time: ${currentTime}. Language: Japanese. Output: { "should_intervene": boolean, "role": "string", "message": "string", "action_label": "string" }`;
    
    // 役員会議（議長）
    if (action === 'hold_board_meeting') return `${jsonPrefix} Role: Chairman. Language: Japanese. Output: { "agenda": "string", "discussion": "string", "decision": "string", "stock_price_impact": "string" }`;
    
    // デフォルト（単純応答）
    return content || '';
}

// JSON文字列のクリーンアップとパース
function parseJsonResult(result: string): any {
    try { return JSON.parse(result.replace(/```json/g, '').replace(/```/g, '').trim()); } catch { return { error: "JSON Parse Failed", raw: result }; }
}

// リクエストログの保存
async function logRequest(supabase: any, userId: string, action: string, provider: string, model: string, status: number, duration: number, errorMsg: string = '') {
    try { await supabase.from('ai_request_logs').insert({ user_id: userId, action, provider, model, status_code: status, duration_ms: duration, error_message: errorMsg.substring(0, 1000) }); } catch {}
}
