import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ALT_SUPPLY_SOURCE,
  type AltSupplyDb,
  evaluateAltSupplyMetrics,
  handleAltSupplyAction,
} from "./alt_supply.ts";

function createInMemoryAltSupplyDb(): AltSupplyDb {
  let seq = 0;
  const rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];

  return {
    listScenarios(userId, limit) {
      const matched = rows
        .filter((r) => r.metadata.user_id === userId)
        .slice(0, limit);
      return Promise.resolve(matched);
    },

    insertScenario(userId, metadata) {
      seq += 1;
      const row = {
        id: `alt-${seq}`,
        source: ALT_SUPPLY_SOURCE,
        metadata: { ...metadata, user_id: userId },
        created_at: `2026-11-26T00:00:0${seq}Z`,
      };
      rows.unshift(row);
      return Promise.resolve(row);
    },

    findScenarioById(userId, id) {
      const match = rows.find(
        (r) => r.id === id && r.metadata.user_id === userId,
      );
      return Promise.resolve(match ?? null);
    },

    updateScenario(userId, id, metadata) {
      const idx = rows.findIndex(
        (r) => r.id === id && r.metadata.user_id === userId,
      );
      const updated = {
        ...rows[idx],
        metadata: { ...metadata, user_id: userId },
      };
      rows[idx] = updated;
      return Promise.resolve(updated);
    },
  };
}

Deno.test(
  "evaluateAltSupplyMetrics computes shortfall and MA escalation risk",
  () => {
    const highRisk = evaluateAltSupplyMetrics({
      stockpileTarget10kT: 100,
      domesticProcurement10kT: 60,
      stockpileThreshold10kT: 80,
      totalProductionTarget10kT: 800,
      currentProduction10kT: 730,
      maImportQuota10kT: 77,
    });
    assertEquals(highRisk.stockpile_shortfall_10k_t, 40);
    assertEquals(highRisk.below_procurement_threshold, true);
    assertEquals(highRisk.total_production_gap_10k_t, -70);
    assertEquals(highRisk.production_shortfall_10k_t, 70);
    assertEquals(
      highRisk.risk_level === "high" || highRisk.risk_level === "critical",
      true,
    );

    const stable = evaluateAltSupplyMetrics({
      stockpileTarget10kT: 100,
      domesticProcurement10kT: 98,
      stockpileThreshold10kT: 80,
      totalProductionTarget10kT: 800,
      currentProduction10kT: 805,
      maImportQuota10kT: 77,
    });
    assertEquals(stable.stockpile_shortfall_10k_t, 2);
    assertEquals(stable.below_procurement_threshold, false);
    assertEquals(stable.total_production_gap_10k_t, 5);
    assertEquals(stable.risk_level, "elevated");
  },
);

Deno.test(
  "alt_supply CRUD seeds idempotently and isolates user ownership",
  async () => {
    const db = createInMemoryAltSupplyDb();

    const firstSeed = await handleAltSupplyAction({
      action: "alt_supply.seed_defaults",
      body: {},
      userId: "user-1",
      db,
    });
    assertEquals(firstSeed.status, 200);
    assertEquals(firstSeed.body.seeded, 2);

    const secondSeed = await handleAltSupplyAction({
      action: "alt_supply.seed_defaults",
      body: {},
      userId: "user-1",
      db,
    });
    assertEquals(secondSeed.status, 200);
    assertEquals(secondSeed.body.seeded, 0);

    const badCreate = await handleAltSupplyAction({
      action: "alt_supply.create",
      body: { title: "Bad", domestic_procurement_10k_t: -5 },
      userId: "user-1",
      db,
    });
    assertEquals(badCreate.status, 400);

    const created = await handleAltSupplyAction({
      action: "alt_supply.create",
      body: {
        title: "2027年 検証シナリオ",
        stockpile_target_10k_t: 100,
        domestic_procurement_10k_t: 55,
        stockpile_threshold_10k_t: 80,
        total_production_target_10k_t: 810,
        current_production_10k_t: 750,
        source_kind: "open_data_sync",
      },
      userId: "user-1",
      db,
    });
    assertEquals(created.status, 200);
    const scenario = created.body.scenario as Record<string, unknown>;
    assertExists(scenario.id);
    assertEquals(scenario.stockpile_shortfall_10k_t, 45);
    assertEquals(scenario.below_procurement_threshold, true);

    const crossUserUpdate = await handleAltSupplyAction({
      action: "alt_supply.update",
      body: { id: scenario.id, domestic_procurement_10k_t: 100 },
      userId: "user-2",
      db,
    });
    assertEquals(crossUserUpdate.status, 404);

    const ownerUpdate = await handleAltSupplyAction({
      action: "alt_supply.update",
      body: { id: scenario.id, domestic_procurement_10k_t: 100 },
      userId: "user-1",
      db,
    });
    assertEquals(ownerUpdate.status, 200);
    const updated = ownerUpdate.body.scenario as Record<string, unknown>;
    assertEquals(updated.stockpile_shortfall_10k_t, 0);
    assertEquals(updated.below_procurement_threshold, false);
  },
);
