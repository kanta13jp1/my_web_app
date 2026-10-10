import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const start = html.indexOf("window.addEventListener('flutter-first-frame'");
const code = html.slice(start, html.indexOf('</script>', start));
function harness() {
  const timers = [];
  const frames = [];
  const attributes = {};
  const shell = { isConnected: true, setAttribute: (key, value) => { attributes[key] = value; }, remove() { this.isConnected = false; } };
  let firstFrame;
  vm.runInNewContext(code, {
    document: { getElementById: () => shell },
    requestAnimationFrame: (callback) => frames.push(callback),
    window: { addEventListener: (_event, callback) => { firstFrame = callback; }, setTimeout: (callback, delay) => timers.push({ callback, delay }) },
  });
  return { shell, attributes, timers, frames, fire: () => firstFrame() };
}
test('keeps readable content until Flutter paints its first frame', () => {
  const h = harness();
  assert.deepEqual(h.attributes, {});
  assert.equal(h.timers.length, 0);
  assert.equal(h.shell.isConnected, true);
});
test('releases the overlay when background frame callbacks stall', () => {
  const h = harness(); h.fire();
  h.timers.find((timer) => timer.delay === 2500).callback();
  assert.equal(h.attributes['aria-hidden'], 'true');
  assert.equal(h.attributes['data-flutter-ready'], 'true');
  h.timers.find((timer) => timer.delay === 150).callback();
  assert.equal(h.shell.isConnected, false);
});
test('normal warmup reveals once and a late fallback remains harmless', () => {
  const h = harness(); h.fire();
  h.frames.shift()(); h.frames.shift()();
  h.timers.find((timer) => timer.delay === 700).callback();
  while (h.frames.length) h.frames.shift()();
  assert.equal(h.attributes['data-flutter-ready'], 'true');
  const removals = h.timers.filter((timer) => timer.delay === 150).length;
  h.timers.find((timer) => timer.delay === 2500).callback();
  assert.equal(h.timers.filter((timer) => timer.delay === 150).length, removals);
});
