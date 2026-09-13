import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { summarizeDailyBillingMetrics } from "./daily_billing_metrics.ts";

Deno.test("daily billing snapshot counts active paid plans and list-price MRR", () => {
  assertEquals(
    summarizeDailyBillingMetrics([
      { tier: "pro", status: "active" },
      { tier: "pro", status: "active" },
      { tier: "team", status: "active" },
      { tier: "free", status: "active" },
      { tier: "team", status: "trialing" },
      { tier: "pro", status: "canceled" },
      null,
    ]),
    {
      revenue: {
        mrrYen: 4_940,
        currency: "JPY",
        basis: "active_list_price",
      },
      paid: { total: 3, pro: 2, team: 1 },
    },
  );
});

Deno.test("daily billing snapshot represents no active subscribers as zero", () => {
  assertEquals(summarizeDailyBillingMetrics([]), {
    revenue: {
      mrrYen: 0,
      currency: "JPY",
      basis: "active_list_price",
    },
    paid: { total: 0, pro: 0, team: 0 },
  });
});
