// AI Assistant Edge Function: "The Five Emperors" (Ultimate Edition)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { AI_CHARACTER_PREAMBLE } from "../_shared/ai_character_preamble.ts";
import { AiAssistantChatError, handleAiAssistantChat } from "./chat.ts";
import { createSupabaseAiAssistantChatStore } from "./chat_supabase.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
  "Content-Type": "application/json",
};

const KEYS = {
  gemini: Deno.env.get("GEMINI_API_KEY"),
  openai: Deno.env.get("OPENAI_API_KEY"),
  anthropic: Deno.env.get("ANTHROPIC_API_KEY"),
  deepseek: Deno.env.get("DEEPSEEK_API_KEY"),
  grok: Deno.env.get("XAI_API_KEY"),
  hedra: Deno.env.get("HEDRA_API_KEY"),
};

const FALLBACK_MODELS = [
  { provider: "openai", model: "gpt-4o-mini" },
  { provider: "anthropic", model: "claude-haiku-4-5-20251001" },
  { provider: "gemini", model: "gemini-2.5-flash" },
  { provider: "deepseek", model: "deepseek-v4-flash" },
];

const MODEL_CATALOG = [
  {
    name: "claude-sonnet-4-6",
    provider: "Anthropic",
    description: "品質重視の推奨モデル",
    score: 980,
  },
  {
    name: "gpt-4o",
    provider: "OpenAI",
    description: "品質重視の推奨モデル",
    score: 970,
  },
  {
    name: "gpt-4o-mini",
    provider: "OpenAI",
    description: "速度重視の推奨モデル",
    score: 910,
  },
  {
    name: "claude-haiku-4-5-20251001",
    provider: "Anthropic",
    description: "速度重視の推奨モデル",
    score: 900,
  },
  {
    name: "gemini-2.5-flash",
    provider: "Google",
    description: "Gemini 系の推奨モデル",
    score: 860,
  },
  {
    name: "gemma-3n-e2b-it",
    provider: "Google",
    description: "Gemini 系の軽量モデル",
    score: 820,
  },
  {
    name: "deepseek-v4-pro",
    provider: "DeepSeek",
    description:
      "推論特化の DeepSeek V4 Pro (旧 deepseek-reasoner / 2026-07-24移行)",
    score: 780,
  },
  {
    name: "deepseek-v4-flash",
    provider: "DeepSeek",
    description: "高速な DeepSeek V4 Flash (旧 deepseek-chat / 2026-07-24移行)",
    score: 760,
  },
];

// 型定義の追加（any排除のため）
interface AIRequest {
  action: string;
  model?: string;
  content?: string;
  text?: string;
  styleName?: string;
  styleInstruction?: string;
  imageBase64?: string;
  mimeType?: string;
  targetLanguage?: string;
  userId?: string;
  recentNotes?: Record<string, unknown>[];
  userStats?: Record<string, unknown>;
  participants?: string[];
  useMagi?: boolean;
  melchiorModel?: string;
  balthasarModel?: string;
  casperModel?: string;
  synthesisModel?: string;
  // マイスキル関連
  skillId?: string;
  skillName?: string;
  skillDescription?: string;
  promptTemplate?: string;
  skillModel?: string;
  skillTags?: string[];
  // 音声AIチャット (long-term memory)
  message?: string;
  conversationId?: string;
  conversationContext?: string; // 'general_chat' | 'ai_university_quiz' | 'habit_coach'
  voiceUsed?: boolean;
  responseMode?: string;
  avatarImageUrl?: string;
  voice?: string;
  title?: string;
}

interface Fighter {
  provider: string;
  model: string;
}

interface MagiNodeProfile {
  nodeName: string;
  viewpoint: string;
  instruction: string;
  provider: string;
  defaultModel: string;
}

interface MagiOpinion {
  nodeName: string;
  viewpoint: string;
  content: string;
}

const MAGI_OPINION_MAX_LENGTH = 900;
const DEFAULT_MELCHIOR_MODEL = "gpt-4o-mini";
const DEFAULT_BALTHASAR_MODEL = "claude-sonnet-4-6";
const DEFAULT_CASPER_MODEL = "gemini-2.5-flash";
const DEFAULT_SYNTHESIS_MODEL = "claude-sonnet-4-6";
// Extended Thinking / 複雑な推論タスク向け (2026-04-17: claude-opus-4-7 に更新) — 将来の extended_thinking action で使用予定
// deno-lint-ignore no-unused-vars
const DEFAULT_EXTENDED_THINKING_MODEL = "claude-opus-4-7";

