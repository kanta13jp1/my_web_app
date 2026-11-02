export type DailyBillingMetrics = {
  revenue: {
    mrrYen: number;
    currency: "JPY";
    basis: "active_list_price";
  };
  paid: {
    total: number;
    pro: number;
    team: number;
  };
};

const MONTHLY_LIST_PRICE_YEN = {
  pro: 980,
  team: 2_980,
} as const;

/**
 * Build an aggregate-only billing snapshot for the daily operations report.
 *
 * The source rows are never returned to callers. MRR is the current active
 * subscription count multiplied by the public monthly list price, so it must
 * not be presented as collected revenue.
 */
export function summarizeDailyBillingMetrics(
  rows: readonly unknown[],
): DailyBillingMetrics {
  let pro = 0;
  let team = 0;

  for (const raw of rows) {
    if (!raw || typeof raw !== "object") continue;
    const row = raw as Record<string, unknown>;
    if (row.status !== "active") continue;
    if (row.tier === "pro") pro += 1;
    if (row.tier === "team") team += 1;
  }

  return {
    revenue: {
      mrrYen: pro * MONTHLY_LIST_PRICE_YEN.pro +
        team * MONTHLY_LIST_PRICE_YEN.team,
      currency: "JPY",
      basis: "active_list_price",
    },
    paid: {
      total: pro + team,
      pro,
      team,
    },
  };
}
