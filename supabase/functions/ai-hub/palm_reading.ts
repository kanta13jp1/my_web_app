export type PalmHandSide = "left" | "right";

export type PalmLineKey = "life" | "head" | "heart" | "fate";

export type PalmLineReading = {
  key: PalmLineKey;
  label: string;
  visibility: number;
  strength: number;
  continuity: number;
  shape: string;
  interpretation: string;
};

export type PalmReadingAnalysis = {
  schema_version: 1;
  detected_hand: PalmHandSide | "unknown";
  photo_quality: {
    score: number;
    is_usable: boolean;
    feedback: string;
  };
  overall: string;
  traits: string;
  love: string;
  work: string;
  advice: string[];
  lines: PalmLineReading[];
  disclaimer: string;
};

export type PalmReadingComparison = {
  has_previous: boolean;
  confidence: "low" | "medium";
  summary: string;
  caution: string;
  changes: Array<{
    key: PalmLineKey;
    label: string;
    direction: "stronger" | "stable" | "weaker" | "uncertain";
    detail: string;
  }>;
};

export type PalmReadingPayload = {
  analysis: PalmReadingAnalysis;
  comparison: PalmReadingComparison;
};

export const PALM_READING_DISCLAIMER =
  "手相占いは科学的・医学的な診断ではありません。結果は娯楽と自己対話のきっかけとしてお楽しみください。";

const LINE_LABELS: Record<PalmLineKey, string> = {
  life: "生命線",
  head: "知能線",
  heart: "感情線",
  fate: "運命線",
};

const LINE_KEYS = Object.keys(LINE_LABELS) as PalmLineKey[];

const UNSAFE_PALMISTRY_CLAIM =
  /(?:病気|疾患|がん|癌|妊娠|不妊|障[がい碍害]|寿命|余命|死期|死亡|自殺|診断|医療|mental\s*health|diagnos(?:e|is)|lifespan|fertility|disabilit|death|suicid)/i;

const SAFE_REPLACEMENT =
  "この項目は安全上の理由で表示できません。手のひらの線の見え方だけを参考にしてください。";

export function normalizePalmHandSide(value: unknown): PalmHandSide | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "left" || normalized === "right") return normalized;
  return null;
}

export function decodePalmImageBase64(
  base64: string,
  mimeType: string,
): Uint8Array | null {
  let bytes: Uint8Array;
  try {
    const binary = atob(base64);
    bytes = Uint8Array.from(
      binary,
      (character) => character.charCodeAt(0),
    );
  } catch {
    return null;
  }
  if (bytes.length === 0 || bytes.length > 4 * 1024 * 1024) return null;

  const matchesMimeType = mimeType === "image/jpeg"
    ? bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[2] === 0xff
    : mimeType === "image/png"
    ? bytes.length >= 8 &&
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every(
        (value, index) => bytes[index] === value,
      )
    : mimeType === "image/webp"
    ? bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP"
    : false;
  return matchesMimeType ? bytes : null;
}

export function buildPalmReadingPrompt(
  handSide: PalmHandSide,
  previousAnalysis?: unknown,
): string {
  const previous = previousAnalysis === undefined || previousAnalysis === null
    ? "none"
    : JSON.stringify(previousAnalysis).slice(0, 12_000);
  return [
    "You are a careful Japanese palmistry entertainer analyzing one palm photo.",
    "Palmistry is not scientific or medical. Never diagnose disease, mental health, fertility, disability, lifespan, death, or future accidents.",
    "Never infer identity, name, exact age, gender, ethnicity, occupation, wealth, or other sensitive attributes from the image.",
    "Describe only visible palm creases and hand pose. Use gentle, non-deterministic wording and practical reflection prompts.",
    `The user selected ${handSide} hand. Treat that selection as authoritative because camera previews may be mirrored.`,
    "First judge whether the whole palm and the four major lines are sufficiently visible. If blur, glare, crop, shadow, or angle prevents a responsible reading, set photo_quality.is_usable=false and explain how to retake it.",
    "Return JSON only, with no Markdown fences or prose outside JSON.",
    '{"analysis":{"schema_version":1,"detected_hand":"left|right|unknown","photo_quality":{"score":0,"is_usable":true,"feedback":"日本語"},"overall":"日本語","traits":"日本語","love":"日本語","work":"日本語","advice":["日本語"],"lines":[{"key":"life|head|heart|fate","label":"日本語","visibility":0,"strength":0,"continuity":0,"shape":"日本語","interpretation":"日本語"}]},"comparison":{"has_previous":false,"confidence":"low|medium","summary":"日本語","caution":"日本語","changes":[{"key":"life|head|heart|fate","label":"日本語","direction":"stronger|stable|weaker|uncertain","detail":"日本語"}]}}',
    "All numeric scores are integers from 0 to 100 and describe only photographic visibility/appearance, not health, luck, worth, or lifespan.",
    "Return exactly one line entry for each key: life, head, heart, fate.",
    previous === "none"
      ? "There is no previous reading. comparison.has_previous must be false and changes must be empty."
      : "Compare conservatively with the previous structured reading below. Differences can come from lighting, focus, angle, hydration, or pose; say so in comparison.caution. Never claim permanent physical change from one comparison. Cap comparison confidence at medium.\nPREVIOUS_READING:\n" +
        previous,
    "Write all user-facing strings in natural Japanese.",
  ].join("\n");
}

export function parsePalmReadingResponse(
  raw: string,
  previousAvailable: boolean,
): PalmReadingPayload | null {
  const object = parseJsonObject(raw);
  if (!object) return null;
  return normalizePalmReadingPayload(object, previousAvailable);
}

