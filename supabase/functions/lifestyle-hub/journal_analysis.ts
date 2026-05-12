export interface JournalAnalysisInput {
  note: string;
  moodScore?: number;
  stressScore?: number;
  sleepHours?: number;
}

export interface JournalInsight {
  summary: string;
  emotion_tags: string[];
  trigger_tags: string[];
  next_actions: string[];
  risk_level: "low" | "medium" | "high";
  focus_area: "spending" | "health" | "mental" | "work" | "general";
}

const keywordGroups = {
  spending: [
    "浪費",
    "支出",
    "購入",
    "買",
    "課金",
    "セール",
    "amazon",
    "馬券",
    "ギャンブル",
  ],
  health: ["睡眠", "眠", "疲", "体調", "食", "運動", "痛", "薬", "体重"],
  mental: ["不安", "焦", "怒", "つら", "落ち込", "孤独", "ストレス"],
  work: ["仕事", "締切", "会議", "開発", "レビュー", "実装", "タスク"],
} as const;

function includesAny(text: string, words: readonly string[]): boolean {
  const lower = text.toLowerCase();
  return words.some((word) => lower.includes(word.toLowerCase()));
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.trim().length > 0))];
}

export function buildJournalInsight(
  input: JournalAnalysisInput,
): JournalInsight {
  const note = input.note.trim();
  const mood = Number(input.moodScore ?? 3);
  const stress = Number(input.stressScore ?? 3);
  const sleep = Number(input.sleepHours ?? 7);

  const triggerTags: string[] = [];
  if (includesAny(note, keywordGroups.spending)) {
    triggerTags.push("支出トリガー");
  }
  if (includesAny(note, keywordGroups.health)) triggerTags.push("健康トリガー");
  if (includesAny(note, keywordGroups.mental)) triggerTags.push("感情トリガー");
  if (includesAny(note, keywordGroups.work)) triggerTags.push("仕事トリガー");
  if (stress >= 4) triggerTags.push("高ストレス");
  if (sleep <= 5) triggerTags.push("睡眠不足");

  const emotionTags: string[] = [];
  if (mood <= 2) emotionTags.push("低調");
  if (mood >= 4) emotionTags.push("前向き");
  if (stress >= 4) emotionTags.push("緊張");
  if (stress <= 2) emotionTags.push("安定");
  if (triggerTags.length === 0) emotionTags.push("観察中");

  const focusArea: JournalInsight["focus_area"] = triggerTags.includes(
      "支出トリガー",
    )
    ? "spending"
    : triggerTags.includes("健康トリガー") || triggerTags.includes("睡眠不足")
    ? "health"
    : triggerTags.includes("感情トリガー") || triggerTags.includes("高ストレス")
    ? "mental"
    : triggerTags.includes("仕事トリガー")
    ? "work"
    : "general";

  const nextActions: string[] = [];
  if (focusArea === "spending") {
    nextActions.push("明日の購入判断は24時間保留して、必要性を1行で記録する");
  }
  if (focusArea === "health") {
    nextActions.push(
      "明日は就寝予定時刻を先に決め、睡眠前30分の画面時間を減らす",
    );
  }
  if (focusArea === "mental") {
    nextActions.push(
      "朝に5分だけ感情ログを書き、強い反応の前後関係を分けて見る",
    );
  }
  if (focusArea === "work") {
    nextActions.push(
      "最初の作業を15分で終わる単位に分け、開始前に完了条件を書く",
    );
  }
  nextActions.push("今日の気づきを1つだけ明日の最優先タスクに反映する");

  const riskScore = (mood <= 2 ? 1 : 0) + (stress >= 4 ? 1 : 0) +
    (sleep <= 5 ? 1 : 0) + (triggerTags.length >= 2 ? 1 : 0);
  const riskLevel: JournalInsight["risk_level"] = riskScore >= 3
    ? "high"
    : riskScore >= 1
    ? "medium"
    : "low";

  const summary = triggerTags.length > 0
    ? `今日の記録では${
      triggerTags.join("・")
    }が目立ちます。明日は小さな先回り行動に落とすと再現性が上がります。`
    : "今日の記録は大きな乱れが少なく、継続観察に向いています。明日は良かった行動を1つだけ再現しましょう。";

  return {
    summary,
    emotion_tags: unique(emotionTags),
    trigger_tags: unique(triggerTags),
    next_actions: unique(nextActions).slice(0, 3),
    risk_level: riskLevel,
    focus_area: focusArea,
  };
}

export function extractFirstJsonObject(
  text: string,
): Record<string, unknown> | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(text.slice(start, end + 1));
    return parsed && typeof parsed === "object"
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return unique(value.map((item) => String(item).trim()));
}

export function coerceJournalInsight(
  raw: Record<string, unknown> | null,
  fallback: JournalInsight,
): JournalInsight {
  if (!raw) return fallback;
  const risk = String(raw.risk_level ?? fallback.risk_level);
  const focus = String(raw.focus_area ?? fallback.focus_area);
  return {
    summary: String(raw.summary ?? fallback.summary).trim() || fallback.summary,
    emotion_tags: stringArray(raw.emotion_tags).length > 0
      ? stringArray(raw.emotion_tags)
      : fallback.emotion_tags,
    trigger_tags: stringArray(raw.trigger_tags).length > 0
      ? stringArray(raw.trigger_tags)
      : fallback.trigger_tags,
    next_actions: stringArray(raw.next_actions).length > 0
      ? stringArray(raw.next_actions).slice(0, 3)
      : fallback.next_actions,
    risk_level: risk === "high" || risk === "medium" || risk === "low"
      ? risk
      : fallback.risk_level,
    focus_area:
      focus === "spending" || focus === "health" || focus === "mental" ||
        focus === "work" || focus === "general"
        ? focus
        : fallback.focus_area,
  };
}