const MAGI_NODE_PROFILES: MagiNodeProfile[] = [
  {
    nodeName: "MELCHIOR",
    viewpoint: "論理・分析重視",
    instruction:
      "Provide logical, evidence-based analysis with clear tradeoffs and practical recommendations.",
    provider: "openai",
    defaultModel: DEFAULT_MELCHIOR_MODEL,
  },
  {
    nodeName: "BALTHASAR",
    viewpoint: "共感・人間理解重視",
    instruction:
      "Focus on emotional nuance, empathy, and how the response will feel for the user.",
    provider: "anthropic",
    defaultModel: DEFAULT_BALTHASAR_MODEL,
  },
  {
    nodeName: "CASPER",
    viewpoint: "批判・リスク検討",
    instruction:
      "Look for blind spots, edge cases, and strategic risks before making a recommendation.",
    provider: "gemini",
    defaultModel: DEFAULT_CASPER_MODEL,
  },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await supabaseClient.auth
      .getUser();
    if (userError || !user) throw new Error("Unauthorized");

    const requestData: AIRequest = await req.json().catch(() => ({}));
    const { action, model: targetModel } = requestData;

    const requestContent = requestData.content ?? requestData.text;
    const runFallbackChain = async (
      originalPrompt: string,
      image?: { base64: string; mime: string },
    ) => {
      // Windows版#94: targetModel 指定時でも quota/rate_limit 時は FALLBACK_MODELS に切替
      // (BI board meeting 等は claude-sonnet-4-6 を明示指定するため fallback が機能していなかった)
      const primaryChain: Fighter[] = [];
      if (targetModel) {
        const primary = {
          provider: inferProvider(targetModel),
          model: targetModel,
        };
        if (isProviderAvailable(primary.provider)) primaryChain.push(primary);
      }
      // 既に primary にあるモデルは除外して追加
      for (const m of FALLBACK_MODELS) {
        if (
          !primaryChain.some((p) =>
            p.provider === m.provider && p.model === m.model
          )
        ) {
          primaryChain.push(m);
        }
      }
      if (primaryChain.length === 0) {
        const ps = getProviderStatus();
        const err: Error & {
          missing_providers?: string[];
          provider_status?: unknown;
        } = new Error(
          "No AI providers configured — すべての API キーが未設定です",
        );
        err.missing_providers = ps.missing;
        err.provider_status = ps;
        throw err;
      }
      let lastError: unknown;
      const attemptedProviders: string[] = [];
      for (const fighter of primaryChain) {
        if (!isProviderAvailable(fighter.provider)) continue;
        attemptedProviders.push(fighter.provider);
        try {
          const result = await callAI(fighter, KEYS, {
            ...requestData,
            content: originalPrompt,
            imageBase64: image?.base64,
            mimeType: image?.mime,
          });
          if (fighter !== primaryChain[0]) {
            console.warn(
              `[fallback] used ${fighter.provider}:${fighter.model} after primary failure`,
            );
          }
          return result;
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e);
          const isQuota =
            /quota|rate.?limit|429|insufficient_quota|RESOURCE_EXHAUSTED/i.test(
              msg,
            );
          console.error(
            `Model ${fighter.model} failed (quota=${isQuota}):`,
            msg,
          );
          lastError = e;
          // quota 以外の一時エラー (400 等) でも次プロバイダーを試す
        }
      }
      // 全 primaryChain 失敗 — 未設定プロバイダーの情報を含めて throw
      const ps = getProviderStatus();
      const finalMsg = lastError instanceof Error
        ? lastError.message
        : String(lastError ?? "unknown");
      const err: Error & {
        attempted_providers?: string[];
        missing_providers?: string[];
        provider_status?: unknown;
      } = new Error(
        `All configured AI providers failed. last=${finalMsg} | missing=${
          ps.missing.join(",") || "(none)"
        }`,
      );
      err.attempted_providers = attemptedProviders;
      err.missing_providers = ps.missing;
      err.provider_status = ps;
      throw err;
    };

    const runPromptWithStrategy = async (
      originalPrompt: string,
      image?: { base64: string; mime: string },
    ) => {
      const shouldUseMagi = requestData.useMagi ?? true;
      if (!shouldUseMagi) {
        return await runFallbackChain(originalPrompt, image);
      }
      return await runMagiChain({
        prompt: originalPrompt,
        requestData: {
          ...requestData,
          content: originalPrompt,
          imageBase64: image?.base64,
          mimeType: image?.mime,
        },
        image,
        fallback: runFallbackChain,
      });
    };

    // --- 1. GET MODELS ---
    if (action === "get_models") {
      const models = MODEL_CATALOG.filter((item) =>
        isProviderAvailable(item.provider)
      );
      const providerStatus = getProviderStatus();
      return new Response(
        JSON.stringify({
          success: true,
          models,
          provider_status: providerStatus,
        }),
        { headers: corsHeaders },
      );
    }

    // --- 1.5 Provider Status (Windows版#94) — Flutter 側でバナー表示 ---
    if (action === "get_provider_status") {
      return new Response(
        JSON.stringify({ success: true, ...getProviderStatus() }),
        { headers: corsHeaders },
      );
    }

    if (action === "assistant_video_reply") {
      const userMessage = (requestData.message ?? requestContent ?? "").trim();
      if (!userMessage) throw new Error("content is required");

      const script = await runPromptWithStrategy(
        buildAssistantVideoPrompt(userMessage),
      );

      if (!KEYS.hedra) {
        return new Response(
          JSON.stringify({
            success: true,
            result: {
              provider: "hedra",
              status: "fallback_text",
              script,
              id: null,
              videoUrl: null,
              previewUrl: null,
              downloadUrl: null,
              reason: "HEDRA_API_KEY not configured",
            },
          }),
          { headers: corsHeaders },
        );
      }

      try {
        const video = await createHedraVideo(requestData, script);
        return new Response(
          JSON.stringify({
            success: true,
            result: {
              provider: "hedra",
              script,
              ...video,
            },
          }),
          { headers: corsHeaders },
        );
      } catch (error: unknown) {
        const reason = error instanceof Error ? error.message : String(error);
        const creditShortage = isHedraCreditError(undefined, reason);
        return new Response(
          JSON.stringify({
            success: true,
            result: {
              provider: "hedra",
              status: creditShortage ? "credit_shortage" : "fallback_text",
              script,
              id: null,
              videoUrl: null,
              previewUrl: null,
              downloadUrl: null,
              reason,
              userMessage: creditShortage
                ? "Hedra API credits are low. The text reply is available, but video generation is paused until credits are replenished."
                : undefined,
            },
          }),
          { headers: corsHeaders },
        );
      }
    }

    // --- 2. AIフォト行動アドバイザー ---
    if (action === "analyze_photo_actions") {
      const imageBase64 = requestData.imageBase64?.trim();
      if (!imageBase64) throw new Error("Image required");
      if (imageBase64.length > 11_200_000) {
        throw new Error("Image must be 8MB or smaller");
      }
      const mimeType = requestData.mimeType?.toLowerCase().trim() ||
        "image/jpeg";
      if (!["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
        throw new Error("JPEG, PNG, or WebP image required");
      }

      const prompt = `
あなたは、写真から「今すべき行動」を整理する生活支援アシスタントです。
添付写真に実際に見えているものだけを観察し、日本語で優先順位付きの具体的な行動を3〜5件提案してください。

必須ルール:
- 写真にない事実、賞味期限、故障、衛生状態、所有者の意図を断定しない。不鮮明な点は不確実だと明記する。
- 人物の特定、属性推測、医療診断はしない。顔、住所、書類などの個人情報を回答に書き起こさない。
- 食品、電気、火気、薬品、カビ、害虫、構造物などの危険が疑われる場合は、無理に触らず表示や取扱説明書を確認し、必要なら専門家へ相談する注意を含める。
- 行動は「何を」「どの順で」「なぜ行うか」が分かる短い表現にする。画像だけでは判断できない確認作業も行動としてよい。
- JSON以外の文章やMarkdownコードフェンスを出力しない。

出力JSON:
{
  "scene_summary": "写真から確認できる状況の短い要約",
  "observations": ["目視できる事実（最大5件）"],
  "actions": [
    {
      "priority": 1,
      "title": "具体的な行動",
      "reason": "この順番で行う理由",
      "estimated_minutes": 5,
      "caution": "注意が必要な場合のみ。なければnull"
    }
  ],
  "confidence_note": "写真だけでは判断できない点を含む短い注記",
  "safety_note": "安全上の注意があれば記載。なければnull"
}

priorityは1（最優先）、2（優先）、3（できれば）のいずれか、estimated_minutesは1〜180の整数にしてください。
`;

      const resultStr = await runFallbackChain(prompt, {
        base64: imageBase64,
        mime: mimeType,
      });
      const cleanJson = resultStr.replace(/```json|```/g, "").trim();
      const parsed: unknown = JSON.parse(cleanJson);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("AI returned an invalid action plan");
      }
      const raw = parsed as Record<string, unknown>;
      const cleanText = (value: unknown, fallback = ""): string =>
        typeof value === "string" && value.trim()
          ? value.trim().slice(0, 600)
          : fallback;
      const rawActions = Array.isArray(raw.actions) ? raw.actions : [];
      const actions = rawActions.slice(0, 6).flatMap((value, index) => {
        if (!value || typeof value !== "object" || Array.isArray(value)) {
          return [];
        }
        const row = value as Record<string, unknown>;
        const title = cleanText(row.title);
        const reason = cleanText(row.reason);
        if (!title || !reason) return [];
        const parsedPriority = Number(row.priority);
        const priority = Number.isFinite(parsedPriority)
          ? Math.max(1, Math.min(3, Math.round(parsedPriority)))
          : Math.min(index + 1, 3);
        const parsedMinutes = Number(row.estimated_minutes);
        const estimatedMinutes = Number.isFinite(parsedMinutes)
          ? Math.max(1, Math.min(180, Math.round(parsedMinutes)))
          : 5;
        return [{
          priority,
          title,
          reason,
          estimated_minutes: estimatedMinutes,
          caution: cleanText(row.caution) || null,
        }];
      }).sort((a, b) => a.priority - b.priority);
      if (actions.length === 0) {
        throw new Error("AI did not return actionable suggestions");
      }
      const observations =
        (Array.isArray(raw.observations) ? raw.observations : []).map((value) =>
          cleanText(value)
        ).filter(Boolean).slice(0, 5);
      const result = {
        scene_summary: cleanText(
          raw.scene_summary,
          "写真に写っている状況を確認しました。",
        ),
        observations,
        actions,
        confidence_note: cleanText(
          raw.confidence_note,
          "写真に写っている範囲だけをもとにした提案です。",
        ),
        safety_note: cleanText(raw.safety_note) || null,
      };
      return new Response(
        JSON.stringify({ success: true, result, image_persisted: false }),
        { headers: corsHeaders },
      );
    }

    // --- 2b. リアル断捨離クエスト（後方互換） ---
    if (action === "analyze_danshari_item") {
      if (!requestData.imageBase64) throw new Error("Image required");

      const prompt = `
            あなたは「自分株式会社」のCSO（最高戦略責任者）です。
            ユーザーがアップロードした「断捨離候補のモノ」の画像を分析し、辛口かつ的確に判定を下してください。

            判定基準:
            1. 「ときめき」が感じられるか？
            2. 実用性はあるか？（ボロボロではないか？）
            3. 過去への執着ではないか？

            出力フォーマット (JSONのみ):
            {
                "item_name": "アイテム名（例: 古びたマグカップ）",
                "spark_joy_score": 0-100の数値 (低いほど捨てるべき),
                "decision": "KEEP" または "DISCARD",
                "reason": "判定理由（例: 持ち手が欠けており、実用性がありません。）",
                "witty_comment": "CSOとしての皮肉やユーモアのあるコメント（例: これを『ヴィンテージ』と呼ぶのは無理がありますね。）"
            }
            `;

      const resultStr = await runFallbackChain(prompt, {
        base64: requestData.imageBase64!,
        mime: requestData.mimeType || "image/jpeg",
      });
      const cleanJson = resultStr.replace(/```json|```/g, "").trim();
      const result = JSON.parse(cleanJson);
      return new Response(JSON.stringify({ success: true, result }), {
        headers: corsHeaders,
      });
    }

    // --- 3. Board Meeting ---
    if (action === "hold_board_meeting") {
      const contextFromClient = requestContent ?? "";
      const systemPrompt = `
あなたは「自分株式会社」の緊急役員会議 BI レポート生成システムです。
雑談ではなく、受け取った現状データだけを根拠に、4名の役員が短く具体的な分析を返してください。

必須ルール:
- 数字が渡されている項目は、できるだけ具体的に引用する
- 不明な数字は推測しない
- 各発言は「現状の数字 -> 問題解釈 -> 次の一手」の順で 2〜4 文にする
- 抽象論や精神論だけで終わらせない
- CFO はサブスク・ポイント・固定費・投資対効果を見る
- CKO はノート・継続実行・深い作業・知識の実行率を見る
- CHRO はストリーク・禁欲・回復行動・習慣崩れの兆候を見る
- CEO は全体を統合し、48時間以内の具体的な実行判断を下す

以下の JSON だけを返してください。コードブロックや前置きは禁止です。
{
  "messages": [
    {
      "speaker_name": "AI CFO",
      "role": "CFO",
      "content": "CFO としての分析..."
    },
    {
      "speaker_name": "AI CKO",
      "role": "CKO",
      "content": "CKO としての分析..."
    },
    {
      "speaker_name": "AI CHRO",
      "role": "CHRO",
      "content": "CHRO としての分析..."
    },
    {
      "speaker_name": "AI CEO",
      "role": "CEO",
      "content": "CEO としての統合判断..."
    }
  ],
  "conclusion": "CEO が今すぐ実行すべき具体策..."
}
`;

      const finalPrompt =
        `${systemPrompt}\n\n[CURRENT BOARD CONTEXT]\n${contextFromClient}`;
      const resultStr = await runPromptWithStrategy(finalPrompt);
      const match = resultStr.match(/\{[\s\S]*\}/);
      if (!match) {
        throw new Error("AI response did not contain valid JSON.");
      }
      const cleanJson = match[0];
      // Gemma等の小型モデルはJSON構文エラーを起こしやすいため修復を試みる
      let result: Record<string, unknown>;
      try {
        result = JSON.parse(cleanJson);
      } catch (_parseErr) {
        // 修復: trailing commas, 不正なカンマ, シングルクォートをダブルに
        const repaired = cleanJson
          .replace(/,\s*([}\]])/g, "$1") // trailing commas
          .replace(/([}\]"0-9])\s*\n\s*"/g, '$1,"') // missing commas between elements
          .replace(/'/g, '"'); // single -> double quotes
        try {
          result = JSON.parse(repaired);
        } catch (_repairErr) {
          // 最終フォールバック: 生テキストを返してフロント側でフォールバック処理させる
          const fallbackResult = {
            messages: [{
              speaker_name: "AI CEO",
              role: "CEO",
              content: resultStr.substring(0, 500),
            }],
            conclusion:
              "AI応答のJSON解析に失敗しました。生テキストを表示しています。",
            _raw_fallback: true,
          };
          return new Response(
            JSON.stringify({ success: true, result: fallbackResult }),
            { headers: corsHeaders },
          );
        }
      }
      const rawMessages = Array.isArray(result.messages) ? result.messages : [];
      const normalizedMessages = rawMessages
        .map((item: Record<string, unknown>) => {
          const role = typeof item.role === "string" ? item.role : "CEO";
          const speakerName = typeof item.speaker_name === "string"
            ? item.speaker_name
            : typeof item.speakerName === "string"
            ? item.speakerName
            : `AI ${role}`;
          const content = typeof item.content === "string"
            ? item.content.trim()
            : "";
          if (!content) return null;
          return {
            speaker_name: speakerName,
            role,
            content,
          };
        })
        .filter(Boolean);
      const formattedResult = {
        messages: normalizedMessages,
        conclusion: typeof result.conclusion === "string"
          ? result.conclusion.trim()
          : "",
      };

      return new Response(
        JSON.stringify({ success: true, result: formattedResult }),
        { headers: corsHeaders },
      );
    }

    // --- 「我が闘争」コラム生成 ---
    if (action === "my_struggle_column") {
      const contextData = requestContent ?? "{}";
      const prompt = `あなたは文学的才能を持つコラムニストです。
以下のユーザーの日常データを元に「我が闘争」というタイトルのコラムを書いてください。

ルール:
- 日常の些細な出来事（習慣の達成、タスクの消化、誘惑との戦い）を壮大に、文学的に描写する
- ユーモアと自虐を交え、読んでいて楽しいコラムにする
- 太宰治や村上春樹のような文体を意識する
- 800〜1200字程度
- 具体的なデータ（習慣の達成数、ストリーク日数など）があれば引用する
- 最後に明日への決意で締める

出力フォーマット (JSONのみ):
{
  "title": "我が闘争 — サブタイトル（その日のテーマ）",
  "column": "コラム本文"
}

[ユーザーの今日のデータ]
${contextData}`;

      const resultStr = await runPromptWithStrategy(prompt);
      const match = resultStr.match(/\{[\s\S]*\}/);
      if (!match) {
        return new Response(
          JSON.stringify({
            success: true,
            result: {
              title: "我が闘争 — 言葉にならぬ日",
              column: resultStr.substring(0, 1200),
            },
          }),
          { headers: corsHeaders },
        );
      }
      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(match[0]);
      } catch {
        parsed = { title: "我が闘争", column: resultStr.substring(0, 1200) };
      }
      return new Response(
        JSON.stringify({
          success: true,
          result: {
            title: typeof parsed.title === "string" ? parsed.title : "我が闘争",
            column: typeof parsed.column === "string"
              ? parsed.column
              : resultStr.substring(0, 1200),
          },
        }),
        { headers: corsHeaders },
      );
    }

    // --- 行動・発言のAI考察 ---
    if (action === "behavior_analysis") {
      const entryData = requestContent ?? "{}";
      const prompt = `あなたは認知行動療法の専門家であり、自己改善コーチです。
以下のユーザーの行動または発言を分析し、考察を提供してください。

ルール:
- 批判ではなく建設的なフィードバックを提供する
- なぜその行動/発言をしたのか、背景にある心理を分析する
- 次に同じ状況になった時、どうすればより良い選択ができるかを提案する
- 200〜300字程度で簡潔に
- 日本語で出力

出力フォーマット (JSONのみ):
{ "analysis": "考察テキスト" }

[ユーザーの行動/発言データ]
${entryData}`;

      const resultStr = await runPromptWithStrategy(prompt);
      const match = resultStr.match(/\{[\s\S]*\}/);
      let analysis = resultStr.substring(0, 400);
      if (match) {
        try {
          const parsed = JSON.parse(match[0]);
          if (typeof parsed.analysis === "string") {
            analysis = parsed.analysis;
          }
        } catch { /* use raw */ }
      }
      return new Response(
        JSON.stringify({
          success: true,
          result: { analysis },
        }),
        { headers: corsHeaders },
      );
    }

    // THOUGHT_INTERRUPT_ELIMINATOR #T2: AI介入提案
    // abstinence_slips の 30日分を集計し、曜日/時間帯/アイテム別の
    // 傾向を LLM に渡して介入提案を生成する
    if (action === "suggest_slip_intervention") {
      // 直近 30日間の slip を取得 (RLS により本人分のみ)
      const sinceIso = new Date(Date.now() - 30 * 86_400_000).toISOString();
      const { data: slipRows, error: slipErr } = await supabaseClient
        .from("abstinence_slips")
        .select("item_id, slipped_at, context, trigger_note")
        .gte("slipped_at", sinceIso)
        .order("slipped_at", { ascending: false })
        .limit(200);

      if (slipErr) {
        return new Response(
          JSON.stringify({
            success: false,
            error: `Failed to load slips: ${slipErr.message}`,
          }),
          { headers: corsHeaders, status: 500 },
        );
      }

      const slips = (slipRows ?? []) as Array<{
        item_id: string;
        slipped_at: string;
        context: string | null;
        trigger_note: string | null;
      }>;

      if (slips.length === 0) {
        return new Response(
          JSON.stringify({
            success: true,
            result: {
              total_slips: 0,
              insights:
                "直近30日間のslip記録がありません。現状維持で問題ありません。",
              intervention_tips: [],
              risk_score: 0,
              top_items: [],
              top_weekdays: [],
              top_hours: [],
            },
          }),
          { headers: corsHeaders },
        );
      }

      // ── 集計: アイテム別 / 曜日別 / 時間帯別 ──
      const itemCounts = new Map<string, number>();
      const weekdayCounts = new Map<number, number>();
      const hourCounts = new Map<number, number>();
      const triggers: string[] = [];

      const weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"];

      for (const slip of slips) {
        itemCounts.set(slip.item_id, (itemCounts.get(slip.item_id) ?? 0) + 1);
        // JST に変換して曜日・時間を取得
        const jstMs = Date.parse(slip.slipped_at) + 9 * 60 * 60 * 1000;
        const d = new Date(jstMs);
        const weekday = d.getUTCDay(); // 0=日 ... 6=土
        const hour = d.getUTCHours();
        weekdayCounts.set(weekday, (weekdayCounts.get(weekday) ?? 0) + 1);
        hourCounts.set(hour, (hourCounts.get(hour) ?? 0) + 1);
        if (slip.trigger_note && slip.trigger_note.trim().length > 0) {
          triggers.push(slip.trigger_note.trim());
        }
      }

      const topItems = [...itemCounts.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([item_id, count]) => ({ item_id, count }));

      const topWeekdays = [...weekdayCounts.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([wd, count]) => ({
          weekday: weekdayLabels[wd] ?? String(wd),
          count,
        }));

      const topHours = [...hourCounts.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([hour, count]) => ({
          hour_range: `${hour}時台`,
          count,
        }));

      // 直近7日 vs 直近30日 の傾向で risk score を算出
      const now = Date.now();
      const last7d = slips.filter((s) =>
        Date.parse(s.slipped_at) >= now - 7 * 86_400_000
      ).length;
      const last30d = slips.length;
      // 30日平均/週と比較して直近7日が多ければ risk 増
      const weeklyAvg = last30d / (30 / 7);
      const riskRaw = weeklyAvg > 0 ? last7d / weeklyAvg : 0;
      const riskScore = Math.max(
        0,
        Math.min(100, Math.round(riskRaw * 50)),
      );

      // ── LLM プロンプト ──
      const triggerSample = triggers.slice(0, 10).join(" / ") || "記録なし";
      const prompt =
        `あなたは認知行動療法(CBT)とACT(アクセプタンス&コミットメント)の専門家です。
ユーザーの「思考妨害 slip (誘惑に負けた記録)」を分析し、個別化された介入提案を提供してください。

[分析データ]
- 直近30日の slip 総数: ${last30d}件
- 直近7日の slip 数: ${last7d}件 (週次平均 ${weeklyAvg.toFixed(1)} に対して${
          riskRaw > 1.2 ? "増加傾向" : riskRaw < 0.8 ? "減少傾向" : "横ばい"
        })
- 最頻アイテム: ${topItems.map((x) => `${x.item_id}(${x.count}回)`).join(", ")}
- 最頻曜日: ${topWeekdays.map((x) => `${x.weekday}(${x.count}回)`).join(", ")}
- 最頻時間帯: ${topHours.map((x) => `${x.hour_range}(${x.count}回)`).join(", ")}
- トリガー記録サンプル: ${triggerSample}

出力ルール:
- CBT/ACT の具体技法 (認知再構成、If-Then プラン、値の明確化、脱フュージョン等) を必ず引用する
- 批判・説教ではなく、共感と具体的な次の一手を提示
- intervention_tips は 3〜5件の実行可能な行動レベルの提案 (各 60字以内)
- insights は 200〜300字の洞察文 (曜日・時間帯パターンに言及)
- 日本語で出力

出力フォーマット (JSONのみ):
{
  "insights": "洞察文",
  "intervention_tips": ["提案1", "提案2", "提案3"]
}`;

      const resultStr = await runPromptWithStrategy(prompt);
      const match = resultStr.match(/\{[\s\S]*\}/);
      let insights = resultStr.substring(0, 400);
      let intervention_tips: string[] = [];
      if (match) {
        try {
          const parsed = JSON.parse(match[0]);
          if (typeof parsed.insights === "string") {
            insights = parsed.insights;
          }
          if (Array.isArray(parsed.intervention_tips)) {
            intervention_tips = parsed.intervention_tips
              .filter((t: unknown): t is string =>
                typeof t === "string" && t.trim().length > 0
              )
              .slice(0, 5);
          }
        } catch { /* use raw */ }
      }

      return new Response(
        JSON.stringify({
          success: true,
          result: {
            total_slips: last30d,
            last_7d_slips: last7d,
            risk_score: riskScore,
            insights,
            intervention_tips,
            top_items: topItems,
            top_weekdays: topWeekdays,
            top_hours: topHours,
          },
        }),
        { headers: corsHeaders },
      );
    }

    if (action === "test_model") {
      const benchmarkPrompt = [
        "You are running a connectivity benchmark.",
        'Reply with the exact text "ping-ok" and nothing else.',
      ].join("\n");
      const startedAt = Date.now();
      const result = await runFallbackChain(benchmarkPrompt);
      const latency = Date.now() - startedAt;
      const normalized = result.trim();
      const passed = normalized === "ping-ok";
      const score = passed ? Math.max(60, 100 - Math.floor(latency / 100)) : 0;
      const benchmark = {
        score,
        latency,
        detail: passed
          ? `Smoke test passed in ${latency}ms`
          : `Unexpected response: ${normalized.slice(0, 120)}`,
        levels: [
          {
            level: "level1",
            description: "Connectivity smoke test",
            passed,
            score,
            maxPoints: 100,
            response: normalized,
            latency,
          },
        ],
      };

      if (!passed) {
        return new Response(
          JSON.stringify({
            success: false,
            error: `Model returned an unexpected benchmark response: ${
              normalized.slice(0, 120)
            }`,
            benchmark,
          }),
          { headers: corsHeaders, status: 400 },
        );
      }

      return new Response(
        JSON.stringify({ success: true, benchmark }),
        { headers: corsHeaders },
      );
    }

    // --- 3.5. generate (raw proxy — no prompt prefix, supports imageBase64) ---
    if (action === "generate") {
      const image = requestData.imageBase64
        ? {
          base64: requestData.imageBase64,
          mime: requestData.mimeType ?? "image/jpeg",
        }
        : undefined;
      const result = await runFallbackChain(requestContent ?? "", image);
      return new Response(JSON.stringify({ success: true, result }), {
        headers: corsHeaders,
      });
    }

    // --- 3.6. マイスキル管理 ---
    if (action === "save_skill") {
      const {
        skillName,
        skillDescription,
        promptTemplate,
        skillModel,
        skillTags,
      } = requestData;
      if (!skillName?.trim()) throw new Error("skillName is required");
      if (!promptTemplate?.trim()) {
        throw new Error("promptTemplate is required");
      }
      const { data, error: dbErr } = await supabaseClient
        .from("user_skills")
        .upsert({
          user_id: user.id,
          name: skillName.trim(),
          description: skillDescription?.trim() ?? null,
          prompt_template: promptTemplate.trim(),
          model: skillModel?.trim() ?? null,
          tags: skillTags ?? [],
        }, { onConflict: "user_id,name" })
        .select("id, name")
        .single();
      if (dbErr) throw new Error(dbErr.message);
      return new Response(JSON.stringify({ success: true, skill: data }), {
        headers: corsHeaders,
      });
    }

    if (action === "list_skills") {
      const { data, error: dbErr } = await supabaseClient
        .from("user_skills")
        .select(
          "id, name, description, prompt_template, model, tags, use_count, created_at",
        )
        .order("use_count", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(50);
      if (dbErr) throw new Error(dbErr.message);
      return new Response(
        JSON.stringify({ success: true, skills: data ?? [] }),
        { headers: corsHeaders },
      );
    }

    if (action === "delete_skill") {
      const { skillId } = requestData;
      if (!skillId) throw new Error("skillId is required");
      const { error: dbErr } = await supabaseClient
        .from("user_skills")
        .delete()
        .eq("id", skillId)
        .eq("user_id", user.id);
      if (dbErr) throw new Error(dbErr.message);
      return new Response(JSON.stringify({ success: true }), {
        headers: corsHeaders,
      });
    }

    if (action === "run_skill") {
      const { skillId } = requestData;
      if (!skillId) throw new Error("skillId is required");
      const { data: skill, error: fetchErr } = await supabaseClient
        .from("user_skills")
        .select("prompt_template, model, use_count")
        .eq("id", skillId)
        .eq("user_id", user.id)
        .single();
      if (fetchErr || !skill) throw new Error("Skill not found");
      // use_count をインクリメント (fire-and-forget)
      void Promise.resolve(
        supabaseClient
          .from("user_skills")
          .update({
            use_count: ((skill as { use_count?: number }).use_count ?? 0) + 1,
          })
          .eq("id", skillId),
      )
        .then(() => {/* ignore */})
        .catch(() => {/* ignore */});
      const prompt = requestContent
        ? `${skill.prompt_template}\n\nContent:\n${requestContent}`
        : skill.prompt_template;
      const result = await runPromptWithStrategy(prompt);
      return new Response(JSON.stringify({ success: true, result }), {
        headers: corsHeaders,
      });
    }

    // --- 4. Generic Actions ---
    if (
      [
        "improve",
        "summarize",
        "expand",
        "translate",
        "suggest_title",
        "custom_prompt",
      ].includes(action)
    ) {
      const normalizedStyleInstruction = requestData.styleInstruction?.trim();
      const targetLanguagePrompt =
        action === "translate" && requestData.targetLanguage?.trim()
          ? `\nTarget language: ${requestData.targetLanguage.trim()}`
          : "";
      const stylePrompt = normalizedStyleInstruction
        ? `\nStyle preset: ${
          requestData.styleName || "custom"
        }\nStyle instruction: ${normalizedStyleInstruction}\nFollow this style while completing the action.`
        : "";
      const prompt = action === "custom_prompt"
        ? `Action: custom_prompt${stylePrompt}${targetLanguagePrompt}\nSaved prompt:\n${
          requestContent ?? ""
        }`
        : `Action: ${action}${stylePrompt}${targetLanguagePrompt}\nContent: ${
          requestContent ?? ""
        }`;
      const result = await runPromptWithStrategy(prompt);
      return new Response(JSON.stringify({ success: true, result }), {
        headers: corsHeaders,
      });
    }

    // ===== 音声AIチャット: 長期記憶付き会話 =====
    if (action === "chat") {
      const userMessage = requestData.message ?? requestContent ?? "";
      if (!userMessage.trim()) {
        return new Response(
          JSON.stringify({ success: false, error: "message is required" }),
          { headers: corsHeaders, status: 400 },
        );
      }

      // サービスロールクライアント (RLS bypass で会話履歴を読み書き)
      const serviceClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      try {
        const result = await handleAiAssistantChat({
          store: createSupabaseAiAssistantChatStore(serviceClient),
          userId: user.id,
          message: userMessage,
          conversationId: requestData.conversationId,
          conversationContext: requestData.conversationContext,
          voiceUsed: requestData.voiceUsed,
          model: targetModel ?? DEFAULT_SYNTHESIS_MODEL,
          generateReply: runPromptWithStrategy,
        });
        return new Response(
          JSON.stringify({ success: true, ...result }),
          { headers: corsHeaders },
        );
      } catch (error) {
        if (error instanceof AiAssistantChatError) {
          return new Response(
            JSON.stringify({
              success: false,
              error: error.message,
              code: error.code,
            }),
            { headers: corsHeaders, status: error.status },
          );
        }
        throw error;
      }
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: `Action "${action}" not found`,
        validActions: [
          "get_models",
          "test_model",
          "generate",
          "analyze_photo_actions",
          "analyze_danshari_item",
          "hold_board_meeting",
          "my_struggle_column",
          "behavior_analysis",
          "improve",
          "summarize",
          "expand",
          "translate",
          "suggest_title",
          "custom_prompt",
          "assistant_video_reply",
          "save_skill",
          "list_skills",
          "delete_skill",
          "run_skill",
          "chat",
        ],
      }),
      { headers: corsHeaders, status: 404 },
    );
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);

    // Check for quota/rate limit errors
    const isQuotaError = /quota|rate limit/i.test(msg);
    const status = isQuotaError ? 429 : 400;

    return new Response(JSON.stringify({ success: false, error: msg }), {
      headers: corsHeaders,
      status,
    });
  }
});

