// growth-hub dashboard.context の純粋ロジックとセクション別 degrade 制御。
// 非 X-operator でもダッシュボード全体の表示を壊さず、権限の無い
// xCandidateList のみ null + 理由へ degrade させ、他セクションと個別エラーを分離する。

export const DEFAULT_DASHBOARD_CANDIDATE_STATUSES = [
  "pending_approval",
  "approved",
  "publish_failed",
] as const;

export const X_OPERATOR_FORBIDDEN_REASON =
  "Forbidden: X operator role required";

export type DashboardSectionKey =
  | "xTodayStatus"
  | "xPerformanceContext"
  | "xCandidateList"
  | "achievementList";

export type DashboardSectionError = {
  code: "forbidden" | "unavailable";
  reason: string;
};

export type CandidateListTarget =
  | { mode: "batch"; statuses: string[] }
  | { mode: "single"; status: string };

export interface DashboardContextLoaders<
  TToday = Record<string, unknown>,
  TPerf = Record<string, unknown>,
  TCandidate = Record<string, unknown>,
  TAchievement = Record<string, unknown>,
> {
  loadXTodayStatus: () => Promise<TToday>;
  loadXPerformanceContext: () => Promise<TPerf>;
  loadXCandidateList: () => Promise<TCandidate>;
  loadAchievementList: () => Promise<TAchievement>;
}

export interface DashboardContextResult<
  TToday = Record<string, unknown>,
  TPerf = Record<string, unknown>,
  TCandidate = Record<string, unknown>,
  TAchievement = Record<string, unknown>,
> {
  success: true;
  isXOperator: boolean;
  xTodayStatus: TToday | null;
  xPerformanceContext: TPerf | null;
  xCandidateList: TCandidate | null;
  achievementList: TAchievement | null;
  errors: Partial<Record<DashboardSectionKey, DashboardSectionError>>;
}

export function normalizeCandidateBatchStatuses(
  rawStatuses: unknown,
  rawStatus: unknown,
): CandidateListTarget {
  if (Array.isArray(rawStatuses)) {
    const cleaned = (rawStatuses as unknown[])
      .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
      .filter((entry) => entry !== "");
    const statuses = [...new Set(cleaned)].slice(0, 10);
    if (statuses.length > 0) {
      return { mode: "batch", statuses };
    }
  }
  if (typeof rawStatus === "string" && rawStatus.trim() !== "") {
    return { mode: "single", status: rawStatus.trim() };
  }
  return {
    mode: "batch",
    statuses: [...DEFAULT_DASHBOARD_CANDIDATE_STATUSES],
  };
}

export async function buildDashboardContext<
  TToday = Record<string, unknown>,
  TPerf = Record<string, unknown>,
  TCandidate = Record<string, unknown>,
  TAchievement = Record<string, unknown>,
>(options: {
  isXOperator: boolean;
  loaders: DashboardContextLoaders<TToday, TPerf, TCandidate, TAchievement>;
  onSectionError?: (section: DashboardSectionKey, error: unknown) => void;
}): Promise<
  DashboardContextResult<TToday, TPerf, TCandidate, TAchievement>
> {
  const errors: Partial<Record<DashboardSectionKey, DashboardSectionError>> =
    {};

  const runSection = async <T>(
    section: DashboardSectionKey,
    loader: () => Promise<T>,
  ): Promise<T | null> => {
    try {
      return await loader();
    } catch (error) {
      options.onSectionError?.(section, error);
      errors[section] = {
        code: "unavailable",
        reason: `${section}_unavailable`,
      };
      return null;
    }
  };

  const candidatePromise: Promise<TCandidate | null> = options.isXOperator
    ? runSection("xCandidateList", options.loaders.loadXCandidateList)
    : (() => {
      errors.xCandidateList = {
        code: "forbidden",
        reason: X_OPERATOR_FORBIDDEN_REASON,
      };
      return Promise.resolve(null);
    })();

  const [
    xTodayStatus,
    xPerformanceContext,
    xCandidateList,
    achievementList,
  ] = await Promise.all([
    runSection("xTodayStatus", options.loaders.loadXTodayStatus),
    runSection("xPerformanceContext", options.loaders.loadXPerformanceContext),
    candidatePromise,
    runSection("achievementList", options.loaders.loadAchievementList),
  ]);

  return {
    success: true,
    isXOperator: options.isXOperator,
    xTodayStatus,
    xPerformanceContext,
    xCandidateList,
    achievementList,
    errors,
  };
}
