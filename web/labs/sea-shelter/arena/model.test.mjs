import test from "node:test";
import assert from "node:assert/strict";
import {
  advanceTraining,
  newTraining,
  RULES,
  trainingCommand,
} from "./model.mjs";

function run(s, ms) {
  const events = [];
  while (ms > 0 && s.status === "running") {
    const delta = Math.min(50, ms);
    const r = advanceTraining(s, delta);
    s = r.state;
    events.push(...r.events);
    ms -= delta;
  }
  return { state: s, events };
}
test("attack impact belongs to simulation and repeated input cannot multiply it", () => {
  const original = newTraining();
  let s = trainingCommand(original, "attack").state;
  for (let i = 0; i < 30; i++) s = trainingCommand(s, "attack").state;
  assert.equal(s.attacks, 1);
  assert.equal(s.targetHp, 60);
  s = run(s, 180).state;
  assert.equal(s.targetHp, 59);
  assert.equal(s.charge, 4);
  assert.equal(original.pending, null);
  assert.equal(original.targetHp, 60);
});
test("reading a tell and guarding prevents damage and enables a counter", () => {
  let s = run(newTraining(), 3900).state;
  assert.equal(s.telegraphing, true);
  s = trainingCommand(s, "guard").state;
  const r = run(s, 900);
  s = r.state;
  assert.equal(s.playerHp, 5);
  assert.equal(s.guards, 1);
  assert.equal(s.charge, 22);
  assert(r.events.some((e) => e.type === "guard-success"));
  s = trainingCommand(s, "attack").state;
  assert.equal(s.pending.damage, 2);
  s = run(s, 180).state;
  assert.equal(s.targetHp, 58);
});
test("blind early guard expires and a player ignoring cues loses", () => {
  let s = trainingCommand(newTraining(), "guard").state;
  s = run(s, 4800).state;
  assert.equal(s.playerHp, 4);
  assert.equal(s.guards, 0);
  s = run(s, 4 * 4800).state;
  assert.equal(s.status, "lost");
  assert.equal(s.playerHp, 0);
  assert.equal(advanceTraining(s, 50).state, s);
  assert.equal(trainingCommand(s, "special").state, s);
});
test("special requires charge, consumes it once, and resolves a separate impact", () => {
  const empty = newTraining();
  assert.equal(trainingCommand(empty, "special").state, empty);
  let s = { ...empty, charge: 100 };
  s = trainingCommand(s, "special").state;
  assert.equal(s.charge, 0);
  assert.equal(s.specials, 1);
  assert.equal(trainingCommand(s, "special").state, s);
  s = run(s, RULES.specialImpact).state;
  assert.equal(s.targetHp, 53);
});
test("background pause freezes simulation and rejects wall-clock jumps", () => {
  let s = run(newTraining(), 4100).state;
  s = trainingCommand(s, "pause").state;
  assert.equal(advanceTraining(s, 50).state, s);
  assert.equal(trainingCommand(s, "attack").state, s);
  s = trainingCommand(s, "resume").state;
  for (const delta of [NaN, Infinity, -1, 0, 10000]) {
    assert.equal(advanceTraining(s, delta).state, s);
  }
  assert.equal(s.time, 4100);
  s = trainingCommand(s, "guard").state;
  assert.equal(run(s, 700).state.playerHp, 5);
});
test("assistance lengthens warning, not damage or guard resource rules", () => {
  const a = run(newTraining({ assisted: true }), 3000);
  const b = run(newTraining(), 3000);
  assert.equal(a.state.telegraphing, true);
  assert.equal(b.state.telegraphing, false);
  assert.equal(a.state.targetHp, b.state.targetHp);
  assert.equal(a.state.playerHp, b.state.playerHp);
});
test("stop and restart cannot retain pending hits or previous victory state", () => {
  let s = trainingCommand(newTraining(), "attack").state;
  s = trainingCommand(s, "stop").state;
  assert.equal(s.pending, null);
  assert.equal(advanceTraining(s, 50).state, s);
  assert.deepEqual(newTraining(), newTraining());
  assert.equal(newTraining().sequence, 0);
});
test("a deliberate guard/attack/special strategy wins a short real-time battle", () => {
  let s = newTraining();
  while (s.status === "running" && s.time < 90000) {
    if (
      s.telegraphing && s.nextStrikeAt - s.time <= 700 &&
      s.time >= s.nextGuardAt
    ) {
      s = trainingCommand(s, "guard").state;
    }
    if (s.time >= s.nextAttackAt && !s.pending) {
      s = trainingCommand(s, s.charge >= 100 ? "special" : "attack").state;
    }
    s = advanceTraining(s, 50).state;
  }
  assert.equal(s.status, "won");
  assert.equal(s.hitsTaken, 0);
  assert(s.guards > 0 && s.specials > 0);
  assert(s.time >= 45000 && s.time <= 90000, `duration ${s.time}`);
});

test("winning impact at the strike boundary prevents damage after victory", () => {
  let s = run({ ...newTraining(), targetHp: 1 }, 4620).state;
  s = trainingCommand(s, "attack").state;
  const r = run(s, 180);
  assert.equal(r.state.status, "won");
  assert.equal(r.state.playerHp, 5);
  assert(!r.events.some((e) => e.type === "player-hit"));
  assert.equal(trainingCommand(r.state, "guard").state, r.state);
});
