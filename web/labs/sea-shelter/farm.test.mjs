import { test } from "node:test";
import assert from "node:assert/strict";
import { act, decode, initialState } from "./model.mjs";
import { GROW_MS } from "./farm.mjs";
const now = 1800000000000;
function garden() {
  const s = initialState();
  s.wood = 20;
  s.metal = 10;
  s.xp = 24;
  return act(s, { type: "build", kind: "garden", x: 3, y: 2 }).state;
}
const plant = { type: "plant", x: 3, y: 2 };
const harvest = { ...plant, type: "harvest" };
test("plant, offline restore, one harvest and resident delivery form a resource loop", () => {
  const s = act(garden(), plant, now).state;
  assert.equal(s.wood, 8);
  assert.equal(act(s, harvest, now + GROW_MS - 1).changed, false);
  const restored = decode(JSON.stringify(s));
  const grown = act(restored, harvest, now + GROW_MS).state;
  assert.equal(grown.farm.food, 3);
  assert.equal(act(grown, harvest, now + GROW_MS).changed, false);
  const delivered = act(grown, { type: "donate-food" }).state;
  assert.equal(delivered.farm.food, 0);
  assert.equal(delivered.wood, 12);
  assert.equal(delivered.metal, 6);
  assert.equal(act(delivered, { type: "donate-food" }).changed, false);
});
test("shortage, occupied crop and replacement protect resources", () => {
  const empty = garden();
  empty.wood = 1;
  assert.equal(act(empty, plant, now).changed, false);
  const s = act(garden(), plant, now).state;
  assert.equal(act(s, plant, now).changed, false);
  assert.equal(
    act(s, { type: "build", kind: "deck", x: 3, y: 2 }).changed,
    false,
  );
  assert.equal(act(s, { type: "harvest", x: 0, y: 0 }, now).changed, false);
});
test("invalid and backward clocks do not pay; large jumps restart without reward", () => {
  const s = act(garden(), plant, now).state;
  for (const clock of [NaN, Infinity, -1, now - 1]) {
    assert.equal(act(s, harvest, clock).changed, false);
  }
  const restarted = act(s, harvest, now + 8 * 86400000);
  assert.equal(restarted.changed, true);
  assert.equal(restarted.state.farm.food, 0);
  assert.equal(
    act(restarted.state, harvest, now + 8 * 86400000).changed,
    false,
  );
});
test("old saves migrate and corrupt farm storage is rejected", () => {
  const legacy = garden();
  delete legacy.farm;
  assert.deepEqual(decode(JSON.stringify(legacy)).farm, {
    food: 0,
    harvested: 0,
    crops: {},
  });
  for (
    const farm of [null, { food: -1 }, {
      food: 0,
      harvested: 0,
      crops: { "0,0": now },
    }, { food: 0, harvested: 0, crops: { "3,2": -1 } }]
  ) {
    assert.throws(
      () => decode(JSON.stringify({ ...garden(), farm })),
      (error) => {
        assert.equal(error.recoveredState.wood, garden().wood);
        assert.deepEqual(error.recoveredState.tiles, garden().tiles);
        assert.equal(error.recoveredState.farm.food, 0);
        return true;
      },
    );
  }
});
