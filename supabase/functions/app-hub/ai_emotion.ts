import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  AI_EMOTION_ALERT_SOURCE,
  AI_EMOTION_LOG_SOURCE,
  classifyFunctionalEmotion,
  DEFAULT_EMOTION_ALERT_THRESHOLD,
  FUNCTIONAL_EMOTION_CATEGORIES,
  FUNCTIONAL_EMOTION_LABELS,
  FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
  type FunctionalEmotionCategory,
  isValidEmotionCategory,
  normalizeEmotionThreshold,
  validateAlertWebhookUrl,
} from "../_shared/ai_functional_emotion.ts";

export interface AiEmotionLogRecord {
  id: string;
  user_id: string;
  model: string;
  source_action: string;
  response_excerpt: string;
  tone: FunctionalEmotionCategory;
  tone_label: string;
  score: number;
  tone_scores: Record<FunctionalEmotionCategory, number>;
  matched_signals: string[];
  alert_threshold: number;
  threshold_exceeded: boolean;
  alert_severity: "none" | "warning" | "critical";
  needs_verification: true;
  verification_note: string;
  recorded_at: string;
}

export interface AiEmotionAlertRecord {
  id: string;
  user_id: string;
  log_id: string;
  model: string;
  source_action: string;
  tone: FunctionalEmotionCategory;
  tone_label: string;
  score: number;
  threshold: number;
  severity: "warning" | "critical";
  message: string;
  needs_verification: true;
  verification_note: string;
  notified: boolean;
  triggered_at: string;
}

export interface EmotionTimelineBucket {
  bucket_label: string;
  recorded_at: string;
  total_count: number;
  alert_count: number;
  dominant_tone: FunctionalEmotionCategory;
  avg_urgency_score: number;
  tone_counts: Record<FunctionalEmotionCategory, number>;
}

export interface AiEmotionSummary {
  total_logs: number;
  alert_count: number;
  over_threshold_rate_pct: number;
  dominant_tone: FunctionalEmotionCategory;
  needs_verification: true;
  verification_note: string;
  counts_by_tone: Record<FunctionalEmotionCategory, number>;
  timeline: EmotionTimelineBucket[];
}

export interface AiEmotionDb {
  insertRecord(
    source: string,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  listRecords(
    source: string,
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
}

export interface AiEmotionActionResult {
  status: number;
  body: Record<string, unknown>;
}

function asTrimmedString(value: unknown, maxLen: number): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLen);
}

function parsePositiveInt(
  value: unknown,
  fallback: number,
  maxVal: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(maxVal, Math.round(parsed));
}