function inferProvider(modelName: string): string {
  const normalized = modelName.toLowerCase().trim();
  if (normalized.startsWith("deepseek")) return "deepseek";
  if (normalized.startsWith("claude")) return "anthropic";
  if (normalized.startsWith("gemini") || normalized.startsWith("gemma")) {
    return "gemini";
  }
  if (normalized.startsWith("grok")) return "xai";
  if (normalized.startsWith("gpt") || normalized.startsWith("o")) {
    return "openai";
  }
  return "openai";
}

function normalizeMagiText(text: string | null | undefined): string | null {
  const normalized = text?.trim();
  if (!normalized) {
    return null;
  }
  if (normalized.length <= MAGI_OPINION_MAX_LENGTH) {
    return normalized;
  }
  return normalized.slice(0, MAGI_OPINION_MAX_LENGTH);
}

function buildMagiNodePrompt(
  originalPrompt: string,
  profile: MagiNodeProfile,
): string {
  return [
    `You are MAGI system node "${profile.nodeName}".`,
    `Viewpoint: ${profile.viewpoint}`,
    `Additional instruction: ${profile.instruction}`,
    "Preserve the user's requested output language and any explicit format constraints from the original prompt.",
    "",
    "[USER_PROMPT]",
    originalPrompt,
  ].join("\n");
}

