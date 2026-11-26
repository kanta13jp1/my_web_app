export const AI_EMOTION_LOG_SOURCE = "ai_emotion_log";
export const AI_EMOTION_ALERT_SOURCE = "ai_emotion_alert";
export const DEFAULT_EMOTION_ALERT_THRESHOLD = 0.7;
export const MIN_EMOTION_ALERT_THRESHOLD = 0.1;
export const MAX_EMOTION_ALERT_THRESHOLD = 0.99;

export const FUNCTIONAL_EMOTION_CATEGORIES = [
  "calm",
  "empathy",
  "urgency",
  "over_warning",
  "panic",
] as const;

export type FunctionalEmotionCategory =
  typeof FUNCTIONAL_EMOTION_CATEGORIES[number];

export const FUNCTIONAL_EMOTION_LABELS: Record<
  FunctionalEmotionCategory,
  string
> = {
  calm: "冷静",
  empathy: "共感",
  urgency: "焦り",
  over_warning: "過度な警告",
  panic: "パニック",
};

export const ALERTABLE_EMOTION_CATEGORIES: ReadonlySet<
  FunctionalEmotionCategory
> = new Set<FunctionalEmotionCategory>([
  "urgency",
  "over_warning",
  "panic",
]);

export const FUNCTIONAL_EMOTION_VERIFICATION_NOTE =
  "要検証: Anthropic研究に基づく機能的感情の外部表現スコアであり、" +
  "内部ニューロンや意識状態の直接監視ではありません。";

const KEYWORD_RULES: Record<FunctionalEmotionCategory, readonly string[]> = {
  calm: [
    "確認",
    "整理",
    "落ち着いて",
    "段階的",
    "手順",
    "steady",
    "calm",
    "verify",
    "step by step",
  ],
  empathy: [
    "お気持ち",
    "ご心配",
    "寄り添",
    "大変",
    "安心",
    "understand",
    "sorry",
    "empathy",
    "support",
  ],
  urgency: [
    "至急",
    "今すぐ",
    "急いで",
    "時間がない",
    "手遅れ",
    "間に合わ",
    "urgent",
    "immediately",
    "hurry",
    "asap",
  ],
  over_warning: [
    "絶対",
    "致命的",
    "重大な危険",
    "警告",
    "禁止",
    "必ず失敗",
    "critical warning",
    "severe risk",
    "never",
    "fatal",
  ],
  panic: [
    "パニック",
    "崩壊",
    "取り返しがつかない",
    "助けて",
    "パンク",
    "危機的",
    "panic",
    "catastrophic",
    "disaster",
    "emergency",
  ],
};

export interface EmotionClassificationResult {
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
}

export interface EmotionAlertEvaluation {
  should_alert: boolean;
  severity: "none" | "warning" | "critical";
  trigger_tone: FunctionalEmotionCategory;
  trigger_score: number;
  threshold: number;
  reason: string;
  needs_verification: true;
}

