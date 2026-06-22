// プロバイダーごとの出力トークン (max_tokens / maxOutputTokens / thinking budget)
// 適用ロジック。index.ts の serve 副作用を避けて単体テストできるよう分離している。

// Gemini の thinking トークンは maxOutputTokens を本文と共有して消費するため、
// 上限を設けないと thinking が枠を食い切り、本文出力前に MAX_TOKENS で途中終了する
// (細木数子風の長文資産要約で実際に発生し provider フォールバックが多発した)。
// 本文用にこのトークン数を確保し、残りを thinkingBudget で上限化する。
export const GEMINI_OUTPUT_TOKEN_RESERVE = 8000;

// gemini-2.5-flash / flash-lite が受け付ける thinkingBudget の範囲。
// 呼び出し側の maxTokens は index.ts の normalizeMaxTokens で 8192 上限に
// クランプされるため、旧実装の (maxTokens - 8000) は本番で常に 192 となり、
// Gemini の下限 512 を下回って 400 INVALID_ARGUMENT
// ("thinking budget 192 is invalid. choose 512-24576") を返していた。
// 算出値をこの範囲にクランプして回避する。
export const GEMINI_MIN_THINKING_BUDGET = 512;
export const GEMINI_MAX_THINKING_BUDGET = 24576;

export function applyProviderGenerationOptions(
  providerId: string,
  requestBody: Record<string, unknown>,
  options?: { maxTokens?: number },
): Record<string, unknown> {
  const maxTokens = options?.maxTokens;

  if (providerId === "openai") {
    // OpenAI の新世代モデル (gpt-5 / o系) は max_tokens パラメータ自体を
    // 拒否するため、ベース body (OPENAI_COMPAT_BODY) の max_tokens: 512 を
    // 取り除いた上で max_completion_tokens へ載せ替える。
    // groq / deepinfra 等の OpenAI 互換プロバイダーは従来どおり max_tokens。
    const body: Record<string, unknown> = { ...requestBody };
    const legacyMaxTokens = body.max_tokens;
    delete body.max_tokens;
    const model = String(body.model ?? "");
    if (model.startsWith("gpt-5") || /^o\d/.test(model)) {
      // reasoning モデルは温度指定を拒否する (既定値のみ許容)。
      delete body.temperature;
      // reasoning_effort を下げないと、推論トークンが max_completion_tokens を
      // 使い切り本文が 0 トークンになる (gpt-5 が text:"" を返す原因)。
      // 金額計算は Dart 側で完了済みなので低 effort で十分。
      if (body.reasoning_effort == null) {
        body.reasoning_effort = "low";
      }
    }
    const budget = maxTokens ??
      (typeof legacyMaxTokens === "number" ? legacyMaxTokens : undefined);
    if (budget != null) {
      body.max_completion_tokens = budget;
    }
    return body;
  }

  if (!maxTokens) return requestBody;

  if (providerId === "google" || providerId === "google_flash_lite") {
    const generationConfig = requestBody.generationConfig &&
        typeof requestBody.generationConfig === "object"
      ? requestBody.generationConfig as Record<string, unknown>
      : {};
    const nextGenerationConfig: Record<string, unknown> = {
      ...generationConfig,
      maxOutputTokens: maxTokens,
    };
    // 呼び出し側が thinkingConfig を明示していないときだけ thinking を上限化する。
    // 本文用に GEMINI_OUTPUT_TOKEN_RESERVE を確保した残りを thinking に割り当てるが、
    // Gemini が許容する [GEMINI_MIN_THINKING_BUDGET, GEMINI_MAX_THINKING_BUDGET] に
    // クランプする。maxTokens は 8192 上限のため実際は下限 512 になり、本文に 7680
    // 以上を残しつつ 400 (192 invalid) を回避する。maxTokens が下限以下の極小
    // リクエストでは thinking を設定せず Gemini 既定に委ねる。
    if (
      generationConfig.thinkingConfig == null &&
      maxTokens > GEMINI_MIN_THINKING_BUDGET
    ) {
      const desiredBudget = maxTokens - GEMINI_OUTPUT_TOKEN_RESERVE;
      nextGenerationConfig.thinkingConfig = {
        thinkingBudget: Math.min(
          GEMINI_MAX_THINKING_BUDGET,
          Math.max(GEMINI_MIN_THINKING_BUDGET, desiredBudget),
        ),
      };
    }
    return {
      ...requestBody,
      generationConfig: nextGenerationConfig,
    };
  }

  return {
    ...requestBody,
    max_tokens: maxTokens,
  };
}
