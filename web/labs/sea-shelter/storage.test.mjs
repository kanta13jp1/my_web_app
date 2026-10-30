import { test } from "node:test";
import assert from "node:assert/strict";
import { act, decode, initialState, neighbors } from "./model.mjs";
import {
  BASE_CAP,
  changeResources,
  resourceLimit,
  resourceTotal,
} from "./storage.mjs";
import {
  act as oldAct,
  decode as oldDecode,
} from "../../../test/fixtures/sea_shelter_v2269/model.mjs";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

test("frozen rollback fixtures are the exact released model and farm blobs", () => {
  for (
    const [name, expected] of [[
      "model.mjs",
      "6ccd76f091317327b3d4472f0355119c188f2302",
    ], ["farm.mjs", "440f60406b88de0699462107f85f270a2b410ebc"]]
  ) {
    const data = readFileSync(
      new URL(
        `../../../test/fixtures/sea_shelter_v2269/${name}`,
        import.meta.url,
      ),
    );
    const hash = createHash("sha1").update(`blob ${data.length}\0`).update(data)
      .digest("hex");
    assert.equal(hash, expected);
  }
});

test("a warehouse uses the existing dock even on a full map without changing XP or population", () => {
  let s = initialState();
  s.wood = BASE_CAP;
  s.metal = BASE_CAP;
  s.xp = 123;
  while (s.tiles.length < 25) {
    let added = false;
    for (let y = 0; y < 5 && !added; y++) {
      for (let x = 0; x < 5 && !added; x++) {
        if (
          !s.tiles.some((t) => t.x === x && t.y === y) && neighbors(s, x, y)
        ) {
          s = act(s, { type: "build", kind: "deck", x, y }).state;
          added = true;
        }
      }
    }
    assert.equal(added, true);
  }
  const before = structuredClone(s);
  const r = act(s, { type: "build-warehouse" });
  assert.equal(r.changed, true);
  assert.deepEqual(r.state.tiles, before.tiles);
  assert.equal(r.state.xp, before.xp);
  assert.equal(r.state.residents, before.residents);
  assert.equal(resourceTotal(r.state, "wood"), before.wood - 30);
  assert.equal(resourceTotal(r.state, "metal"), before.metal - 15);
  assert.equal(resourceLimit(r.state), BASE_CAP * 2);
  assert.equal(act(r.state, { type: "build-warehouse" }).changed, false);
});

test("warehouse shortage and repeated building never spend partial costs", () => {
  const s = initialState();
  s.wood = 29;
  s.metal = 15;
  const snapshot = JSON.stringify(s);
  assert.equal(act(s, { type: "build-warehouse" }).changed, false);
  assert.equal(JSON.stringify(s), snapshot);
  s.wood++;
  const built = act(s, { type: "build-warehouse" }).state;
  assert.equal(built.wood, 0);
  assert.equal(built.metal, 0);
  assert.equal(built.xp, 0);
  assert.equal(built.residents, 1);
  assert.deepEqual(act(built, { type: "build-warehouse" }).state, built);
});

test("free collection reports only accepted amounts and all-full collection changes nothing", () => {
  const s = initialState();
  s.wood = BASE_CAP - 1;
  s.metal = BASE_CAP;
  const r = act(s, { type: "collect" });
  assert.equal(r.state.wood, BASE_CAP);
  assert.equal(r.state.metal, BASE_CAP);
  assert.match(r.message, /木材 \+1 \/ 金属 \+0/);
  assert.match(r.message, /回収していません/);
  const full = act(r.state, { type: "collect" });
  assert.equal(full.changed, false);
  assert.equal(full.remedy, "storage");
  assert.deepEqual(full.state, r.state);
});