export function normalizePalmReadingPayload(
  value: unknown,
  previousAvailable: boolean,
): PalmReadingPayload | null {
  const root = asRecord(value);
  const analysisRaw = asRecord(root?.analysis);
  if (!analysisRaw) return null;

  const qualityRaw = asRecord(analysisRaw.photo_quality);
  const qualityScore = clampInteger(qualityRaw?.score, 0, 100);
  const qualityUsable = qualityRaw?.is_usable === true && qualityScore >= 45;
  const overall = sanitizePalmistryText(analysisRaw.overall, 800);
  if (!overall && qualityUsable) return null;

  const rawLines = Array.isArray(analysisRaw.lines) ? analysisRaw.lines : [];
  const lineByKey = new Map<PalmLineKey, Record<string, unknown>>();
  for (const candidate of rawLines) {
    const item = asRecord(candidate);
    const key = normalizeLineKey(item?.key);
    if (item && key && !lineByKey.has(key)) lineByKey.set(key, item);
  }

  const analysis: PalmReadingAnalysis = {
    schema_version: 1,
    detected_hand: normalizePalmHandSide(analysisRaw.detected_hand) ??
      "unknown",
    photo_quality: {
      score: qualityScore,
      is_usable: qualityUsable,
      feedback: sanitizePalmistryText(qualityRaw?.feedback, 400) ||
        (qualityUsable
          ? "主要線を確認できる画質です。"
          : "手のひら全体を明るい場所で正面から撮り直してください。"),
    },
    overall: overall || "写真から十分な手相を読み取れませんでした。",
    traits: sanitizePalmistryText(analysisRaw.traits, 800),
    love: sanitizePalmistryText(analysisRaw.love, 800),
    work: sanitizePalmistryText(analysisRaw.work, 800),
    advice: normalizeTextList(analysisRaw.advice, 5, 240),
    lines: LINE_KEYS.map((key) => normalizeLine(key, lineByKey.get(key))),
    disclaimer: PALM_READING_DISCLAIMER,
  };

  return {
    analysis,
    comparison: normalizeComparison(root?.comparison, previousAvailable),
  };
}

function normalizeLine(
  key: PalmLineKey,
  value?: Record<string, unknown>,
): PalmLineReading {
  return {
    key,
    label: LINE_LABELS[key],
    visibility: clampInteger(value?.visibility, 0, 100),
    strength: clampInteger(value?.strength, 0, 100),
    continuity: clampInteger(value?.continuity, 0, 100),
    shape: sanitizePalmistryText(value?.shape, 240) || "判別が難しい",
    interpretation: sanitizePalmistryText(value?.interpretation, 600) ||
      "この写真では線の特徴を十分に判別できません。",
  };
}

function normalizeComparison(
  value: unknown,
  previousAvailable: boolean,
): PalmReadingComparison {
  const raw = asRecord(value);
  if (!previousAvailable) {
    return {
      has_previous: false,
      confidence: "low",
      summary: "同じ手の過去データがないため、今回が比較の基準になります。",
      caution: "次回も同じ明るさ・距離・角度で撮ると比較しやすくなります。",
      changes: [],
    };
  }

  const changes: PalmReadingComparison["changes"] = [];
  const rawChanges = Array.isArray(raw?.changes) ? raw.changes : [];
  for (const candidate of rawChanges.slice(0, 8)) {
    const item = asRecord(candidate);
    const key = normalizeLineKey(item?.key);
    if (!item || !key || changes.some((change) => change.key === key)) {
      continue;
    }
    changes.push({
      key,
      label: LINE_LABELS[key],
      direction: normalizeDirection(item.direction),
      detail: sanitizePalmistryText(item.detail, 500) ||
        "撮影条件の差もあるため、明確な変化とは断定できません。",
    });
  }

  return {
    has_previous: true,
    // 写真2枚だけの比較は、モデルが high と返しても medium を上限にする。
    confidence: String(raw?.confidence).toLowerCase() === "medium"
      ? "medium"
      : "low",
    summary: sanitizePalmistryText(raw?.summary, 800) ||
      "前回との違いは確認できますが、撮影条件の影響も考慮してください。",
    caution: sanitizePalmistryText(raw?.caution, 500) ||
      "線の見え方は光、角度、ピント、手の開き方でも変わります。",
    changes,
  };
}

function normalizeDirection(
  value: unknown,
): PalmReadingComparison["changes"][number]["direction"] {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (
    normalized === "stronger" || normalized === "stable" ||
    normalized === "weaker"
  ) {
    return normalized;
  }
  return "uncertain";
}

function normalizeLineKey(value: unknown): PalmLineKey | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  return LINE_KEYS.includes(normalized as PalmLineKey)
    ? normalized as PalmLineKey
    : null;
}

function normalizeTextList(
  value: unknown,
  maxItems: number,
  maxLength: number,
): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => sanitizePalmistryText(item, maxLength))
    .filter((item) => item.length > 0)
    .slice(0, maxItems);
}

function parseJsonObject(raw: string): Record<string, unknown> | null {
  const cleaned = raw
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return asRecord(JSON.parse(cleaned.slice(start, end + 1)));
  } catch {
    return null;
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function sanitizeText(value: unknown, maxLength: number): string {
  return String(value ?? "")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function sanitizePalmistryText(value: unknown, maxLength: number): string {
  const sanitized = sanitizeText(value, maxLength);
  return UNSAFE_PALMISTRY_CLAIM.test(sanitized) ? SAFE_REPLACEMENT : sanitized;
}

function clampInteger(value: unknown, min: number, max: number): number {
  const numeric = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(numeric)) return min;
  return Math.min(max, Math.max(min, Math.round(numeric)));
}