function buildMagiSynthesisPrompt(
  originalPrompt: string,
  opinions: MagiOpinion[],
): string {
  const sections = opinions.flatMap((opinion) => [
    `[${opinion.nodeName} / ${opinion.viewpoint}]`,
    opinion.content,
    "",
  ]);

  return [
    "You are the MAGI synthesis node.",
    "Review the opinions from the other nodes, compare tradeoffs, and merge them into one final answer.",
    "Return exactly one JSON object with the merged recommendation and key reasoning.",
    "Keep the answer concise and do not use Markdown code fences.",
    "Preserve the original prompt language and any explicit format constraints.",
    "",
    "[ORIGINAL_PROMPT]",
    originalPrompt,
    "",
    ...sections,
  ].join("\n");
}

function resolveMagiNodeModel(
  profile: MagiNodeProfile,
  requestData: AIRequest,
): string {
  const requestedModel = requestData.model?.trim();
  const safeGeminiModel =
    requestedModel && inferProvider(requestedModel) === "gemini"
      ? requestedModel
      : DEFAULT_CASPER_MODEL;

  switch (profile.nodeName) {
    case "MELCHIOR":
      return requestData.melchiorModel?.trim() || DEFAULT_MELCHIOR_MODEL;
    case "BALTHASAR":
      return requestData.balthasarModel?.trim() || DEFAULT_BALTHASAR_MODEL;
    case "CASPER":
      return requestData.casperModel?.trim() || safeGeminiModel;
    default:
      return profile.defaultModel;
  }
}