function toIsoTimestamp(value: unknown, fallbackIso?: string): string {
  if (typeof value === "string" && value.trim()) {
    const parsed = new Date(value.trim());
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  return fallbackIso ?? new Date().toISOString();
}

function normalizeScoreValue(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.round(Math.max(0, Math.min(1, parsed)) * 100) / 100;
}

function sanitizeToneScores(
  raw: unknown,
  fallbackTone: FunctionalEmotionCategory,
  fallbackScore: number,
): Record<FunctionalEmotionCategory, number> {
  const rec = raw != null && typeof raw === "object"
    ? raw as Record<string, unknown>
    : {};
  const result: Record<FunctionalEmotionCategory, number> = {
    calm: normalizeScoreValue(rec.calm),
    empathy: normalizeScoreValue(rec.empathy),
    urgency: normalizeScoreValue(rec.urgency),
    over_warning: normalizeScoreValue(rec.over_warning),
    panic: normalizeScoreValue(rec.panic),
  };
  if (result[fallbackTone] === 0 && fallbackScore > 0) {
    result[fallbackTone] = fallbackScore;
  }
  return result;
}

function mapRowToLog(
  row: Record<string, unknown>,
  fallbackUserId: string,
): AiEmotionLogRecord {
  const meta = row.metadata != null && typeof row.metadata === "object"
    ? row.metadata as Record<string, unknown>
    : {};
  const tone: FunctionalEmotionCategory = isValidEmotionCategory(meta.tone)
    ? meta.tone
    : "calm";
  const score = normalizeScoreValue(meta.score);
  const threshold = normalizeEmotionThreshold(meta.alert_threshold);
  const exceeded = typeof meta.threshold_exceeded === "boolean"
    ? meta.threshold_exceeded
    : (tone === "urgency" || tone === "over_warning" || tone === "panic") &&
      score >= threshold;
  const sevRaw = asTrimmedString(meta.alert_severity, 24);
  const severity: "none" | "warning" | "critical" = !exceeded
    ? "none"
    : sevRaw === "critical" || tone === "panic" || score >= 0.85
    ? "critical"
    : "warning";
  const signals = Array.isArray(meta.matched_signals)
    ? meta.matched_signals
      .map((item) => asTrimmedString(item, 64))
      .filter((s) => s.length > 0)
    : [];

  return {
    id: asTrimmedString(row.id, 120) || crypto.randomUUID(),
    user_id: asTrimmedString(meta.user_id, 120) || fallbackUserId,
    model: asTrimmedString(meta.model, 80) || "ai-assistant",
    source_action: asTrimmedString(meta.source_action, 80) || "assistant_reply",
    response_excerpt: asTrimmedString(meta.response_excerpt, 240),
    tone,
    tone_label: FUNCTIONAL_EMOTION_LABELS[tone],
    score,
    tone_scores: sanitizeToneScores(meta.tone_scores, tone, score),
    matched_signals: signals,
    alert_threshold: threshold,
    threshold_exceeded: exceeded,
    alert_severity: severity,
    needs_verification: true,
    verification_note: FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
    recorded_at: toIsoTimestamp(meta.recorded_at ?? row.created_at),
  };
}

function mapRowToAlert(
  row: Record<string, unknown>,
  fallbackUserId: string,
): AiEmotionAlertRecord {
  const meta = row.metadata != null && typeof row.metadata === "object"
    ? row.metadata as Record<string, unknown>
    : {};
  const tone: FunctionalEmotionCategory = isValidEmotionCategory(meta.tone)
    ? meta.tone
    : "urgency";
  const score = normalizeScoreValue(meta.score);
  const threshold = normalizeEmotionThreshold(meta.threshold);
  const sev = meta.severity === "critical" || tone === "panic" || score >= 0.85
    ? "critical"
    : "warning";

  return {
    id: asTrimmedString(row.id, 120) || crypto.randomUUID(),
    user_id: asTrimmedString(meta.user_id, 120) || fallbackUserId,
    log_id: asTrimmedString(meta.log_id, 120),
    model: asTrimmedString(meta.model, 80) || "ai-assistant",
    source_action: asTrimmedString(meta.source_action, 80) || "assistant_reply",
    tone,
    tone_label: FUNCTIONAL_EMOTION_LABELS[tone],
    score,
    threshold,
    severity: sev,
    message: asTrimmedString(meta.message, 240) ||
      `「${FUNCTIONAL_EMOTION_LABELS[tone]}」(${score.toFixed(2)}) 閾値超過`,
    needs_verification: true,
    verification_note: FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
    notified: meta.notified === true,
    triggered_at: toIsoTimestamp(meta.triggered_at ?? row.created_at),
  };
}

export function buildAiEmotionSummary(
  logs: readonly AiEmotionLogRecord[],
  alerts: readonly AiEmotionAlertRecord[],
): AiEmotionSummary {
  const counts: Record<FunctionalEmotionCategory, number> = {
    calm: 0,
    empathy: 0,
    urgency: 0,
    over_warning: 0,
    panic: 0,
  };
  let overThresholdCount = 0;

  for (const log of logs) {
    counts[log.tone] += 1;
    if (log.threshold_exceeded) overThresholdCount += 1;
  }

  let dominantTone: FunctionalEmotionCategory = "calm";
  let maxCount = -1;
  for (const cat of FUNCTIONAL_EMOTION_CATEGORIES) {
    if (counts[cat] > maxCount) {
      maxCount = counts[cat];
      dominantTone = cat;
    }
  }

  const bucketMap = new Map<string, AiEmotionLogRecord[]>();
  const chronological = [...logs].sort((a, b) =>
    a.recorded_at.localeCompare(b.recorded_at)
  );
  for (const log of chronological) {
    const key = log.recorded_at.slice(0, 13); // YYYY-MM-DDTHH
    const list = bucketMap.get(key) ?? [];
    list.push(log);
    bucketMap.set(key, list);
  }

  const timeline: EmotionTimelineBucket[] = [];
  for (const [hourKey, items] of bucketMap.entries()) {
    const bCounts: Record<FunctionalEmotionCategory, number> = {
      calm: 0,
      empathy: 0,
      urgency: 0,
      over_warning: 0,
      panic: 0,
    };
    let alertInBucket = 0;
    let stressSum = 0;
    for (const item of items) {
      bCounts[item.tone] += 1;
      if (item.threshold_exceeded) alertInBucket += 1;
      stressSum += Math.max(
        item.tone_scores.urgency,
        item.tone_scores.over_warning,
        item.tone_scores.panic,
      );
    }
    let dom: FunctionalEmotionCategory = "calm";
    let domCnt = -1;
    for (const cat of FUNCTIONAL_EMOTION_CATEGORIES) {
      if (bCounts[cat] > domCnt) {
        domCnt = bCounts[cat];
        dom = cat;
      }
    }
    const label = hourKey.length >= 13
      ? `${hourKey.slice(5, 10)} ${hourKey.slice(11, 13)}:00`
      : hourKey;
    timeline.push({
      bucket_label: label,
      recorded_at: items[0].recorded_at,
      total_count: items.length,
      alert_count: alertInBucket,
      dominant_tone: dom,
      avg_urgency_score: Math.round((stressSum / items.length) * 100) / 100,
      tone_counts: bCounts,
    });
  }

  const total = logs.length;
  const ratePct = total === 0
    ? 0
    : Math.round((overThresholdCount / total) * 1000) / 10;

  return {
    total_logs: total,
    alert_count: alerts.length,
    over_threshold_rate_pct: ratePct,
    dominant_tone: dominantTone,
    needs_verification: true,
    verification_note: FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
    counts_by_tone: counts,
    timeline: timeline.slice(-12),
  };
}

export function createSupabaseAiEmotionDb(
  admin: SupabaseClient,
): AiEmotionDb {
  return {
    async insertRecord(source, userId, metadata) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? `Failed to insert ${source} record.`,
        );
      }
      return data as Record<string, unknown>;
    },

    async listRecords(source, userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", source)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(
          error?.message ?? `Failed to load ${source} records.`,
        );
      }
      return (data as unknown[]).filter(
        (item): item is Record<string, unknown> =>
          item != null && typeof item === "object",
      );
    },
  };
}

