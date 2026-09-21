import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { DecisionLoop, readState, summarize, validateRom } from '../../web/jev-mario-lab/core.mjs';
const require = createRequire(import.meta.url);
const jsnes = require('../../web/jev-mario-lab/vendor/jsnes.min.js');
const flush = () => new Promise(r => setImmediate(r));
const reply = { choice: 'right', confidence: .8, upstream_http_ms: 23 };
test('median/p95 preserve first sample; failed values excluded', () => {
  assert.deepEqual(summarize([100, 1, 3, 2, NaN]), { count: 4, median: 2.5, p95: 100 });
  assert.equal(summarize([]).median, null);
});
test('RAM coordinates, signed speed, block buffer page and enemies', () => {
  const ram = new Uint8Array(2048); ram[0x6d] = 1; ram[0x86] = 32;
  ram[0x71a] = 1; ram[0x71c] = 16; ram[0x57] = 255;
  ram[0x5d0 + 1] = 84; ram[0xf] = 1; ram[0x6e] = 1; ram[0x87] = 64;
  const s = readState(ram); assert.equal(s.player.x, 288); assert.equal(s.player.vx, -1);
  assert.equal(s.tiles[0], -1); assert.equal(s.tiles[1], 84); assert.equal(s.enemies[0].dx, 32);
});
test('emulator executes original synthetic test ROM, without Nintendo data', () => {
  const rom = new Uint8Array(40976); rom.set([78, 69, 83, 26, 2, 1]);
  // LDA #42; STA $0040; JMP $8005. Reset vector to $8000.
  rom.set([0xa9, 42, 0x8d, 0x40, 0, 0x4c, 5, 0x80], 16);
  rom[16 + 0x7ffc] = 0; rom[16 + 0x7ffd] = 0x80;
  validateRom(rom); let frames = 0;
  const nes = new jsnes.NES({ emulateSound: false, onFrame: () => frames++ });
  nes.loadROM(rom); nes.frame(); assert.equal(nes.cpu.mem[0x40], 42); assert.equal(frames, 1);
  assert.throws(() => validateRom(new Uint8Array(42)));
});
test('stop discards late response and prevents overlapping restart', async () => {
  let resolve, now = 0; const actions = [], records = [];
  const loop = new DecisionLoop({ request: () => new Promise(r => resolve = r), state: () => ({}),
    apply: a => actions.push(a), record: r => records.push(r), done: () => {}, clock: () => now });
  loop.start(); now = 50; loop.stop(); assert.equal(loop.start(), false);
  resolve(reply); await flush(); assert(!actions.includes('right'));
  assert.equal(records.length, 1); assert.equal(records[0].cancelled, true);
});
test('stale replies release buttons, cap completes and failure stops', async () => {
  let now = 0; const actions = [], records = [];
  const loop = new DecisionLoop({ request: async () => { now += 800; return reply; }, state: () => ({}),
    apply: a => actions.push(a), record: r => records.push(r), done: () => {}, clock: () => now });
  loop.start({ count: 1 }); await flush(); assert.equal(loop.active, false);
  assert.equal(records[0].stale, true); assert(!actions.includes('right'));
  loop.request = async () => { throw new Error('quota'); };
  loop.start(); await flush(); assert.equal(loop.active, false); assert.equal(records.length, 2);
});