function buildMagiSynthesisFighters(requestData: AIRequest): Fighter[] {
  const fighters: Fighter[] = [];
  const addedProviders = new Set<string>();

  const addFighter = (modelName: string | undefined) => {
    const normalized = modelName?.trim();
    if (!normalized) {
      return;
    }
    const provider = inferProvider(normalized);
    if (addedProviders.has(provider) || !isProviderAvailable(provider)) {
      return;
    }
    fighters.push({ provider, model: normalized });
    addedProviders.add(provider);
  };

  addFighter(requestData.synthesisModel || DEFAULT_SYNTHESIS_MODEL);
  addFighter(requestData.casperModel || DEFAULT_CASPER_MODEL);
  addFighter(requestData.melchiorModel || DEFAULT_MELCHIOR_MODEL);
  addFighter(requestData.balthasarModel || DEFAULT_BALTHASAR_MODEL);
  addFighter("deepseek-v4-flash");

  return fighters;
}

async function runMagiNode(params: {
  prompt: string;
  profile: MagiNodeProfile;
  requestData: AIRequest;
  image?: { base64: string; mime: string };
}): Promise<MagiOpinion | null> {
  const { prompt, profile, requestData, image } = params;
  const model = resolveMagiNodeModel(profile, requestData);
  const provider = inferProvider(model);
  if (!isProviderAvailable(provider)) {
    console.info(
      `MAGI node skipped: ${profile.nodeName} (${provider}, no API key)`,
    );
    return null;
  }

  try {
    const response = await callAI(
      { provider, model },
      KEYS,
      {
        ...requestData,
        content: buildMagiNodePrompt(prompt, profile),
        imageBase64: image?.base64,
        mimeType: image?.mime,
      },
    );
    const content = normalizeMagiText(response);
    if (!content) {
      return null;
    }
    return {
      nodeName: profile.nodeName,
      viewpoint: profile.viewpoint,
      content,
    };
  } catch (error) {
    console.error(`MAGI node failed: ${profile.nodeName}`, error);
    return null;
  }
}

