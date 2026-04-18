// tools-hub — 個人生産性ツール統合EF
// Merges (30 EFs): password-generator, password-vault, currency-converter,
//   weather-widget, qr-code-generator, markdown-renderer, pomodoro-timer,
//   focus-timer, clipboard-history, quick-note, goal-tracker, contact-manager,
//   reading-list, bookmark-manager, bookmark-sync, tag-manager, template-library,
//   address-book, emergency-contacts, news-rss-aggregator, changelog-manager,
//   multi-language, habit-tracker, habit-gamification, virtual-pet, poll-survey,
//   form-builder, note-sharing-enhanced, content-versioning, mindmap-diagram
//
// GET/POST ?action=<action> or body { action: "..." }
// All data stored in hub_data table (source column = feature name)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

// Generic CRUD on hub_data by source
async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

// ===== Horse Racing Multi-Provider Ensemble (Windows版#94) =====
// Quota/failure 時に自動 fallback + 複数プロバイダーで1レースの予想を蓄積
// して精度を向上させる。shared chat 基盤 (ai-hub) と独立させているのは
// horse racing 固有のプロンプト・JSON schema・コスト追跡が混ざらないため。

type HorseProviderConfig = {
  provider: string;
  model: string;
  apiKeyEnv: string;
  estimatedCostUsd: number;
};

const HORSE_PROVIDER_CHAIN: HorseProviderConfig[] = [
  { provider: "google", model: "gemini-2.5-flash", apiKeyEnv: "GEMINI_API_KEY", estimatedCostUsd: 0.0005 },
  { provider: "openai", model: "gpt-4o-mini", apiKeyEnv: "OPENAI_API_KEY", estimatedCostUsd: 0.002 },
  { provider: "anthropic", model: "claude-haiku-4-5", apiKeyEnv: "ANTHROPIC_API_KEY", estimatedCostUsd: 0.003 },
  { provider: "xai", model: "grok-4-1-fast-non-reasoning", apiKeyEnv: "XAI_API_KEY", estimatedCostUsd: 0.002 },
];

type ProviderPredictionResult = {
  success: boolean;
  prediction?: {
    first: string;
    second: string;
    third: string;
    confidence: number;
    reasoning: string;
  };
  error?: {
    http_status?: number;
    reason: string;
    detail?: string;
    is_quota: boolean;
  };
  latency_ms: number;
};

function buildHorseRacePrompt(race: Record<string, unknown>, entries: Record<string, unknown>[]): string {
  const entryText = entries.map((e) =>
    `馬番${e.horse_number} ${e.horse_name} (騎手:${e.jockey ?? "不明"}, 単勝${e.win_odds ?? "?"}倍, ${e.popularity ?? "?"}番人気)`
  ).join("\n");
  return `競馬レース「${race.race_name}」(${race.venue ?? ""}/${race.course_type ?? "芝"}${race.distance ?? ""}m/${race.grade ?? ""}) の3連単予想をしてください。\n出走馬:\n${entryText}\n\nJSON形式のみで回答 (前後に説明文を入れない): {"first":"予想馬名1","second":"予想馬名2","third":"予想馬名3","confidence":0.0,"reasoning":"根拠"}`;
}

