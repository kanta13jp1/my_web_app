import { test } from "node:test";
import assert from "node:assert/strict";
import { act, capacity, decode, initialState } from "./model.mjs";

function journey() {
  let s = initialState();
  const run = (a) => {
    const r = act(s, a);
    assert.equal(r.changed, true, r.message);
    s = r.state;
  };
  for (let i = 0; i < 3; i++) run({ type: "collect" });
  run({ type: "claim", id: "supplies" });
  run({ type: "build", kind: "home", x: 3, y: 2 });
  run({ type: "claim", id: "shelter" });
  for (let i = 0; i < 5; i++) run({ type: "collect" });
  run({ type: "invite" });
  run({ type: "invite" });
  run({ type: "build", kind: "garden", x: 2, y: 3 });
  run({ type: "claim", id: "community" });
  return s;
}
test("three requests are reachable and save round trips preserve progress", () => {
  const s = journey();
  assert.equal(s.claimed.length, 3);
  assert.equal(s.residents, 3);
  assert.deepEqual(decode(JSON.stringify(s)), s);
  assert.equal(act(s, { type: "collect" }).state.wood - s.wood, 4);
});
test("shortage, locked facilities and remote/occupied cells never spend resources", () => {
  const s = initialState();
  for (
    const a of [
      { type: "build", kind: "home", x: 3, y: 2 },
      { type: "build", kind: "deck", x: 3, y: 2 },
      { type: "build", kind: "deck", x: 0, y: 0 },
      { type: "build", kind: "deck", x: 2, y: 2 },
      { type: "invite" },
      { type: "claim", id: "supplies" },
      { type: "build", kind: "unknown", x: 3, y: 2 },
    ]
  ) {
    const r = act(s, a);
    assert.equal(r.changed, false);
    assert.deepEqual(r.state, s);
  }
});
test("repeat build/claim and overcapacity cannot duplicate rewards or spend", () => {
  const s = journey();
  assert.equal(capacity(s), 3);
  for (
    const a of [{ type: "invite" }, { type: "claim", id: "community" }, {
      type: "build",
      kind: "home",
      x: 3,
      y: 2,
    }]
  ) assert.equal(act(s, a).changed, false);
});
test("25 adjacent tiles fill the map without overlapping or negative resources", () => {
  let s = { ...journey(), wood: 1000, metal: 1000 };
  for (let radius = 1; radius <= 4; radius++) {
    for (let y = 0; y < 5; y++) {
      for (let x = 0; x < 5; x++) {
        if (
          Math.abs(x - 2) + Math.abs(y - 2) === radius &&
          !s.tiles.some((t) => t.x === x && t.y === y)
        ) s = act(s, { type: "build", kind: "deck", x, y }).state;
      }
    }
  }
  assert.equal(s.tiles.length, 25);
  assert.ok(s.wood >= 0);
  assert.deepEqual(decode(JSON.stringify(s)), s);
});
test("corrupt, unsupported and inconsistent saves are rejected", () => {
  const valid = journey();
  const corrupt = [
    null,
    {},
    { ...valid, version: 2 },
    { ...valid, wood: -1 },
    { ...valid, xp: 1.5 },
    { ...valid, tiles: [...valid.tiles, valid.tiles[1]] },
    { ...valid, residents: 99 },
    { ...valid, claimed: ["fake"] },
    { ...valid, tiles: [valid.tiles[0], { x: 0, y: 0, kind: "deck" }] },
    { ...valid, profile: { ...valid.profile, name: "" } },
  ];
  for (const s of corrupt) assert.throws(() => decode(JSON.stringify(s)));
  assert.throws(() => decode("{bad"));
});
test("profile controls accept plain text and reject locked titles and invalid fields", () => {
  const s = initialState();
  assert.equal(
    act(s, { type: "profile", profile: { ...s.profile, title: "海の建築家" } })
      .changed,
    false,
  );
  assert.equal(
    act(s, { type: "profile", profile: { ...s.profile, name: "x".repeat(17) } })
      .changed,
    false,
  );
  const r = act(journey(), {
    type: "profile",
    profile: {
      ...s.profile,
      name: "<船長>",
      icon: "貝",
      frame: "星",
      title: "潮灯の守り手",
    },
  });
  assert.equal(r.changed, true);
  assert.equal(r.state.profile.name, "<船長>");
});
test("model does not mutate its input and repeated collections stop at cap", () => {
  const s = initialState();
  act(s, { type: "collect" });
  assert.equal(s.wood, 0);
  assert.equal(
    act({ ...s, collected: 10000 }, { type: "collect" }).changed,
    false,
  );
});
test("facilities can change without losing completed requests or occupied housing", () => {
  let s = { ...journey(), wood: 1000, metal: 1000 };
  const blocked = act(s, { type: "build", kind: "garden", x: 3, y: 2 });
  assert.equal(blocked.changed, false);
  assert.deepEqual(blocked.state, s);
  s = act(s, { type: "build", kind: "deck", x: 2, y: 3 }).state;
  assert.deepEqual(decode(JSON.stringify(s)), s);
  const upgraded = act(s, { type: "build", kind: "home", x: 2, y: 3 });
  assert.equal(upgraded.changed, true);
  assert.equal(upgraded.state.tiles.length, s.tiles.length);
});