async function runMagiBestEffort(params: {
  prompt: string;
  requestData: AIRequest;
  image?: { base64: string; mime: string };
}): Promise<string> {
  const { prompt, requestData, image } = params;
  let lastError: unknown;
  for (const fighter of buildMagiSynthesisFighters(requestData)) {
    try {
      const response = await callAI(
        fighter,
        KEYS,
        {
          ...requestData,
          content: prompt,
          imageBase64: image?.base64,
          mimeType: image?.mime,
        },
      );
      const normalized = normalizeMagiText(response);
      if (normalized) {
        return normalized;
      }
    } catch (error) {
      console.error(`MAGI synthesis fallback failed: ${fighter.model}`, error);
      lastError = error;
    }
  }
  if (lastError instanceof Error) {
    throw lastError;
  }
  throw new Error("MAGI synthesis fallback failed.");
}

async function runMagiChain(params: {
  prompt: string;
  requestData: AIRequest;
  image?: { base64: string; mime: string };
  fallback: (
    originalPrompt: string,
    image?: { base64: string; mime: string },
  ) => Promise<string>;
}): Promise<string> {
  const { prompt, requestData, image, fallback } = params;
  const opinions = (await Promise.all(
    MAGI_NODE_PROFILES.map((profile) =>
      runMagiNode({ prompt, profile, requestData, image })
    ),
  )).filter((opinion): opinion is MagiOpinion => opinion !== null);

  if (opinions.length === 0) {
    try {
      return await runMagiBestEffort({ prompt, requestData, image });
    } catch {
      return await fallback(prompt, image);
    }
  }

  if (opinions.length === 1) {
    return opinions[0].content;
  }

  const synthesisPrompt = buildMagiSynthesisPrompt(prompt, opinions);
  try {
    return await runMagiBestEffort({
      prompt: synthesisPrompt,
      requestData,
      image,
    });
  } catch {
    return opinions[0].content;
  }
}

