// プロバイダーごとの出力トークン (max_tokens / maxOutputTokens / thinking budget)
// 適用ロジック。index.ts の serve 副作用を避けて単体テストできるよう分離している。

// Gemini の thinking トークンは maxOutputTokens を本文と共有して消費するため、
// 上限を設けないと thinking が枠を食い切り、本文出力前に MAX_TOKENS で途中終了する
// (細木数子風の長文資産要約で実際に発生し provider フォールバックが多発した)。
// 本文用にこのトークン数を確保し、残りを thinkingBudget で上限化する。
export const GEMINI_OUTPUT_TOKEN_RESERVE = 8000;

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
    // 呼び出し側が thinkingConfig を明示していない & 本文確保枠より大きい予算のときだけ
    // thinking を上限化する。残り (maxTokens - reserve) を thinking に割り当て、
    // 本文用に最低 GEMINI_OUTPUT_TOKEN_RESERVE を必ず残す。
    if (
      generationConfig.thinkingConfig == null &&
      maxTokens > GEMINI_OUTPUT_TOKEN_RESERVE
    ) {
      nextGenerationConfig.thinkingConfig = {
        thinkingBudget: maxTokens - GEMINI_OUTPUT_TOKEN_RESERVE,
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
