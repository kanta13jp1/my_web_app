export type HabitResourceMetric = {
  habit_id: string;
  habit_title: string;
  goal_title: string | null;
  sample_count: number;
  avg_time_minutes: number;
  avg_fatigue_score: number;
  avg_goal_contribution_score: number;
  performance_measurement_source: string;
  performance_is_proxy: boolean;
  performance_sample_stddev: number | null;
  has_sufficient_data: boolean;
  insufficient_data_reason: string | null;
  resource_cost_index: number;
  efficiency_score: number;
  time_performance_correlation: number | null;
  fatigue_performance_correlation: number | null;
  overall_time_performance_correlation: number | null;
  overall_fatigue_performance_correlation: number | null;
  is_pareto_optimal: boolean;
};

export const MIN_ANALYSIS_SAMPLE_COUNT = 7;

export type MentorRecommendation = {
  habit_id: string;
  title: string;
  reason: string;
};

export type ScalingPlanStep = {
  stage: number;
  duration_days: number;
  load_multiplier: number;
  target: string;
  guardrail: string;
};

export type MentorPlan = {
  mentor_summary: string;
  recommendations: MentorRecommendation[];
  scaling_plan: ScalingPlanStep[];
};

const numberOr = (value: unknown, fallback = 0): number => {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const correlationOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === "") return null;
  const parsed = numberOr(value, Number.NaN);
  return Number.isFinite(parsed) ? clamp(parsed, -1, 1) : null;
};

const clamp = (value: number, min: number, max: number): number =>
  Math.min(max, Math.max(min, value));

const boundedText = (
  value: unknown,
  fallback: string,
  maxLength = 120,
): string => {
  const text = String(value ?? "").trim();
  return (text || fallback).slice(0, maxLength);
};

const optionalBoundedText = (value: unknown): string | null => {
  if (value === null || value === undefined) return null;
  const text = String(value).trim().slice(0, 120);
  return text || null;
};

export function normalizeMetrics(rows: unknown): HabitResourceMetric[] {
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((row): row is Record<string, unknown> =>
      Boolean(row) && typeof row === "object"
    )
    .map((row) => {
      const sampleCount = Math.max(
        0,
        Math.trunc(numberOr(row.sample_count)),
      );
      const performanceSampleStddev = row.performance_sample_stddev === null ||
          row.performance_sample_stddev === undefined
        ? null
        : Math.max(0, numberOr(row.performance_sample_stddev));
      const performanceMeasurementSource = boundedText(
        row.performance_measurement_source,
        "unknown",
      );
      return {
        habit_id: String(row.habit_id ?? ""),
        habit_title: boundedText(row.habit_title, "名称未設定の習慣"),
        goal_title: optionalBoundedText(row.goal_title),
        sample_count: sampleCount,
        avg_time_minutes: clamp(numberOr(row.avg_time_minutes), 0, 1440),
        avg_fatigue_score: clamp(numberOr(row.avg_fatigue_score), 0, 10),
        avg_goal_contribution_score: clamp(
          numberOr(row.avg_goal_contribution_score),
          0,
          100,
        ),
        performance_measurement_source: performanceMeasurementSource,
        performance_is_proxy: row.performance_is_proxy === true,
        performance_sample_stddev: performanceSampleStddev,
        has_sufficient_data: row.has_sufficient_data === true &&
          performanceMeasurementSource ===
            "self_reported_goal_contribution_proxy" &&
          sampleCount >= MIN_ANALYSIS_SAMPLE_COUNT &&
          performanceSampleStddev !== null && performanceSampleStddev > 0,
        insufficient_data_reason: optionalBoundedText(
          row.insufficient_data_reason,
        ),
        resource_cost_index: Math.max(0, numberOr(row.resource_cost_index)),
        efficiency_score: Math.max(0, numberOr(row.efficiency_score)),
        time_performance_correlation: correlationOrNull(
          row.time_performance_correlation,
        ),
        fatigue_performance_correlation: correlationOrNull(
          row.fatigue_performance_correlation,
        ),
        overall_time_performance_correlation: correlationOrNull(
          row.overall_time_performance_correlation,
        ),
        overall_fatigue_performance_correlation: correlationOrNull(
          row.overall_fatigue_performance_correlation,
        ),
        is_pareto_optimal: row.is_pareto_optimal === true,
      };
    })
    .filter((metric) => metric.habit_id.length > 0);
}

export function findParetoFrontier(
  metrics: HabitResourceMetric[],
): HabitResourceMetric[] {
  const eligible = metrics.filter((metric) => metric.has_sufficient_data);
  return eligible.filter((candidate) =>
    !eligible.some((competitor) =>
      competitor.habit_id !== candidate.habit_id &&
      competitor.avg_time_minutes <= candidate.avg_time_minutes &&
      competitor.avg_fatigue_score <= candidate.avg_fatigue_score &&
      competitor.avg_goal_contribution_score >=
        candidate.avg_goal_contribution_score &&
      (
        competitor.avg_time_minutes < candidate.avg_time_minutes ||
        competitor.avg_fatigue_score < candidate.avg_fatigue_score ||
        competitor.avg_goal_contribution_score >
          candidate.avg_goal_contribution_score
      )
    )
  );
}