// キーの型定義
type KeyMap = typeof KEYS;

async function callAI(
  fighter: Fighter,
  keys: KeyMap,
  data: AIRequest,
): Promise<string> {
  if (!isProviderAvailable(fighter.provider)) {
    throw new Error(`${fighter.provider} API key is not configured`);
  }
  if (fighter.provider === "gemini") {
    return await callGemini(fighter.model, keys.gemini!, data);
  }
  if (fighter.provider === "anthropic") {
    return await callAnthropic(fighter.model, keys.anthropic!, data);
  }
  if (fighter.provider === "deepseek") {
    return await callDeepSeek(fighter.model, keys.deepseek!, data);
  }
  return await callOpenAICompatible(fighter.model, keys.openai!, data, {
    providerLabel: "OpenAI",
    baseUrl: "https://api.openai.com/v1/chat/completions",
  });
}

// ---------------- Helper functions ----------------
// Removed unused 'provider' arg, typed arrays instead of any[]

function isProviderAvailable(providerName: string): boolean {
  switch (providerName.toLowerCase()) {
    case "google":
    case "gemini":
      return Boolean(KEYS.gemini);
    case "openai":
      return Boolean(KEYS.openai);
    case "anthropic":
      return Boolean(KEYS.anthropic);
    case "deepseek":
      return Boolean(KEYS.deepseek);
    case "xai":
    case "grok":
      return Boolean(KEYS.grok);
    case "hedra":
      return Boolean(KEYS.hedra);
    default:
      return false;
  }
}

// Windows版#94: 各 API キーの設定状況を返す (Flutter 側でバナー表示)
function getProviderStatus(): {
  configured: string[];
  missing: string[];
  total: number;
  details: Record<string, { env: string; configured: boolean }>;
} {
  const details = {
    google: { env: "GEMINI_API_KEY", configured: Boolean(KEYS.gemini) },
    openai: { env: "OPENAI_API_KEY", configured: Boolean(KEYS.openai) },
    anthropic: {
      env: "ANTHROPIC_API_KEY",
      configured: Boolean(KEYS.anthropic),
    },
    deepseek: { env: "DEEPSEEK_API_KEY", configured: Boolean(KEYS.deepseek) },
    xai: { env: "XAI_API_KEY", configured: Boolean(KEYS.grok) },
    hedra: { env: "HEDRA_API_KEY", configured: Boolean(KEYS.hedra) },
  };
  const configured = Object.entries(details)
    .filter(([_, v]) => v.configured)
    .map(([k]) => k);
  const missing = Object.entries(details)
    .filter(([_, v]) => !v.configured)
    .map(([k]) => k);
  return { configured, missing, total: Object.keys(details).length, details };
}