test("expanded quantities survive actual old-code decode and spending then return without truncation", () => {
  const s = initialState();
  s.wood = 40;
  s.metal = 20;
  const built = act(s, { type: "build-warehouse" }).state;
  changeResources(built, {
    wood: 150000 - built.wood,
    metal: 150000 - built.metal,
    food: 150000,
  });
  const old = oldDecode(JSON.stringify(built));
  assert.equal(old.wood, BASE_CAP);
  assert.equal(old.farm.food, BASE_CAP);
  assert.equal(old.storage.reserve.wood, 150000 - BASE_CAP);
  const spent = oldAct(old, { type: "build", kind: "deck", x: 3, y: 2 });
  assert.equal(spent.changed, true);
  const back = decode(JSON.stringify(spent.state));
  assert.equal(resourceTotal(back, "wood"), 149996);
  assert.equal(resourceTotal(back, "metal"), 150000);
  assert.equal(resourceTotal(back, "food"), 150000);
  assert.equal(back.storage.built, true);
});

test("harvest and paid delivery are atomic at capacity; explicit sharing can clear food room", () => {
  const s = initialState();
  s.storage.built = true;
  changeResources(s, {
    wood: BASE_CAP * 2,
    metal: BASE_CAP * 2,
    food: BASE_CAP * 2 - 2,
  });
  s.tiles.push({ x: 3, y: 2, kind: "garden" });
  s.farm.crops["3,2"] = 1000;
  const snapshot = JSON.stringify(s);
  assert.equal(act(s, { type: "harvest", x: 3, y: 2 }, 61000).changed, false);
  assert.equal(act(s, { type: "donate-food" }).changed, false);
  assert.equal(JSON.stringify(s), snapshot);
  const shared = act(s, { type: "share-food" }).state;
  assert.equal(resourceTotal(shared, "food"), BASE_CAP * 2 - 5);
  assert.equal(shared.xp, s.xp);
  const harvested = act(shared, { type: "harvest", x: 3, y: 2 }, 61000).state;
  assert.equal(resourceTotal(harvested, "food"), BASE_CAP * 2 - 2);
  assert.equal(harvested.farm.crops["3,2"], undefined);
  assert.equal(
    act(harvested, { type: "harvest", x: 3, y: 2 }, 61000).changed,
    false,
  );
  changeResources(harvested, { wood: -4, metal: -1 });
  const delivered = act(harvested, { type: "donate-food" }).state;
  assert.equal(resourceTotal(delivered, "wood"), BASE_CAP * 2);
  assert.equal(resourceTotal(delivered, "metal"), BASE_CAP * 2);
  assert.equal(resourceTotal(delivered, "food"), BASE_CAP * 2 - 5);
  assert.equal(delivered.xp, 2);
});

test("legacy saves migrate without reducing quantities and invalid extension recovery keeps valid reserves", () => {
  const old = initialState();
  old.wood = BASE_CAP;
  old.metal = BASE_CAP;
  delete old.storage;
  const migrated = decode(JSON.stringify(old));
  assert.equal(resourceTotal(migrated, "wood"), BASE_CAP);
  assert.equal(migrated.storage.built, false);
  migrated.storage = {
    version: 1,
    built: false,
    reserve: { wood: 77, metal: -1, food: 9 },
  };
  assert.throws(() => decode(JSON.stringify(migrated)), (error) => {
    assert.equal(resourceTotal(error.recoveredState, "wood"), BASE_CAP + 77);
    assert.equal(resourceTotal(error.recoveredState, "metal"), BASE_CAP);
    assert.equal(resourceTotal(error.recoveredState, "food"), 9);
    assert.equal(error.recoveredState.storage.built, true);
    assert.match(error.recoveryMessage, /倉庫/);
    return true;
  });
});

test("invalid resource transactions do not clamp or partially mutate resources", () => {
  const s = initialState();
  const snapshot = JSON.stringify(s);
  assert.throws(() => changeResources(s, { wood: BASE_CAP + 1, metal: 2 }));
  assert.equal(JSON.stringify(s), snapshot);
  assert.throws(() => changeResources(s, { food: -1 }));
  assert.equal(JSON.stringify(s), snapshot);
});
