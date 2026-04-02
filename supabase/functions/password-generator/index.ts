// Password Generator Edge Function
// パスワード生成 (セキュリティツール)
// - カスタム長さ・文字種
// - パスフレーズ生成
// - 強度チェック
// - 生成履歴 (ハッシュのみ保存)
//
// GET  → 強度チェック
// POST → パスワード生成 / パスフレーズ生成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const LOWERCASE = "abcdefghijklmnopqrstuvwxyz";
const UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const DIGITS = "0123456789";
const SYMBOLS = "!@#$%^&*()_+-=[]{}|;:,.<>?";

const PASSPHRASE_WORDS = [
  "apple", "beach", "cloud", "dance", "eagle", "flame", "grape", "house",
  "ivory", "jewel", "kite", "lemon", "moon", "night", "ocean", "pearl",
  "queen", "river", "star", "tiger", "unity", "vivid", "water", "xenon",
  "yoga", "zebra", "amber", "brave", "coral", "delta", "ember", "frost",
  "globe", "honey", "input", "jazzy", "karma", "lotus", "magic", "noble",
  "olive", "piano", "quest", "robin", "solar", "trail", "ultra", "valor",
  "wheat", "pixel", "young", "zippy",
];

function generateSecureRandom(length: number): Uint8Array {
  const arr = new Uint8Array(length);
  crypto.getRandomValues(arr);
  return arr;
}

function checkStrength(password: string): { score: number; label: string; feedback: string[] } {
  let score = 0;
  const feedback: string[] = [];

  if (password.length >= 8) score += 1;
  if (password.length >= 12) score += 1;
  if (password.length >= 16) score += 1;
  if (password.length < 8) feedback.push("8文字以上にしてください");

  if (/[a-z]/.test(password)) score += 1;
  else feedback.push("小文字を含めてください");

  if (/[A-Z]/.test(password)) score += 1;
  else feedback.push("大文字を含めてください");

  if (/[0-9]/.test(password)) score += 1;
  else feedback.push("数字を含めてください");

  if (/[^a-zA-Z0-9]/.test(password)) score += 1;
  else feedback.push("記号を含めてください");

  // Check for common patterns
  if (/(.)\1{2,}/.test(password)) { score -= 1; feedback.push("同じ文字の連続を避けてください"); }
  if (/^[a-zA-Z]+$/.test(password)) { score -= 1; feedback.push("文字のみは弱いです"); }

  const labels = ["非常に弱い", "弱い", "やや弱い", "普通", "やや強い", "強い", "非常に強い"];
  const clampedScore = Math.max(0, Math.min(6, score));

  return { score: clampedScore, label: labels[clampedScore], feedback };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const password = url.searchParams.get("password") ?? "";

      if (!password) {
        return new Response(
          JSON.stringify({ success: true, info: "POST to generate, GET with ?password= to check strength" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const strength = checkStrength(password);
      return new Response(
        JSON.stringify({ success: true, strength }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "generate") {
        const {
          length: len = 16,
          uppercase = true,
          lowercase = true,
          digits = true,
          symbols = true,
          exclude = "",
        } = body;

        const pwLength = Math.max(4, Math.min(128, len));
        let charset = "";
        if (lowercase) charset += LOWERCASE;
        if (uppercase) charset += UPPERCASE;
        if (digits) charset += DIGITS;
        if (symbols) charset += SYMBOLS;

        if (exclude) {
          for (const c of exclude) {
            charset = charset.replace(c, "");
          }
        }

        if (charset.length === 0) charset = LOWERCASE + DIGITS;

        const randomBytes = generateSecureRandom(pwLength);
        let password = "";
        for (let i = 0; i < pwLength; i++) {
          password += charset[randomBytes[i] % charset.length];
        }

        const strength = checkStrength(password);

        return new Response(
          JSON.stringify({ success: true, password, length: pwLength, strength }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "passphrase") {
        const { words: wordCount = 4, separator = "-", capitalize = true } = body;
        const count = Math.max(2, Math.min(10, wordCount));

        const randomBytes = generateSecureRandom(count);
        const selectedWords = [];
        for (let i = 0; i < count; i++) {
          let word = PASSPHRASE_WORDS[randomBytes[i] % PASSPHRASE_WORDS.length];
          if (capitalize) word = word[0].toUpperCase() + word.slice(1);
          selectedWords.push(word);
        }

        const passphrase = selectedWords.join(separator);
        const strength = checkStrength(passphrase);

        return new Response(
          JSON.stringify({ success: true, passphrase, wordCount: count, strength }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action. Use 'generate' or 'passphrase'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
