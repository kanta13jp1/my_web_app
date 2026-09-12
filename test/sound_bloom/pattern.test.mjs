import test from 'node:test';
import assert from 'node:assert/strict';
import { preset, validate, toggle, frequency, activeAt } from '../../web/labs/sound-bloom/pattern.mjs';
test('presets serialize and restore without sharing arrays', () => {
  for (let p = 0; p < 3; p++) { const original = preset(p), copy = validate(JSON.parse(JSON.stringify(original))); assert.deepEqual(copy, original); copy.notes[0][0] = !copy.notes[0][0]; assert.notDeepEqual(copy, original); }
});
test('toggle is immutable and reversible', () => { const original = preset(); const next = toggle(original, 1, 3); assert.notDeepEqual(original, next); assert.deepEqual(toggle(next, 1, 3), original); assert.throws(() => toggle(original, 4, 0)); });
test('malformed data never becomes state', () => { for (const value of [null, {}, {...preset(), tempo: 0}, {...preset(), tempo: 161}, {...preset(), tempo: NaN}, {...preset(), notes: [[true]]}, {...preset(), muted: ['false',false,false,false]}]) assert.throws(() => validate(value)); });
test('mute removes scheduled tracks and empty gardens are silent', () => { const state = preset(); state.notes = state.notes.map(r => r.map(() => true)); assert.equal(activeAt(state, 0).length, 4); state.muted[1] = true; assert.deepEqual(activeAt(state, 0), [0,2,3]); state.notes = state.notes.map(r => r.map(() => false)); assert.deepEqual(activeAt(state, 0), []); });
test('all pitches are audible finite positive values', () => { for (let t = 0; t < 4; t++) for (let s = 0; s < 16; s++) assert.ok(Number.isFinite(frequency(t,s)) && frequency(t,s) > 20 && frequency(t,s) < 20000); });