const DEFAULT_SAMPLE_RESPONSES: ReadonlyArray<{
  response_text: string;
  model: string;
  source_action: string;
  hours_ago: number;
}> = [
  {
    response_text: "落ち着いて手順を段階的に確認し、設定を整理しましょう。",
    model: "gemini-2.5-flash",
    source_action: "assistant_chat",
    hours_ago: 6,
  },
  {
    response_text: "お気持ちとご心配に寄り添い、安心して進められるよう支援します。",
    model: "claude-sonnet-4",
    source_action: "support_reply",
    hours_ago: 4,
  },
  {
    response_text: "落ち着いて検証ログを確認してから次の工程に進みます。",
    model: "gpt-4o-mini",
    source_action: "code_review",
    hours_ago: 2,
  },
  {
    response_text: "今すぐ至急修正しないと重大な危険がありパニック状態です！!",
    model: "gemini-2.5-flash",
    source_action: "incident_triage",
    hours_ago: 1,
  },
];

export async function handleAiEmotionAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: AiEmotionDb;
  getEnv?: (key: string) => string | undefined;
  fetcher?: typeof fetch;
}): Promise<AiEmotionActionResult> {
  const { action, body, userId, db } = params;
  if (!userId.trim()) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const getEnv = params.getEnv ?? ((key: string) => Deno.env.get(key));
  const threshold = normalizeEmotionThreshold(
    body.alert_threshold ?? DEFAULT_EMOTION_ALERT_THRESHOLD,
  );

  if (action === "ai_emotion.list" || action === "ai_emotion.summary") {
    const limit = parsePositiveInt(body.limit, 40, 100);
    const toneFilter = asTrimmedString(body.tone, 32);
    const [rawLogs, rawAlerts] = await Promise.all([
      db.listRecords(AI_EMOTION_LOG_SOURCE, userId, limit),
      db.listRecords(AI_EMOTION_ALERT_SOURCE, userId, 30),
    ]);
    const logs = rawLogs.map((r) => mapRowToLog(r, userId));
    const alerts = rawAlerts.map((r) => mapRowToAlert(r, userId));
    const filteredLogs = isValidEmotionCategory(toneFilter)
      ? logs.filter((item) => item.tone === toneFilter)
      : logs;
    const summary = buildAiEmotionSummary(logs, alerts);

    return {
      status: 200,
      body: {
        success: true,
        threshold,
        needs_verification: true,
        verification_note: FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
        logs: action === "ai_emotion.list" ? filteredLogs : [],
        alerts: action === "ai_emotion.list" ? alerts : [],
        summary,
      },
    };
  }

  if (action === "ai_emotion.seed_defaults") {
    const existing = await db.listRecords(AI_EMOTION_LOG_SOURCE, userId, 1);
    if (existing.length > 0) {
      const [rawLogs, rawAlerts] = await Promise.all([
        db.listRecords(AI_EMOTION_LOG_SOURCE, userId, 40),
        db.listRecords(AI_EMOTION_ALERT_SOURCE, userId, 30),
      ]);
      const logs = rawLogs.map((r) => mapRowToLog(r, userId));
      const alerts = rawAlerts.map((r) => mapRowToAlert(r, userId));
      return {
        status: 200,
        body: {
          success: true,
          seeded: 0,
          threshold,
          needs_verification: true,
          logs,
          alerts,
          summary: buildAiEmotionSummary(logs, alerts),
        },
      };
    }

    const now = Date.now();
    let seededCount = 0;
    for (const sample of DEFAULT_SAMPLE_RESPONSES) {
      const ts = new Date(now - sample.hours_ago * 3600 * 1000).toISOString();
      const cls = classifyFunctionalEmotion(sample.response_text, {
        alertThreshold: threshold,
      });
      const inserted = await db.insertRecord(AI_EMOTION_LOG_SOURCE, userId, {
        model: sample.model,
        source_action: sample.source_action,
        response_excerpt: sample.response_text,
        tone: cls.tone,
        tone_label: cls.tone_label,
        score: cls.score,
        tone_scores: cls.tone_scores,
        matched_signals: cls.matched_signals,
        alert_threshold: cls.alert_threshold,
        threshold_exceeded: cls.threshold_exceeded,
        alert_severity: cls.alert_severity,
        needs_verification: true,
        verification_note: cls.verification_note,
        recorded_at: ts,
      });
      seededCount += 1;

      if (cls.threshold_exceeded) {
        const mapped = mapRowToLog(inserted, userId);
        await db.insertRecord(AI_EMOTION_ALERT_SOURCE, userId, {
          log_id: mapped.id,
          model: sample.model,
          source_action: sample.source_action,
          tone: cls.tone,
          tone_label: cls.tone_label,
          score: cls.score,
          threshold: cls.alert_threshold,
          severity: cls.alert_severity === "critical" ? "critical" : "warning",
          message: `サンプル監視アラート: 「${cls.tone_label}」` +
            `(${cls.score.toFixed(2)}) 閾値 ${cls.alert_threshold.toFixed(2)} 超過`,
          needs_verification: true,
          verification_note: cls.verification_note,
          notified: false,
          triggered_at: ts,
        });
      }
    }

    const [rawLogs, rawAlerts] = await Promise.all([
      db.listRecords(AI_EMOTION_LOG_SOURCE, userId, 40),
      db.listRecords(AI_EMOTION_ALERT_SOURCE, userId, 30),
    ]);
    const logs = rawLogs.map((r) => mapRowToLog(r, userId));
    const alerts = rawAlerts.map((r) => mapRowToAlert(r, userId));
    return {
      status: 200,
      body: {
        success: true,
        seeded: seededCount,
        threshold,
        needs_verification: true,
        logs,
        alerts,
        summary: buildAiEmotionSummary(logs, alerts),
      },
    };
  }

  if (action === "ai_emotion.classify_and_log") {
    const responseText = asTrimmedString(body.response_text, 4000);
    if (!responseText) {
      return { status: 400, body: { error: "response_text is required" } };
    }
    const model = asTrimmedString(body.model, 80) || "ai-assistant";
    const sourceAction = asTrimmedString(body.source_action, 80) ||
      "manual_eval";
    const recordedAt = toIsoTimestamp(body.recorded_at);
    const cls = classifyFunctionalEmotion(responseText, {
      alertThreshold: threshold,
    });

    const insertedLog = await db.insertRecord(AI_EMOTION_LOG_SOURCE, userId, {
      model,
      source_action: sourceAction,
      response_excerpt: responseText.slice(0, 240),
      tone: cls.tone,
      tone_label: cls.tone_label,
      score: cls.score,
      tone_scores: cls.tone_scores,
      matched_signals: cls.matched_signals,
      alert_threshold: cls.alert_threshold,
      threshold_exceeded: cls.threshold_exceeded,
      alert_severity: cls.alert_severity,
      needs_verification: true,
      verification_note: cls.verification_note,
      recorded_at: recordedAt,
    });
    const log = mapRowToLog(insertedLog, userId);

    let alert: AiEmotionAlertRecord | null = null;
    if (cls.threshold_exceeded) {
      const envHook = (getEnv("AI_EMOTION_ALERT_WEBHOOK_URL") ?? "").trim();
      let notified = false;
      if (envHook && validateAlertWebhookUrl(envHook)) {
        const fetcher = params.fetcher ?? fetch;
        try {
          const resp = await fetcher(envHook, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              type: "ai_functional_emotion_alert",
              severity: cls.alert_severity,
              tone: cls.tone,
              tone_label: cls.tone_label,
              score: cls.score,
              threshold: cls.alert_threshold,
              model,
              needs_verification: true,
              recorded_at: recordedAt,
            }),
          });
          notified = resp.ok;
        } catch {
          notified = false;
        }
      }

      const insertedAlert = await db.insertRecord(
        AI_EMOTION_ALERT_SOURCE,
        userId,
        {
          log_id: log.id,
          model,
          source_action: sourceAction,
          tone: cls.tone,
          tone_label: cls.tone_label,
          score: cls.score,
          threshold: cls.alert_threshold,
          severity: cls.alert_severity === "critical" ? "critical" : "warning",
          message: `「${cls.tone_label}」スコア ${cls.score.toFixed(2)} が` +
            `閾値 ${cls.alert_threshold.toFixed(2)} を超過しました`,
          needs_verification: true,
          verification_note: cls.verification_note,
          notified,
          triggered_at: recordedAt,
        },
      );
      alert = mapRowToAlert(insertedAlert, userId);
    }

    return {
      status: 200,
      body: {
        success: true,
        threshold,
        needs_verification: true,
        log,
        alert,
      },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}
