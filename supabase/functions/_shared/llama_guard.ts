// Llama Guard 4 入出力安全フィルタ
// ベンダーダイジェスト 2026-07-05 採用 #3 (Meta LlamaFirewall / Llama Guard 4)。
//
// - Groq API (既存 GROQ_API_KEY を流用) 経由で Llama Guard 4 を呼び、
//   ユーザー入力 / AI 出力の安全性を分類する。
// - LLAMA_GUARD_ENABLED=1 のときのみ有効 (段階的ロールアウト / 評価フェーズ)。
//   未設定時は checked:false で素通しし、既存動作を一切変えない。
// - Guard API 障害時は fail-open (可用性優先)。判定不能は error に残す。
// - docs/AI_DEV_PRINCIPLES.md §deny-by-default: 本番の有効化判断は
//   scripts/llama_guard_eval.py での false-positive 率評価後に行う。

const GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_GUARD_MODEL = "meta-llama/llama-guard-4-12b";
const GUARD_TIMEOUT_MS = 5_000;
const GUARD_INPUT_MAX_CHARS = 8_000;

export interface LlamaGuardVerdict {
  /** LLAMA_GUARD_ENABLED=1 かつ GROQ_API_KEY 設定済みか */
  enabled: boolean;
  /** Guard API の判定が実際に得られたか (障害時 false = fail-open) */
  checked: boolean;
  /** 安全と判定されたか (未チェック時は true = fail-open) */
  safe: boolean;
  /** unsafe 時の MLCommons hazard categories (例: ["S1","S9"]) */
  categories: string[];
  error?: string;
}

const PASS_VERDICT: LlamaGuardVerdict = {
  enabled: false,
  checked: false,
  safe: true,
  categories: [],
};

export function llamaGuardEnabled(): boolean {
  try {
    return Deno.env.get("LLAMA_GUARD_ENABLED") === "1" &&
      Boolean(Deno.env.get("GROQ_API_KEY"));
  } catch {
    return false;
  }
}

/** Llama Guard の生出力 ("safe" | "unsafe\nS1,S2") をパースする */
export function parseLlamaGuardOutput(
  raw: string,
): { safe: boolean; categories: string[] } {
  const lines = raw.trim().split("\n").map((line) => line.trim())
    .filter(Boolean);
  const verdict = (lines[0] ?? "").toLowerCase();
  if (verdict === "safe") return { safe: true, categories: [] };
  if (verdict === "unsafe") {
    const categories = (lines[1] ?? "")
      .split(",")
      .map((c) => c.trim().toUpperCase())
      .filter((c) => /^S\d{1,2}$/.test(c));
    return { safe: false, categories };
  }
  // 想定外フォーマットは unsafe 扱いにしない (fail-open) —
  // caller 側で checked:true / categories 空として観測される
  return { safe: true, categories: [] };
}

/**
 * ユーザー入力または AI 出力を Llama Guard 4 で分類する。
 * role: "user" = 入力フィルタ / "assistant" = 出力フィルタ。
 */
export async function checkContentSafety(
  text: string,
  role: "user" | "assistant" = "user",
): Promise<LlamaGuardVerdict> {
  if (!llamaGuardEnabled()) return PASS_VERDICT;
  const content = text.slice(0, GUARD_INPUT_MAX_CHARS).trim();
  if (!content) return { ...PASS_VERDICT, enabled: true };

  const apiKey = Deno.env.get("GROQ_API_KEY") ?? "";
  const model = Deno.env.get("LLAMA_GUARD_MODEL") || DEFAULT_GUARD_MODEL;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GUARD_TIMEOUT_MS);
  try {
    const resp = await fetch(GROQ_CHAT_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: 32,
        temperature: 0,
        messages: [{ role, content }],
      }),
      signal: controller.signal,
    });
    const data = await resp.json().catch(() => null) as
      | Record<string, unknown>
      | null;
    if (!resp.ok || !data) {
      return {
        enabled: true,
        checked: false,
        safe: true,
        categories: [],
        error: `llama-guard http ${resp.status}`,
      };
    }
    const raw = String(
      (data.choices as Array<{ message?: { content?: string } }>)?.[0]
        ?.message?.content ?? "",
    );
    const { safe, categories } = parseLlamaGuardOutput(raw);
    return { enabled: true, checked: true, safe, categories };
  } catch (error) {
    return {
      enabled: true,
      checked: false,
      safe: true,
      categories: [],
      error: error instanceof Error ? error.message : String(error),
    };
  } finally {
    clearTimeout(timeoutId);
  }
}