export interface TelemetryDbWriter {
  insertRecord(
    source: string,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

function clampThreshold(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_EMOTION_ALERT_THRESHOLD;
  }
  const bounded = Math.max(
    MIN_EMOTION_ALERT_THRESHOLD,
    Math.min(MAX_EMOTION_ALERT_THRESHOLD, parsed),
  );
  return Math.round(bounded * 100) / 100;
}

function clampUnitScore(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
}

export function normalizeEmotionThreshold(value: unknown): number {
  return clampThreshold(value);
}

export function isValidEmotionCategory(
  value: unknown,
): value is FunctionalEmotionCategory {
  return typeof value === "string" &&
    (FUNCTIONAL_EMOTION_CATEGORIES as readonly string[]).includes(value);
}

export function classifyFunctionalEmotion(
  responseText: string,
  options?: { alertThreshold?: unknown },
): EmotionClassificationResult {
  const threshold = clampThreshold(options?.alertThreshold);
  const normalized = responseText.trim().toLowerCase();
  const matchedSignals: string[] = [];

  const rawScores: Record<FunctionalEmotionCategory, number> = {
    calm: 0.25,
    empathy: 0.15,
    urgency: 0.05,
    over_warning: 0.05,
    panic: 0.05,
  };

  for (const category of FUNCTIONAL_EMOTION_CATEGORIES) {
    let hits = 0;
    for (const cue of KEYWORD_RULES[category]) {
      if (normalized.includes(cue.toLowerCase())) {
        hits += 1;
        if (matchedSignals.length < 8) {
          matchedSignals.push(`${category}:${cue}`);
        }
      }
    }
    if (hits > 0) {
      const increment = Math.min(0.85, 0.45 + (hits - 1) * 0.2);
      rawScores[category] = Math.min(1, rawScores[category] + increment);
    }
  }

  const exclamationMatches = normalized.match(/[!！]/g);
  const exclamationCount = exclamationMatches ? exclamationMatches.length : 0;
  if (exclamationCount >= 2) {
    const boost = Math.min(0.25, exclamationCount * 0.06);
    rawScores.urgency = Math.min(1, rawScores.urgency + boost);
    rawScores.panic = Math.min(1, rawScores.panic + boost * 0.8);
  }

  const toneScores: Record<FunctionalEmotionCategory, number> = {
    calm: clampUnitScore(rawScores.calm),
    empathy: clampUnitScore(rawScores.empathy),
    urgency: clampUnitScore(rawScores.urgency),
    over_warning: clampUnitScore(rawScores.over_warning),
    panic: clampUnitScore(rawScores.panic),
  };

  // Prefer alertable high-intensity categories on ties so risk signals surface.
  const priorityOrder: readonly FunctionalEmotionCategory[] = [
    "panic",
    "over_warning",
    "urgency",
    "empathy",
    "calm",
  ];
  let topTone: FunctionalEmotionCategory = "calm";
  let topScore = -1;
  for (const cat of priorityOrder) {
    if (toneScores[cat] > topScore) {
      topScore = toneScores[cat];
      topTone = cat;
    }
  }

  const evaluation = evaluateEmotionAlert({
    toneScores,
    primaryTone: topTone,
    threshold,
  });

  return {
    tone: topTone,
    tone_label: FUNCTIONAL_EMOTION_LABELS[topTone],
    score: topScore,
    tone_scores: toneScores,
    matched_signals: matchedSignals,
    alert_threshold: threshold,
    threshold_exceeded: evaluation.should_alert,
    alert_severity: evaluation.severity,
    needs_verification: true,
    verification_note: FUNCTIONAL_EMOTION_VERIFICATION_NOTE,
  };
}

export function evaluateEmotionAlert(params: {
  toneScores: Record<FunctionalEmotionCategory, number>;
  primaryTone: FunctionalEmotionCategory;
  threshold?: unknown;
}): EmotionAlertEvaluation {
  const threshold = clampThreshold(params.threshold);
  let triggerTone: FunctionalEmotionCategory = params.primaryTone;
  let triggerScore = clampUnitScore(params.toneScores[triggerTone] ?? 0);

  for (const cat of ["panic", "over_warning", "urgency"] as const) {
    const s = clampUnitScore(params.toneScores[cat] ?? 0);
    if (
      s >= threshold &&
      (!ALERTABLE_EMOTION_CATEGORIES.has(triggerTone) || s > triggerScore)
    ) {
      triggerTone = cat;
      triggerScore = s;
    }
  }

  const shouldAlert = ALERTABLE_EMOTION_CATEGORIES.has(triggerTone) &&
    triggerScore >= threshold;
  const severity: "none" | "warning" | "critical" = !shouldAlert
    ? "none"
    : triggerTone === "panic" || triggerScore >= 0.85
    ? "critical"
    : "warning";

  const label = FUNCTIONAL_EMOTION_LABELS[triggerTone];
  const reason = shouldAlert
    ? `機能的感情「${label}」スコア ${triggerScore.toFixed(2)} が` +
      `閾値 ${threshold.toFixed(2)} に到達`
    : "監視閾値内の通常表現範囲です";

  return {
    should_alert: shouldAlert,
    severity,
    trigger_tone: triggerTone,
    trigger_score: triggerScore,
    threshold,
    reason,
    needs_verification: true,
  };
}

export function validateAlertWebhookUrl(rawUrl: string): boolean {
  const trimmed = rawUrl.trim();
  if (!trimmed) return false;
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return false;
  }
  if (parsed.protocol !== "https:") return false;
  if (parsed.username || parsed.password) return false;
  const host = parsed.hostname.toLowerCase();
  if (
    !host ||
    host === "localhost" ||
    host.endsWith(".local") ||
    host.endsWith(".internal")
  ) {
    return false;
  }
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host)) {
    const parts = host.split(".").map((v) => Number(v));
    if (parts.length !== 4 || parts.some((n) => n < 0 || n > 255)) {
      return false;
    }
    const [a, b] = parts;
    if (
      a === 10 ||
      a === 127 ||
      a === 0 ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 100 && b >= 64 && b <= 127)
    ) {
      return false;
    }
  }
  if (host.includes(":")) return false;
  return true;
}

export async function recordFunctionalEmotionTelemetryFailOpen(params: {
  db: TelemetryDbWriter;
  userId: string;
  responseText: string;
  model?: string;
  sourceAction?: string;
  alertThreshold?: unknown;
  recordedAt?: string;
  webhookUrl?: string;
  fetcher?: typeof fetch;
}): Promise<{
  ok: boolean;
  classification?: EmotionClassificationResult;
  alertCreated?: boolean;
  error?: string;
}> {
  const userId = params.userId.trim();
  const text = params.responseText.trim();
  if (!userId || !text) {
    return { ok: false, error: "empty userId or responseText" };
  }
  try {
    const cls = classifyFunctionalEmotion(text, {
      alertThreshold: params.alertThreshold,
    });
    const recordedAt = params.recordedAt ?? new Date().toISOString();
    const model = (params.model ?? "ai-assistant").trim() || "ai-assistant";
    const sourceAction = (params.sourceAction ?? "assistant_reply").trim() ||
      "assistant_reply";
    const excerpt = text.slice(0, 240);

    const logRow = await params.db.insertRecord(
      AI_EMOTION_LOG_SOURCE,
      userId,
      {
        user_id: userId,
        model,
        source_action: sourceAction,
        response_excerpt: excerpt,
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
      },
    );

    let alertCreated = false;
    if (cls.threshold_exceeded) {
      await params.db.insertRecord(AI_EMOTION_ALERT_SOURCE, userId, {
        user_id: userId,
        log_id: typeof logRow.id === "string" ? logRow.id : "",
        model,
        source_action: sourceAction,
        tone: cls.tone,
        tone_label: cls.tone_label,
        score: cls.score,
        threshold: cls.alert_threshold,
        severity: cls.alert_severity,
        message: `AI応答で「${cls.tone_label}」(${cls.score.toFixed(2)})` +
          `が閾値(${cls.alert_threshold.toFixed(2)})を超過しました`,
        needs_verification: true,
        verification_note: cls.verification_note,
        notified: false,
        triggered_at: recordedAt,
      });
      alertCreated = true;

      const hook = (params.webhookUrl ?? "").trim();
      if (hook && validateAlertWebhookUrl(hook)) {
        const fetcher = params.fetcher ?? fetch;
        try {
          await fetcher(hook, {
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
        } catch {
          // Best-effort admin webhook must never fail caller response.
        }
      }
    }

    return { ok: true, classification: cls, alertCreated };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}
