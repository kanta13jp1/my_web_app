import {
  anonymizedHouseholdCount,
  buildHouseholdTrackerReport,
  daysUntilSalaryDay,
  parseHouseholdTrackerConsent,
  parseHouseholdTrackerMirror,
  salaryCyclePhase,
} from "./x_household_tracker.ts";

function assert(
  condition: unknown,
  message = "assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

const mirror = {
  schema_version: 1,
  observed_at: "2026-07-12T00:30:00.000Z",
  monitored_accounts: 4,
  balance_increasing: 1,
  negative_amortization: 0,
  slow_payoff: 2,
  critical_count: 1,
  warning_count: 2,
  salary_day: 25,
  salary_day_configured: true,
};

Deno.test("household mirror parser is allowlist/fail-closed", () => {
  const parsed = parseHouseholdTrackerMirror(mirror);
  assert(parsed !== null);
  assertEquals(parsed.monitoredAccounts, 4);
  assertEquals(
    parseHouseholdTrackerMirror({ ...mirror, salary_day: 31 }),
    null,
  );
  assertEquals(
    parseHouseholdTrackerMirror({ ...mirror, critical_count: -1 }),
    null,
  );
  assertEquals(
    parseHouseholdTrackerConsent({ schema_version: 1, enabled: true }),
    true,
  );
  assertEquals(parseHouseholdTrackerConsent({ enabled: true }), null);
});

Deno.test("small cells and salary dates are bucketed", () => {
  assertEquals(anonymizedHouseholdCount(0), "0件");
  assertEquals(anonymizedHouseholdCount(1), "1〜2件");
  assertEquals(anonymizedHouseholdCount(2), "1〜2件");
  assertEquals(anonymizedHouseholdCount(3), "3〜5件");
  assertEquals(anonymizedHouseholdCount(8), "6〜10件");
  assertEquals(anonymizedHouseholdCount(12), "11件以上");
  assertEquals(
    daysUntilSalaryDay(new Date("2026-07-12T03:00:00Z"), 25),
    13,
  );
  assertEquals(
    salaryCyclePhase(new Date("2026-07-12T03:00:00Z"), 25),
    "給料日まで1〜2週間",
  );
});

Deno.test("report is post-A scoreboard without exact private cells", () => {
  const report = buildHouseholdTrackerReport(
    mirror,
    new Date("2026-07-12T03:00:00Z"),
  );
  assertEquals(report.available, true);
  const text = report.text ?? "";
  assert(text.includes("家計トラッカー 2026/07/12"));
  assert(text.includes("負債トレンド検出: 3〜5件"));
  assert(text.includes("残高増加 1〜2件"));
  assert(text.includes("給料日サイクル: 給料日まで1〜2週間"));
  assert(!text.includes("毎月25日"));
  assert(!text.includes("00:30"));
  assert(!text.includes("円"));
});

Deno.test("unconfigured, stale, and future snapshots skip", () => {
  assertEquals(
    buildHouseholdTrackerReport(
      { ...mirror, salary_day_configured: false },
      new Date("2026-07-12T03:00:00Z"),
    ).reason,
    "salary_day_not_configured",
  );
  assertEquals(
    buildHouseholdTrackerReport(
      { ...mirror, observed_at: "2026-07-01T00:00:00Z" },
      new Date("2026-07-12T03:00:00Z"),
    ).reason,
    "stale_snapshot",
  );
  assertEquals(
    buildHouseholdTrackerReport(
      { ...mirror, observed_at: "2026-07-13T00:00:00Z" },
      new Date("2026-07-12T03:00:00Z"),
    ).reason,
    "snapshot_from_future",
  );
});
