export const DEFAULT_GEMINI_JSON_MODEL = "gemini-2.5-flash";
export const DEFAULT_OPENAI_JSON_MODEL = "gpt-4o-mini";

type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

function shouldDisableGeminiThinking(model: string): boolean {
  return /^gemini-2\.5-flash(?:-\d+)?$/i.test(model.trim());
}

function parseJsonObject(raw: string): Record<string, unknown> | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const unfenced = trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
  const firstBrace = unfenced.indexOf("{");
  const lastBrace = unfenced.lastIndexOf("}");
  const jsonText = firstBrace >= 0 && lastBrace > firstBrace
    ? unfenced.slice(firstBrace, lastBrace + 1)
    : unfenced;

  try {
    const parsed: unknown = JSON.parse(jsonText);
    if (
      parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)
    ) {
      return parsed as Record<string, unknown>;
    }
    return null;
  } catch {
    return null;
  }
}

export async function generateJsonWithGeminiFirst(args: {
  systemPrompt: string;
  userPrompt: string;
  geminiApiKey?: string;
  openAiApiKey?: string;
  geminiModel?: string;
  openAiModel?: string;
  temperature?: number;
  maxOutputTokens?: number;
  timeoutMs?: number;
  fetchImpl?: FetchLike;
}): Promise<Record<string, unknown> | null> {
  const fetchImpl = args.fetchImpl ?? fetch;
  const geminiKey = args.geminiApiKey?.trim() ?? "";
  const openAiKey = args.openAiApiKey?.trim() ?? "";
  const geminiModel = args.geminiModel?.trim() || DEFAULT_GEMINI_JSON_MODEL;
  const openAiModel = args.openAiModel?.trim() || DEFAULT_OPENAI_JSON_MODEL;
  const temperature = args.temperature ?? 0.2;
  const maxOutputTokens = args.maxOutputTokens ?? 1024;
  const timeoutMs = args.timeoutMs ?? 12_000;

  if (geminiKey) {
    try {
      const endpoint =
        `https://generativelanguage.googleapis.com/v1beta/models/${
          encodeURIComponent(geminiModel)
        }:generateContent`;
      const generationConfig: Record<string, unknown> = {
        temperature,
        maxOutputTokens,
        responseMimeType: "application/json",
      };
      if (shouldDisableGeminiThinking(geminiModel)) {
        generationConfig.thinkingConfig = { thinkingBudget: 0 };
      }
      const response = await fetchImpl(endpoint, {
        method: "POST",
        headers: {
          "x-goog-api-key": geminiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: args.systemPrompt }],
          },
          contents: [
            {
              role: "user",
              parts: [{ text: args.userPrompt }],
            },
          ],
          generationConfig,
        }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.ok) {
        const data = await response.json() as {
          candidates?: Array<{
            content?: { parts?: Array<{ text?: unknown; thought?: unknown }> };
          }>;
        };
        const rawText = (data.candidates?.[0]?.content?.parts ?? [])
          .filter((part) => part?.thought !== true)
          .map((part) => String(part?.text ?? ""))
          .join("");
        const parsed = parseJsonObject(rawText);
        if (parsed) return parsed;
      }
    } catch {
      // Fall through to OpenAI fallback.
    }
  }

  if (openAiKey) {
    try {
      const response = await fetchImpl(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openAiKey}`,
          },
          body: JSON.stringify({
            model: openAiModel,
            temperature,
            max_tokens: maxOutputTokens,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: args.systemPrompt },
              { role: "user", content: args.userPrompt },
            ],
          }),
          signal: AbortSignal.timeout(timeoutMs),
        },
      );
      if (response.ok) {
        const data = await response.json() as {
          choices?: Array<{ message?: { content?: unknown } }>;
        };
        const content = String(data.choices?.[0]?.message?.content ?? "");
        const parsed = parseJsonObject(content);
        if (parsed) return parsed;
      }
    } catch {
      // Return null so callers can degrade to static fallback.
    }
  }

  return null;
}