export function buildFallbackMentorPlan(
  metrics: HabitResourceMetric[],
): MentorPlan {
  const frontier = findParetoFrontier(metrics)
    .sort((a, b) => b.efficiency_score - a.efficiency_score)
    .slice(0, 5);
  if (frontier.length === 0) {
    const hasRecordedMetrics = metrics.length > 0;
    return {
      mentor_summary: hasRecordedMetrics
        ? "記録はありますが、分析には習慣ごとに7件以上かつ成果と時間または疲労度の変動が必要です。目標貢献度は実目標進捗ではなく自己申告proxyとして扱います。現時点では相関、パレート推奨、負荷拡大を断定できません。"
        : "分析に必要な実績がまだありません。習慣を完了するときに時間、疲労度、目標貢献度を記録してください。目標貢献度は自己申告proxyとして扱われます。",
      recommendations: [],
      scaling_plan: [],
    };
  }

  const lead = frontier[0];
  const recommendations = frontier.map((metric) => ({
    habit_id: metric.habit_id,
    title: metric.habit_title,
    reason:
      `平均${metric.avg_time_minutes.toFixed(0)}分・疲労度${
        metric.avg_fatigue_score.toFixed(1)
      }で` +
      `自己申告の目標貢献度proxy${
        metric.avg_goal_contribution_score.toFixed(0)
      }を記録し、他の候補に支配されない効率です。`,
  }));
  return {
    mentor_summary:
      `「${lead.habit_title}」を基準行動にすると、少ない資源で成果を伸ばしやすい状態です。` +
      "疲労度が上がった週は負荷を戻し、成果の再現性を優先してください。",
    recommendations,
    scaling_plan: [
      {
        stage: 1,
        duration_days: 7,
        load_multiplier: 1,
        target:
          `${lead.habit_title}を現在の負荷で継続し、実績を7件まで蓄積する`,
        guardrail: "疲労度が7以上の日は時間を増やさない",
      },
      {
        stage: 2,
        duration_days: 14,
        load_multiplier: 1.1,
        target: "平均目標貢献度を維持したまま負荷を10%だけ増やす",
        guardrail: "目標貢献度が前週比で下がったら第1段階へ戻す",
      },
      {
        stage: 3,
        duration_days: 21,
        load_multiplier: 1.2,
        target: "再現性が確認できたパレート最適習慣だけを20%まで拡張する",
        guardrail: "時間または疲労度が20%以上増えたら拡張を停止する",
      },
    ],
  };
}

export function extractJsonObject(
  text: string,
): Record<string, unknown> | null {
  const trimmed = text.trim().replace(/^```(?:json)?\s*/i, "").replace(
    /\s*```$/,
    "",
  );
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(trimmed.slice(start, end + 1));
    return parsed && typeof parsed === "object"
      ? parsed as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

export function normalizeMentorPlan(
  raw: Record<string, unknown> | null,
  metrics: HabitResourceMetric[],
): MentorPlan {
  const fallback = buildFallbackMentorPlan(metrics);
  if (!raw) return fallback;
  if (findParetoFrontier(metrics).length === 0) return fallback;
  const frontier = new Map(
    findParetoFrontier(metrics).map((metric) => [metric.habit_id, metric]),
  );
  const rawRecommendations = Array.isArray(raw.recommendations)
    ? raw.recommendations
    : [];
  const recommendations = rawRecommendations
    .filter((item): item is Record<string, unknown> =>
      Boolean(item) && typeof item === "object"
    )
    .map((item) => {
      const metric = frontier.get(String(item.habit_id ?? ""));
      if (!metric) return null;
      return {
        habit_id: metric.habit_id,
        title: metric.habit_title,
        reason: String(item.reason ?? "").trim().slice(0, 300),
      };
    })
    .filter((item): item is MentorRecommendation =>
      item !== null && item.reason.length > 0
    )
    .slice(0, 5);

  const rawSteps = Array.isArray(raw.scaling_plan) ? raw.scaling_plan : [];
  const scalingPlan = rawSteps
    .filter((item): item is Record<string, unknown> =>
      Boolean(item) && typeof item === "object"
    )
    .map((item, index) => ({
      stage: index + 1,
      duration_days: Math.trunc(clamp(numberOr(item.duration_days, 7), 3, 30)),
      load_multiplier: clamp(numberOr(item.load_multiplier, 1), 0.8, 1.25),
      target: String(item.target ?? "").trim().slice(0, 300),
      guardrail: String(item.guardrail ?? "").trim().slice(0, 300),
    }))
    .filter((item) => item.target.length > 0 && item.guardrail.length > 0)
    .slice(0, 3);
  const hasGradualScaling = scalingPlan.length === 3 &&
    scalingPlan[1].load_multiplier >= scalingPlan[0].load_multiplier &&
    scalingPlan[2].load_multiplier >= scalingPlan[1].load_multiplier &&
    scalingPlan[2].load_multiplier > scalingPlan[0].load_multiplier;

  const mentorSummary = String(raw.mentor_summary ?? "").trim().slice(0, 600);
  return {
    mentor_summary: mentorSummary || fallback.mentor_summary,
    recommendations: recommendations.length > 0
      ? recommendations
      : fallback.recommendations,
    scaling_plan: hasGradualScaling ? scalingPlan : fallback.scaling_plan,
  };
}