async function callProviderForHorsePrediction(
  cfg: HorseProviderConfig,
  prompt: string,
): Promise<ProviderPredictionResult> {
  const apiKey = Deno.env.get(cfg.apiKeyEnv) ?? "";
  if (!apiKey) {
    return {
      success: false,
      error: { reason: `${cfg.apiKeyEnv} not configured`, is_quota: false },
      latency_ms: 0,
    };
  }
  const startMs = Date.now();
  try {
    let res: Response;
    let rawText = "";

    if (cfg.provider === "google") {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cfg.model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
        },
      );
      if (res.ok) {
        const data = await res.json() as { candidates?: Array<{ content: { parts: Array<{ text: string }> } }> };
        rawText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      }
    } else if (cfg.provider === "openai" || cfg.provider === "xai") {
      const url = cfg.provider === "openai"
        ? "https://api.openai.com/v1/chat/completions"
        : "https://api.x.ai/v1/chat/completions";
      res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: cfg.model,
          messages: [
            { role: "system", content: "あなたは競馬予想AIです。必ずJSONのみで回答してください。" },
            { role: "user", content: prompt },
          ],
          temperature: 0.3,
          response_format: { type: "json_object" },
        }),
      });
      if (res.ok) {
        const data = await res.json() as { choices?: Array<{ message: { content: string } }> };
        rawText = data.choices?.[0]?.message?.content ?? "";
      }
    } else if (cfg.provider === "anthropic") {
      res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: cfg.model,
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });
      if (res.ok) {
        const data = await res.json() as { content?: Array<{ text: string }> };
        rawText = data.content?.[0]?.text ?? "";
      }
    } else {
      return {
        success: false,
        error: { reason: `unknown provider: ${cfg.provider}`, is_quota: false },
        latency_ms: Date.now() - startMs,
      };
    }

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      const isQuota = res.status === 429 ||
        /quota|rate.?limit|RESOURCE_EXHAUSTED|insufficient_quota/i.test(errText);
      return {
        success: false,
        error: {
          http_status: res.status,
          reason: `${cfg.provider} HTTP ${res.status}`,
          detail: errText.slice(0, 200),
          is_quota: isQuota,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    let pred: Record<string, unknown>;
    try {
      pred = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim());
    } catch (parseErr) {
      return {
        success: false,
        error: {
          reason: `JSON.parse failed: ${parseErr}`,
          detail: rawText.slice(0, 200),
          is_quota: false,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    return {
      success: true,
      prediction: {
        first: String(pred.first ?? ""),
        second: String(pred.second ?? ""),
        third: String(pred.third ?? ""),
        confidence: Number(pred.confidence ?? 0.5),
        reasoning: String(pred.reasoning ?? ""),
      },
      latency_ms: Date.now() - startMs,
    };
  } catch (err) {
    return {
      success: false,
      error: { reason: `exception: ${String(err).slice(0, 200)}`, is_quota: false },
      latency_ms: Date.now() - startMs,
    };
  }
}

async function persistEnsemblePrediction(
  admin: SupabaseClient,
  raceId: string,
  cfg: HorseProviderConfig,
  result: ProviderPredictionResult,
): Promise<void> {
  if (!result.success || !result.prediction) return;
  await admin.from("horse_race_predictions_ensemble").upsert({
    race_id: raceId,
    provider: cfg.provider,
    model: cfg.model,
    first_pick: result.prediction.first,
    second_pick: result.prediction.second,
    third_pick: result.prediction.third,
    confidence: result.prediction.confidence,
    reasoning: result.prediction.reasoning,
    prediction_json: result.prediction,
    estimated_cost_usd: cfg.estimatedCostUsd,
    latency_ms: result.latency_ms,
  }, { onConflict: "race_id,provider,model" });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ?? "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Stateless utilities (no auth needed) ────────────────────────────────
    if (action === "generate_password") {
      const length = Number(body.length ?? 16);
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-_";
      const arr = new Uint8Array(length);
      crypto.getRandomValues(arr);
      const password = Array.from(arr, (b) => chars[b % chars.length]).join("");
      return json({ success: true, password });
    }

    if (action === "generate_qr") {
      const text = String(body.text ?? "");
      const size = Number(body.size ?? 200);
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
      return json({ success: true, qr_url: qrUrl, text });
    }

    if (action === "convert_currency") {
      const from = String(body.from ?? "USD").toUpperCase();
      const to = String(body.to ?? "JPY").toUpperCase();
      const amount = Number(body.amount ?? 1);
      const res = await fetch(`https://open.er-api.com/v6/latest/${from}`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Exchange rate API unavailable" }, 502);
      const rates = (await res.json() as { rates: Record<string, number> }).rates;
      const rate = rates[to];
      if (!rate) return json({ error: `Unknown currency: ${to}` }, 400);
      return json({ success: true, from, to, amount, rate, result: amount * rate });
    }

    if (action === "get_weather") {
      const city = String(body.city ?? "Tokyo");
      const res = await fetch(`https://wttr.in/${encodeURIComponent(city)}?format=j1`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Weather API unavailable" }, 502);
      const data = await res.json() as Record<string, unknown>;
      return json({ success: true, city, weather: data });
    }

    if (action === "render_markdown") {
      // Client-side rendering preferred; return raw markdown with metadata
      const markdown = String(body.markdown ?? "");
      return json({ success: true, markdown, length: markdown.length });
    }

    if (action === "translate") {
      const text = String(body.text ?? "");
      const target = String(body.target ?? "ja");
      const source = String(body.source ?? "auto");
      const res = await fetch(
        `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${source}|${target}`
      ).catch(() => null);
      if (!res || !res.ok) return json({ error: "Translation API unavailable" }, 502);
      const result = await res.json() as { responseData?: { translatedText?: string } };
      return json({ success: true, original: text, translated: result.responseData?.translatedText ?? text, target });
    }

    // ── Horse Racing 自動化パイプライン (auth不要 — GitHub Actions対応) ─────────
    if (action.startsWith("horseracing.")) {
      switch (action) {
        case "horseracing.today": {
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const type = String(body.type ?? "all");
          
          let query = admin
            .from("horse_races")
            .select("*, horse_entries(*), horse_predictions(*), horse_results(*)")
            .eq("race_date", targetDate);
            
          if (type === "jra") query = query.eq("source", "jra");
          else if (type === "nar") query = query.eq("source", "nar");
            
          const { data: races, error: re } = await query.order("post_time", { ascending: true });
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [], date: targetDate });
        }
        case "horseracing.list_races": {
          const { data: races, error: re } = await admin
            .from("horse_races")
            .select("*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)")
            .order("race_date", { ascending: false })
            .limit(50);
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [] });
        }
        case "horseracing.predict_all": {
          // Windows版#94: quota fallback chain 対応
          // 1) レース毎に HORSE_PROVIDER_CHAIN を順に試行 (quota時は次プロバイダー)
          // 2) 成功した予想を horse_predictions (互換維持) + horse_race_predictions_ensemble に両方記録
          // 3) 全プロバイダーquota時のみ残りレースを早期skip
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const { data: races } = await admin.from("horse_races")
            .select("*, horse_entries(*), horse_predictions(id)")
            .eq("race_date", targetDate).eq("status", "scheduled");
          if (!races || races.length === 0) return json({ success: true, predictions: [], message: "本日のレースなし" });
          // deno-lint-ignore no-explicit-any
          const unpredicted = races.filter((r: any) => !r.horse_predictions || r.horse_predictions.length === 0);
          if (unpredicted.length === 0) return json({ success: true, predictions: [], message: "全レース予想済" });
          const results: Array<Record<string, unknown>> = [];
          const failures: Array<Record<string, unknown>> = [];
          const providerStats: Record<string, { attempts: number; hits: number; quotas: number }> = {};
          for (const cfg of HORSE_PROVIDER_CHAIN) {
            providerStats[cfg.provider] = { attempts: 0, hits: 0, quotas: 0 };
          }
          const exhaustedProviders = new Set<string>();

          for (const race of unpredicted) {
            if (exhaustedProviders.size >= HORSE_PROVIDER_CHAIN.length) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: "skipped: all providers exhausted (quota)",
              });
              continue;
            }
            // deno-lint-ignore no-explicit-any
            const entries = (race.horse_entries as any[]) ?? [];
            if (entries.length < 3) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: `entries < 3 (${entries.length}頭)`,
              });
              continue;
            }
            const prompt = buildHorseRacePrompt(race, entries);
            let succeededCfg: HorseProviderConfig | null = null;
            let succeededResult: ProviderPredictionResult | null = null;
            const perRaceFailures: Array<Record<string, unknown>> = [];

            for (const cfg of HORSE_PROVIDER_CHAIN) {
              if (exhaustedProviders.has(cfg.provider)) continue;
              providerStats[cfg.provider].attempts += 1;
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                providerStats[cfg.provider].hits += 1;
                succeededCfg = cfg;
                succeededResult = result;
                break;
              }
              perRaceFailures.push({
                provider: cfg.provider,
                model: cfg.model,
                reason: result.error?.reason,
                http_status: result.error?.http_status,
                is_quota: result.error?.is_quota ?? false,
              });
              if (result.error?.is_quota) {
                providerStats[cfg.provider].quotas += 1;
                exhaustedProviders.add(cfg.provider);
                console.warn(`[predict_all] ${cfg.provider} quota exceeded — fallback to next provider.`);
              }
            }

            if (!succeededCfg || !succeededResult || !succeededResult.prediction) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: "all providers failed",
                provider_failures: perRaceFailures,
              });
              continue;
            }

            // 1) ensemble table に記録 (プロバイダー別蓄積)
            await persistEnsemblePrediction(admin, race.id, succeededCfg, succeededResult);

            // 2) 互換維持: horse_predictions (代表1件) に最初の成功プロバイダー結果を入れる
            const pred = succeededResult.prediction;
            const { error: ie } = await admin.from("horse_predictions").upsert({
              race_id: race.id,
              first_pick: pred.first || entries[0].horse_name,
              second_pick: pred.second || entries[1].horse_name,
              third_pick: pred.third || entries[2].horse_name,
              confidence: pred.confidence,
              ai_reasoning: pred.reasoning,
              ai_model: `${succeededCfg.provider}:${succeededCfg.model}`,
            }, { onConflict: "race_id" });
            if (ie) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: `horse_predictions upsert failed: ${ie.message}`,
              });
            } else {
              results.push({
                race_id: race.id,
                race_name: race.race_name,
                provider: succeededCfg.provider,
                model: succeededCfg.model,
                ...pred,
              });
            }
          }
          return json({
            success: true,
            predictions: results,
            count: results.length,
            failures,
            failure_count: failures.length,
            provider_stats: providerStats,
            exhausted_providers: Array.from(exhaustedProviders),
          });
        }
        case "horseracing.predict_ensemble": {
          // 1レースに対し全プロバイダーで並列予想 → ensemble table に記録
          // body: { race_id, providers?: string[], force?: boolean }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const whitelist: string[] | null = Array.isArray(body.providers) ? body.providers.map(String) : null;
          const force = Boolean(body.force ?? false);
          const { data: race, error: re } = await admin.from("horse_races")
            .select("*, horse_entries(*)")
            .eq("id", raceId)
            .maybeSingle();
          if (re) throw new Error(re.message);
          if (!race) return json({ error: "race not found" }, 404);
          // deno-lint-ignore no-explicit-any
          const entries = ((race as any).horse_entries as any[]) ?? [];
          if (entries.length < 3) return json({ error: `entries < 3 (${entries.length})` }, 400);

          const targetCfgs = whitelist
            ? HORSE_PROVIDER_CHAIN.filter((c) => whitelist.includes(c.provider))
            : HORSE_PROVIDER_CHAIN;
          if (targetCfgs.length === 0) return json({ error: "no providers selected" }, 400);

          // 既に予想済みの provider は skip (force=true でやり直し)
          let existing: Set<string> = new Set();
          if (!force) {
            const { data: ex } = await admin.from("horse_race_predictions_ensemble")
              .select("provider, model")
              .eq("race_id", raceId);
            existing = new Set((ex ?? []).map((r: Record<string, unknown>) => `${r.provider}:${r.model}`));
          }

          const prompt = buildHorseRacePrompt(race as Record<string, unknown>, entries);
          const jobs = targetCfgs
            .filter((cfg) => !existing.has(`${cfg.provider}:${cfg.model}`))
            .map(async (cfg) => {
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                await persistEnsemblePrediction(admin, raceId, cfg, result);
              }
              return { cfg, result };
            });
          const settled = await Promise.all(jobs);
          const succeeded = settled.filter((s) => s.result.success);
          const failed = settled.filter((s) => !s.result.success);
          return json({
            success: true,
            race_id: raceId,
            attempted: settled.length,
            succeeded: succeeded.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              prediction: s.result.prediction,
              latency_ms: s.result.latency_ms,
            })),
            failed: failed.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              reason: s.result.error?.reason,
              is_quota: s.result.error?.is_quota ?? false,
            })),
            skipped_already_predicted: targetCfgs.length - settled.length,
          });
        }
        case "horseracing.consensus": {
          // 1レースの全予想をプロバイダー横断で集計しコンセンサスを返す
          // body: { race_id }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const { data: preds, error: pe } = await admin.from("horse_race_predictions_ensemble")
            .select("provider, model, first_pick, second_pick, third_pick, confidence, reasoning, predicted_at")
            .eq("race_id", raceId)
            .order("predicted_at", { ascending: true });
          if (pe) throw new Error(pe.message);
          const rows = preds ?? [];
          if (rows.length === 0) {
            return json({ success: true, race_id: raceId, consensus: null, predictions: [] });
          }
          // 1着票数 + 信頼度加重集計
          const firstVotes: Record<string, { votes: number; weighted: number; providers: string[] }> = {};
          for (const p of rows) {
            const horse = String(p.first_pick ?? "").trim();
            if (!horse) continue;
            if (!firstVotes[horse]) firstVotes[horse] = { votes: 0, weighted: 0, providers: [] };
            firstVotes[horse].votes += 1;
            firstVotes[horse].weighted += Number(p.confidence ?? 0.5);
            firstVotes[horse].providers.push(`${p.provider}:${p.model}`);
          }
          const sortedFirst = Object.entries(firstVotes)
            .sort((a, b) => b[1].weighted - a[1].weighted);
          const top = sortedFirst[0];
          const agreementRate = top ? top[1].votes / rows.length : 0;
          return json({
            success: true,
            race_id: raceId,
            predictions: rows,
            total_providers: rows.length,
            consensus: top ? {
              first_pick: top[0],
              votes: top[1].votes,
              weighted_score: Math.round(top[1].weighted * 1000) / 1000,
              providers: top[1].providers,
              agreement_rate: Math.round(agreementRate * 1000) / 1000,
            } : null,
            first_pick_distribution: sortedFirst.map(([horse, v]) => ({
              horse,
              votes: v.votes,
              weighted: Math.round(v.weighted * 1000) / 1000,
              providers: v.providers,
            })),
          });
        }
        case "horseracing.provider_leaderboard": {
          const { data, error: le } = await admin.from("horse_provider_leaderboard")
            .select("*");
          if (le) throw new Error(le.message);
          return json({ success: true, leaderboard: data ?? [] });
        }
        case "horseracing.evaluate_accuracy": {
          // 結果確定済みレースの ensemble 予想を全てスコアリング
          // body: { race_id? } (指定時は1レース、省略時は最新50レース)
          const raceId = body.race_id ? String(body.race_id) : null;
          const resultsQuery = admin.from("horse_results")
            .select("race_id, first_place, second_place, third_place");
          const { data: resultsRows, error: resErr } = raceId
            ? await resultsQuery.eq("race_id", raceId)
            : await resultsQuery.order("created_at", { ascending: false }).limit(50);
          if (resErr) throw new Error(resErr.message);
          if (!resultsRows || resultsRows.length === 0) {
            return json({ success: true, evaluated: 0, message: "no finalized results" });
          }
          let evaluated = 0;
          for (const r of resultsRows as Array<Record<string, unknown>>) {
            const rid = String(r.race_id);
            const { data: preds } = await admin.from("horse_race_predictions_ensemble")
              .select("provider, model, first_pick, second_pick, third_pick")
              .eq("race_id", rid);
            for (const p of (preds ?? []) as Array<Record<string, unknown>>) {
              const firstCorrect = String(p.first_pick ?? "").trim() === String(r.first_place ?? "").trim();
              const trifectaCorrect = firstCorrect
                && String(p.second_pick ?? "").trim() === String(r.second_place ?? "").trim()
                && String(p.third_pick ?? "").trim() === String(r.third_place ?? "").trim();
              await admin.from("horse_prediction_accuracy").upsert({
                race_id: rid,
                provider: p.provider,
                model: p.model,
                predicted_first: p.first_pick,
                predicted_second: p.second_pick,
                predicted_third: p.third_pick,
                actual_first: r.first_place,
                actual_second: r.second_place,
                actual_third: r.third_place,
                first_correct: firstCorrect,
                trifecta_correct: trifectaCorrect,
              }, { onConflict: "race_id,provider,model" });
              evaluated += 1;
            }
          }
          return json({ success: true, evaluated, races_processed: resultsRows.length });
        }
        case "horseracing.predictions": {
          const { data: preds, error: pe } = await admin.from("horse_predictions")
            .select("*, horse_races(race_name,race_date,venue,grade,course_type,distance)")
            .order("created_at", { ascending: false }).limit(Number(body.limit ?? 50));
          if (pe) throw new Error(pe.message);
          const raceIds = (preds ?? []).map((p: Record<string, unknown>) => p.race_id as string).filter(Boolean);
          const resultsMap: Record<string, unknown> = {};
          if (raceIds.length > 0) {
            const { data: hrs } = await admin.from("horse_results")
              .select("race_id,first_place,second_place,third_place,trifecta_paid,is_prediction_correct")
              .in("race_id", raceIds);
            (hrs ?? []).forEach((r: Record<string, unknown>) => { resultsMap[r.race_id as string] = r; });
          }
          const enriched = (preds ?? []).map((p: Record<string, unknown>) => ({
            ...p, horse_results: resultsMap[p.race_id as string] ?? null,
          }));
          return json({ success: true, predictions: enriched });
        }
        case "horseracing.store_results": {
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const pred = await admin.from("horse_predictions").select("first_pick,second_pick,third_pick").eq("race_id", raceId).maybeSingle();
          const isCorrect = pred.data
            ? (pred.data.first_pick === body.first_place && pred.data.second_pick === body.second_place && pred.data.third_pick === body.third_place)
            : null;
          const { error: re } = await admin.from("horse_results").upsert({
            race_id: raceId, first_place: body.first_place, second_place: body.second_place,
            third_place: body.third_place, trifecta_paid: body.trifecta_paid ?? null,
            winner_odds: body.winner_odds ?? null, is_prediction_correct: isCorrect,
          }, { onConflict: "race_id" });
          await admin.from("horse_races").update({ status: "completed" }).eq("id", raceId);
          if (re) throw new Error(re.message);
          return json({ success: true, is_correct: isCorrect });
        }
        case "horseracing.accuracy": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          const { data: recentHits } = await admin.from("horse_results")
            .select("race_id, is_prediction_correct, trifecta_paid, horse_races(race_name, race_date)")
            .eq("is_prediction_correct", true).order("fetched_at", { ascending: false }).limit(5);
          return json({ success: true, stats: stats ?? {}, recent_hits: recentHits ?? [] });
        }
        case "horseracing.register_race": {
          const { data: r, error: re } = await admin.from("horse_races").insert({
            source: "manual", race_name: String(body.name ?? ""),
            race_date: String(body.date ?? new Date().toISOString().split("T")[0]),
            venue: body.venue ?? null, course_type: body.race_type ?? "芝",
            grade: body.grade ?? "未勝利", distance: body.distance ?? null, status: "scheduled",
          }).select("id").single();
          if (re) throw new Error(re.message);
          return json({ success: true, race_id: r?.id });
        }
        case "horseracing.stats": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          return json({ success: true, stats: {
            totalBets: stats?.total_predictions ?? 0, wins: stats?.correct_count ?? 0,
            winRate: stats?.hit_rate_pct ?? 0, totalPayout: stats?.total_payout ?? 0,
            maxPayout: stats?.max_payout ?? 0,
          }});
        }
        default:
          return json({ error: `Unknown horseracing action: ${action}` }, 400);
      }
    }

        // ── Authenticated CRUD operations ────────────────────────────────────────
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Bookmarks ───────────────────────────────────────────────────────────
      case "bookmark.list": return json({ success: true, bookmarks: await listItems(admin, "bookmark", userId) });
      case "bookmark.add": {
        const item = await addItem(admin, "bookmark", userId, {
          url: body.url, title: body.title, tags: body.tags ?? [],
        });
        return json({ success: true, bookmark: item });
      }
      case "bookmark.delete": {
        await deleteItem(admin, "bookmark", userId, String(body.id ?? ""));
        return json({ success: true });
      }
      case "bookmark.sync": {
        const bookmarks = body.bookmarks as unknown[] ?? [];
        for (const bm of bookmarks) {
          await addItem(admin, "bookmark_sync", userId, bm as Record<string, unknown>);
        }
        return json({ success: true, synced: bookmarks.length });
      }

      // ── Quick Notes ─────────────────────────────────────────────────────────
      case "note.list": return json({ success: true, notes: await listItems(admin, "quick_note", userId) });
      case "note.add": {
        const item = await addItem(admin, "quick_note", userId, {
          content: body.content, title: body.title ?? "", tags: body.tags ?? [],
        });
        return json({ success: true, note: item });
      }
      case "note.delete": {
        await deleteItem(admin, "quick_note", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Goals ───────────────────────────────────────────────────────────────
      case "goal.list": return json({ success: true, goals: await listItems(admin, "goal", userId) });
      case "goal.add": {
        const item = await addItem(admin, "goal", userId, {
          title: body.title, description: body.description, deadline: body.deadline,
          status: "active", milestones: body.milestones ?? [],
        });
        return json({ success: true, goal: item });
      }
      case "goal.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "goal");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "goal.delete": {
        await deleteItem(admin, "goal", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Contacts ────────────────────────────────────────────────────────────
      case "contact.list": return json({ success: true, contacts: await listItems(admin, "contact", userId) });
      case "contact.add": {
        const item = await addItem(admin, "contact", userId, {
          name: body.name, email: body.email, phone: body.phone,
          company: body.company, notes: body.notes,
        });
        return json({ success: true, contact: item });
      }
      case "contact.delete": {
        await deleteItem(admin, "contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Reading List ────────────────────────────────────────────────────────
      case "reading.list": return json({ success: true, items: await listItems(admin, "reading", userId) });
      case "reading.add": {
        const item = await addItem(admin, "reading", userId, {
          url: body.url, title: body.title, status: "unread",
        });
        return json({ success: true, item });
      }
      case "reading.mark_read": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "read", read_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "reading");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Tags ────────────────────────────────────────────────────────────────
      case "tag.list": return json({ success: true, tags: await listItems(admin, "tag", userId) });
      case "tag.create": {
        const item = await addItem(admin, "tag", userId, { name: body.name, color: body.color });
        return json({ success: true, tag: item });
      }
      case "tag.delete": {
        await deleteItem(admin, "tag", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Templates ───────────────────────────────────────────────────────────
      case "template.list": return json({ success: true, templates: await listItems(admin, "template", userId) });
      case "template.create": {
        const item = await addItem(admin, "template", userId, {
          name: body.name, content: body.content, category: body.category,
        });
        return json({ success: true, template: item });
      }
      case "template.use": {
        const templates = await listItems(admin, "template", userId);
        const found = templates.find((t) => (t.metadata as Record<string, unknown>)?.id === body.id);
        return json({ success: true, content: (found?.metadata as Record<string, unknown>)?.content ?? "" });
      }
      case "template.delete": {
        await deleteItem(admin, "template", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Address Book ─────────────────────────────────────────────────────────
      case "address.list": return json({ success: true, addresses: await listItems(admin, "address", userId) });
      case "address.add": {
        const item = await addItem(admin, "address", userId, {
          name: body.name, street: body.street, city: body.city,
          country: body.country, type: body.type ?? "home",
        });
        return json({ success: true, address: item });
      }
      case "address.delete": {
        await deleteItem(admin, "address", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Emergency Contacts ──────────────────────────────────────────────────
      case "emergency.list": return json({ success: true, contacts: await listItems(admin, "emergency_contact", userId) });
      case "emergency.add": {
        const item = await addItem(admin, "emergency_contact", userId, {
          name: body.name, phone: body.phone, relation: body.relation,
        });
        return json({ success: true, contact: item });
      }
      case "emergency.delete": {
        await deleteItem(admin, "emergency_contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Habits ──────────────────────────────────────────────────────────────
      case "habit.list": return json({ success: true, habits: await listItems(admin, "habit_definition", userId) });
      case "habit.create": {
        const item = await addItem(admin, "habit_definition", userId, {
          name: body.name, frequency: body.frequency ?? "daily",
          target: body.target ?? 1, points: body.points ?? 10,
        });
        return json({ success: true, habit: item });
      }
      case "habit.checkin": {
        const item = await addItem(admin, "habit_checkin", userId, {
          habit_id: body.habit_id, note: body.note ?? "", date: new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, checkin: item });
      }
      case "habit.stats": {
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        return json({ success: true, total_checkins: checkins.length, checkins: checkins.slice(0, 30) });
      }

      // ── Habit Gamification (merged from habit-gamification EF) ───────────────
      case "habit.gamification.profile": {
        const habits = await listItems(admin, "habit_definition", userId, 20);
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        const points = checkins.length * 10;
        const level = Math.floor(points / 100) + 1;
        return json({ success: true, profile: { user_id: userId, points, level, habit_count: habits.length, checkin_count: checkins.length } });
      }
      case "habit.gamification.badges": {
        const badges = await listItems(admin, "habit_badge", userId);
        return json({ success: true, badges });
      }
      case "habit.gamification.challenges": {
        const challenges = await listItems(admin, "habit_challenge", userId, 10);
        return json({ success: true, challenges });
      }
      case "habit.gamification.leaderboard": {
        const { data, error: lbErr } = await admin.from("hub_data")
          .select("metadata")
          .eq("source", "habit_checkin")
          .order("created_at", { ascending: false })
          .limit(100);
        if (lbErr) throw new Error(lbErr.message);
        const counts: Record<string, number> = {};
        for (const row of data ?? []) {
          const uid = (row.metadata as Record<string, unknown>)?.user_id as string;
          if (uid) counts[uid] = (counts[uid] ?? 0) + 1;
        }
        const leaderboard = Object.entries(counts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 20)
          .map(([uid, count], i) => ({ rank: i + 1, user_id: uid, checkins: count }));
        return json({ success: true, leaderboard });
      }
      case "habit.gamification.award": {
        const badge = await addItem(admin, "habit_badge", userId, {
          badge_type: body.badge_type ?? "streak", title: body.title ?? "バッジ", earned_at: new Date().toISOString(),
        });
        return json({ success: true, badge });
      }

      // ── Pomodoro / Focus Timer ───────────────────────────────────────────────
      case "pomodoro.start": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, started_at: new Date().toISOString(), status: "running",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.complete": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, completed_at: new Date().toISOString(), status: "done",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.history": return json({ success: true, sessions: await listItems(admin, "pomodoro", userId) });

      case "focus.start": {
        const item = await addItem(admin, "focus_timer", userId, {
          task: body.task ?? "", started_at: new Date().toISOString(),
        });
        return json({ success: true, session: item });
      }

      // ── Clipboard History ────────────────────────────────────────────────────
      case "clipboard.list": return json({ success: true, items: await listItems(admin, "clipboard", userId, 30) });
      case "clipboard.add": {
        const item = await addItem(admin, "clipboard", userId, { text: body.text, source: body.source ?? "manual" });
        return json({ success: true, item });
      }
      case "clipboard.clear": {
        await admin.from("hub_data")
          .delete().eq("source", "clipboard").filter("metadata->>user_id", "eq", userId);
        return json({ success: true });
      }

      // ── News / RSS ───────────────────────────────────────────────────────────
      case "rss.list_feeds": return json({ success: true, feeds: await listItems(admin, "rss_feed", userId) });
      case "rss.add_feed": {
        const item = await addItem(admin, "rss_feed", userId, { url: body.url, title: body.title });
        return json({ success: true, feed: item });
      }
      case "rss.fetch": {
        const feedUrl = String(body.url ?? "");
        const res = await fetch(feedUrl).catch(() => null);
        if (!res || !res.ok) return json({ error: "Cannot fetch feed" }, 502);
        const text = await res.text();
        return json({ success: true, content: text.slice(0, 5000) });
      }

      // ── Changelog ────────────────────────────────────────────────────────────
      case "changelog.list": return json({ success: true, entries: await listItems(admin, "changelog", userId) });
      case "changelog.create": {
        const item = await addItem(admin, "changelog", userId, {
          version: body.version, title: body.title, changes: body.changes ?? [],
        });
        return json({ success: true, entry: item });
      }

      // ── Mindmap ──────────────────────────────────────────────────────────────
      case "mindmap.list": return json({ success: true, maps: await listItems(admin, "mindmap", userId) });
      case "mindmap.create": {
        const item = await addItem(admin, "mindmap", userId, {
          title: body.title, nodes: body.nodes ?? [], edges: body.edges ?? [],
        });
        return json({ success: true, map: item });
      }
      case "mindmap.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "mindmap");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "mindmap.delete": {
        await deleteItem(admin, "mindmap", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Polls & Forms ────────────────────────────────────────────────────────
      case "poll.create": {
        const item = await addItem(admin, "poll", userId, {
          question: body.question, options: body.options ?? [], votes: {},
        });
        return json({ success: true, poll: item });
      }
      case "poll.vote": {
        const polls = await listItems(admin, "poll", userId, 100);
        const poll = polls.find((p) => p.id === body.poll_id);
        if (!poll) return json({ error: "Poll not found" }, 404);
        const meta = poll.metadata as Record<string, unknown>;
        const votes = (meta.votes as Record<string, number>) ?? {};
        votes[String(body.option ?? "")] = (votes[String(body.option ?? "")] ?? 0) + 1;
        await admin.from("hub_data").update({ metadata: { ...meta, votes } }).eq("id", poll.id);
        return json({ success: true, votes });
      }
      case "form.create": {
        const item = await addItem(admin, "form", userId, {
          title: body.title, fields: body.fields ?? [], responses: [],
        });
        return json({ success: true, form: item });
      }
      case "form.submit": {
        const item = await addItem(admin, "form_response", userId, {
          form_id: body.form_id, responses: body.responses ?? {},
        });
        return json({ success: true, response: item });
      }

      // ── Note Sharing ─────────────────────────────────────────────────────────
      case "note_share.create": {
        const shareId = crypto.randomUUID();
        const item = await addItem(admin, "note_share", userId, {
          share_id: shareId, content: body.content, title: body.title,
          expires_at: body.expires_at, is_public: body.is_public ?? true,
        });
        return json({ success: true, share_id: shareId, share: item });
      }
      case "note_share.get": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "note_share")
          .filter("metadata->>share_id", "eq", String(body.share_id ?? ""))
          .single();
        return json({ success: true, note: data });
      }

      // ── Content Versioning ───────────────────────────────────────────────────
      case "version.list": return json({ success: true, versions: await listItems(admin, "content_version", userId) });
      case "version.create": {
        const item = await addItem(admin, "content_version", userId, {
          document_id: body.document_id, content: body.content, version: body.version ?? 1,
        });
        return json({ success: true, version: item });
      }

      // ── Password Vault ───────────────────────────────────────────────────────
      case "vault.list": return json({ success: true, entries: await listItems(admin, "password_vault", userId) });
      case "vault.add": {
        const item = await addItem(admin, "password_vault", userId, {
          site: body.site, username: body.username, encrypted_password: body.encrypted_password,
          notes: body.notes,
        });
        return json({ success: true, entry: item });
      }
      case "vault.delete": {
        await deleteItem(admin, "password_vault", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Virtual Pet ──────────────────────────────────────────────────────────
      case "pet.status": {
        const pets = await listItems(admin, "virtual_pet", userId, 1);
        if (pets.length === 0) {
          const pet = await addItem(admin, "virtual_pet", userId, {
            name: "たま", hunger: 50, happiness: 50, age_days: 0, last_fed: new Date().toISOString(),
          });
          return json({ success: true, pet });
        }
        return json({ success: true, pet: pets[0] });
      }
      case "pet.feed": {
        const { data: latest } = await admin.from("hub_data")
          .select("id, metadata").eq("source", "virtual_pet")
          .filter("metadata->>user_id", "eq", userId).order("created_at", { ascending: false }).limit(1).single();
        if (!latest) return json({ error: "No pet found" }, 404);
        const meta = latest.metadata as Record<string, unknown>;
        await admin.from("hub_data").update({
          metadata: { ...meta, hunger: Math.min(100, Number(meta.hunger ?? 50) + 20), last_fed: new Date().toISOString() },
        }).eq("id", latest.id);
        return json({ success: true, message: "Pet fed!" });
      }

      // ── Slack Integration ─────────────────────────────────────────────────────
      case "slack.post": {
        const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
        if (!webhookUrl) return json({ error: "SLACK_WEBHOOK_URL not configured" }, 503);
        const text = String(body.text ?? "");
        if (!text) return json({ error: "text is required" }, 400);
        const payload: Record<string, unknown> = { text };
        if (body.channel) payload.channel = body.channel;
        if (body.username) payload.username = body.username;
        const resp = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        if (!resp.ok) return json({ error: `Slack API error: ${resp.status}` }, 502);
        return json({ success: true, message: "Posted to Slack" });
      }

      case "slack.search": {
        const token = Deno.env.get("SLACK_BOT_TOKEN") ?? "";
        if (!token) return json({ error: "SLACK_BOT_TOKEN not configured" }, 503);
        const query = String(body.query ?? "");
        if (!query) return json({ error: "query is required" }, 400);
        const count = Math.min(Number(body.count ?? 10), 50);
        const params = new URLSearchParams({ query, count: String(count) });
        const resp = await fetch(`https://slack.com/api/search.messages?${params}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!resp.ok) return json({ error: `Slack API error: ${resp.status}` }, 502);
        const data = await resp.json() as Record<string, unknown>;
        if (!data.ok) return json({ error: String(data.error ?? "Slack API error") }, 502);
        const msgData = data.messages as Record<string, unknown> | undefined;
        const matches = (msgData?.matches as Record<string, unknown>[] | undefined) ?? [];
        const messages = matches.map((m) => ({
          text: m.text, user: m.username,
          channel: (m.channel as Record<string, unknown> | undefined)?.name,
          ts: m.ts,
        }));
        return json({ success: true, total: msgData?.total ?? 0, messages });
      }

      default:
        return json({
          error: `Unknown action: ${action}`,
          available_actions: [
            "generate_password", "generate_qr", "convert_currency", "get_weather", "render_markdown", "translate",
            "bookmark.list", "bookmark.add", "bookmark.delete", "bookmark.sync",
            "note.list", "note.add", "note.delete",
            "goal.list", "goal.add", "goal.update", "goal.delete",
            "contact.list", "contact.add", "contact.delete",
            "reading.list", "reading.add", "reading.mark_read",
            "tag.list", "tag.create", "tag.delete",
            "template.list", "template.create", "template.use", "template.delete",
            "address.list", "address.add", "address.delete",
            "emergency.list", "emergency.add", "emergency.delete",
            "habit.list", "habit.create", "habit.checkin", "habit.stats",
            "pomodoro.start", "pomodoro.complete", "pomodoro.history",
            "focus.start",
            "clipboard.list", "clipboard.add", "clipboard.clear",
            "rss.list_feeds", "rss.add_feed", "rss.fetch",
            "changelog.list", "changelog.create",
            "mindmap.list", "mindmap.create", "mindmap.update", "mindmap.delete",
            "poll.create", "poll.vote", "form.create", "form.submit",
            "note_share.create", "note_share.get",
            "version.list", "version.create",
            "vault.list", "vault.add", "vault.delete",
            "pet.status", "pet.feed",
            "horseracing.today", "horseracing.list_races", "horseracing.predict_all",
            "horseracing.predict_ensemble", "horseracing.consensus",
            "horseracing.provider_leaderboard", "horseracing.evaluate_accuracy",
            "horseracing.predictions", "horseracing.store_results", "horseracing.accuracy",
            "horseracing.register_race", "horseracing.stats",
            "slack.post", "slack.search",
          ],
        }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