function buildAssistantVideoPrompt(userMessage: string): string {
  return `${AI_CHARACTER_PREAMBLE}

ユーザーの依頼に対して、アバター動画がそのまま読み上げられる短い返答原稿を作成してください。

必須ルール:
- 出力は日本語の話し言葉
- 2〜4文で簡潔にまとめる
- 箇条書き、絵文字、見出し、Markdown を使わない
- 「こんにちは」などの短い導入は可
- 動画向けなので一文を長くしすぎない
- 根拠のない断定や誇張を避ける

ユーザー依頼:
${userMessage}
`.trim();
}

function firstNonEmptyString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function isHedraCreditError(
  status: number | undefined,
  message: string,
): boolean {
  if (status === 402) return true;
  return /credit|billing|balance|payment|required top.?up|insufficient|quota|out of credits|not enough/i
    .test(message);
}

function buildHedraCreditErrorMessage(status: number, message: string): string {
  return [
    "Hedra API credits are insufficient.",
    `status=${status}`,
    `detail=${message}`,
    "Open /quota-dashboard to check remaining credits and replenish before retrying video generation.",
  ].join(" ");
}

function buildHedraAvatarImage(data: AIRequest): string | null {
  const avatarImageUrl = data.avatarImageUrl?.trim();
  if (avatarImageUrl) return avatarImageUrl;
  const base64 = data.imageBase64?.trim();
  if (!base64) return null;
  const mimeType = data.mimeType?.trim() || "image/jpeg";
  return `data:${mimeType};base64,${base64}`;
}

function normalizeHedraVideoResponse(payload: unknown): {
  id: string | null;
  status: string;
  videoUrl: string | null;
  previewUrl: string | null;
  downloadUrl: string | null;
} {
  const data = payload as Record<string, unknown> | null;
  const id = firstNonEmptyString(
    data?.id,
    data?.video_id,
    (data?.video as Record<string, unknown> | null)?.id,
    (data?.job as Record<string, unknown> | null)?.id,
  );
  const videoUrl = firstNonEmptyString(
    data?.url,
    data?.video_url,
    data?.download_url,
    (data?.result as Record<string, unknown> | null)?.url,
    (data?.video as Record<string, unknown> | null)?.url,
    (data?.video as Record<string, unknown> | null)?.download_url,
    (data?.asset as Record<string, unknown> | null)?.url,
  );
  const previewUrl = firstNonEmptyString(
    data?.preview_url,
    (data?.video as Record<string, unknown> | null)?.preview_url,
    (data?.asset as Record<string, unknown> | null)?.preview_url,
  );
  const downloadUrl = firstNonEmptyString(
    data?.download_url,
    (data?.video as Record<string, unknown> | null)?.download_url,
    videoUrl,
  );
  const status = firstNonEmptyString(
    data?.status,
    data?.state,
    (data?.job as Record<string, unknown> | null)?.status,
    (data?.video as Record<string, unknown> | null)?.status,
  ) ?? (videoUrl ? "completed" : "submitted");

  return {
    id,
    status,
    videoUrl,
    previewUrl,
    downloadUrl,
  };
}

async function createHedraVideo(
  data: AIRequest,
  script: string,
): Promise<{
  id: string | null;
  status: string;
  videoUrl: string | null;
  previewUrl: string | null;
  downloadUrl: string | null;
}> {
  const avatarImage = buildHedraAvatarImage(data);
  const body: Record<string, unknown> = {
    text: script,
    voice: data.voice?.trim() || "ja-JP",
  };
  if (avatarImage) body.avatarImage = avatarImage;
  if (data.title?.trim()) body.title = data.title.trim();

  const response = await fetch(
    "https://mercury.dev.dream-ai.com/api/v1/characters",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-KEY": KEYS.hedra!,
      },
      body: JSON.stringify(body),
    },
  );

  const rawText = await response.text();
  let parsed: unknown = {};
  if (rawText.trim().length > 0) {
    try {
      parsed = JSON.parse(rawText);
    } catch {
      parsed = { raw: rawText };
    }
  }

  if (!response.ok) {
    const message = firstNonEmptyString(
      (parsed as Record<string, unknown> | null)?.error,
      (parsed as Record<string, unknown> | null)?.message,
      rawText,
    ) ?? `Hedra request failed with status ${response.status}`;
    if (isHedraCreditError(response.status, message)) {
      throw new Error(buildHedraCreditErrorMessage(response.status, message));
    }
    throw new Error(message);
  }

  return normalizeHedraVideoResponse(parsed);
}

async function callOpenAICompatible(
  model: string,
  apiKey: string,
  data: AIRequest,
  options: { providerLabel: string; baseUrl: string },
): Promise<string> {
  const messages: Array<
    { role: string; content: string | Array<Record<string, unknown>> }
  > = [{ role: "user", content: data.content || "" }];
  if (data.imageBase64) {
    messages[0].content = [
      { type: "text", text: data.content || "" },
      {
        type: "image_url",
        image_url: { url: `data:${data.mimeType};base64,${data.imageBase64}` },
      },
    ];
  }
  const resp = await fetch(options.baseUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model, messages, max_tokens: 1024 }),
  });
  const json = await resp.json();
  if (!resp.ok) {
    throw new Error(
      `${options.providerLabel}: ${json.error?.message || "Unknown error"}`,
    );
  }
  return json.choices[0].message.content;
}

async function callDeepSeek(
  model: string,
  apiKey: string,
  data: AIRequest,
): Promise<string> {
  return await callOpenAICompatible(model, apiKey, data, {
    providerLabel: "DeepSeek",
    baseUrl: "https://api.deepseek.com/chat/completions",
  });
}

async function callAnthropic(
  model: string,
  apiKey: string,
  data: AIRequest,
): Promise<string> {
  const content: Array<Record<string, unknown>> = [{
    type: "text",
    text: data.content || "",
  }];
  if (data.imageBase64) {
    content.unshift({
      type: "image",
      source: {
        type: "base64",
        media_type: data.mimeType || "image/jpeg",
        data: data.imageBase64,
      },
    });
  }
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      messages: [{ role: "user", content }],
    }),
  });
  const json = await resp.json();
  if (!resp.ok) {
    throw new Error(`Anthropic: ${json.error?.message || "Unknown error"}`);
  }
  return json.content[0].text;
}

async function callGemini(
  model: string,
  apiKey: string,
  data: AIRequest,
): Promise<string> {
  const parts: Array<Record<string, unknown>> = [{ text: data.content || "" }];
  if (data.imageBase64) {
    parts.push({
      inline_data: {
        mime_type: data.mimeType || "image/jpeg",
        data: data.imageBase64,
      },
    });
  }
  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts }] }),
    },
  );
  const json = await resp.json();
  if (!resp.ok) {
    throw new Error(`Gemini: ${json.error?.message || "Unknown error"}`);
  }
  return json.candidates[0].content.parts[0].text;
}
