import test from 'node:test';
import assert from 'node:assert/strict';
import { BASE, LIMIT, create, step, metrics, position, schedule, validate, signal } from './model.mjs';
test('same demand and seed produce identical schedules across signal settings', () => {
  assert.deepEqual(schedule(BASE), schedule({ ...BASE, green: 26, offset: 8 }));
});
test('replay is deterministic', () => {
  const a = create(BASE), b = create(BASE);
  for (let n = 0; n < LIMIT; n++) { step(a); step(b); }
  assert.deepEqual(a, b); assert.ok(a.arrived > 0);
});
test('conservation and unique occupancy for bounded seeds and extremes', () => {
  for (const seed of [1, 42, 9999]) for (const green of [6, 18, 30]) for (const offset of [0, 8, 16]) {
    const w = create({ ...BASE, seed, green, offset, demand: 80 });
    for (let n = 0; n < LIMIT; n++) {
      step(w);
      assert.equal(w.next, w.arrived + w.pending.length + w.cars.length);
      assert.equal(new Set(w.cars.map(c => position(c).join(','))).size, w.cars.length);
      assert.ok(w.cars.every(c => Number.isInteger(c.p) && c.p >= 0 && c.p <= 32));
    }
  }
});
test('invalid input rejected; no silent NaN fallback', () => {
  for (const value of [NaN, Infinity, -1, 0, 31, 1.5, '18']) assert.throws(() => validate({ ...BASE, green: value }));
  assert.throws(() => validate(null));
});
test('both traffic phases and clearance exist', () => {
  const phases = new Set(Array.from({ length: 40 }, (_, t) => signal(BASE, t, 8, 8)));
  assert.deepEqual([...phases].sort(), ['-', 'E', 'S']);
});
test('completed simulation is frozen', () => {
  const w = create(BASE); for (let n = 0; n < LIMIT; n++) step(w);
  const before = JSON.stringify(w); step(w); assert.equal(JSON.stringify(w), before);
});
test('initial metrics do not invent average travel time', () => {
  assert.equal(metrics(create(BASE)).averageTravel, null);
});
