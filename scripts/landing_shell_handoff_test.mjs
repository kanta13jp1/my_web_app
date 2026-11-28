import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const start = html.indexOf("window.addEventListener('flutter-first-frame'");
const code = html.slice(start, html.indexOf('</script>', start));

function harness() {
  let nextTimerId = 1;
  let nextFrameId = 1;
  const timers = [];
  const frames = [];
  const attributes = {};
  const shell = {
    isConnected: true,
    setAttribute: (key, value) => {
      attributes[key] = value;
    },
    remove() {
      this.isConnected = false;
    },
  };
  let firstFrame;
  const windowObj = {
    addEventListener: (_event, callback) => {
      firstFrame = callback;
    },
    setTimeout: (callback, delay) => {
      const id = nextTimerId++;
      timers.push({ id, callback, delay, cleared: false });
      return id;
    },
    clearTimeout: (id) => {
      const timer = timers.find((t) => t.id === id);
      if (timer) timer.cleared = true;
    },
  };
  vm.runInNewContext(code, {
    document: { getElementById: () => shell },
    requestAnimationFrame: (callback) => {
      const id = nextFrameId++;
      frames.push({ id, callback, cancelled: false });
      return id;
    },
    window: {
      ...windowObj,
      cancelAnimationFrame: (id) => {
        const frame = frames.find((f) => f.id === id);
        if (frame) frame.cancelled = true;
      },
    },
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
  const h = harness();
  h.fire();
  const fallback = h.timers.find((timer) => timer.delay === 2000 && !timer.cleared);
  assert.ok(fallback);
  fallback.callback();
  assert.equal(h.attributes['aria-hidden'], 'true');
  assert.equal(h.attributes['data-flutter-ready'], 'true');
  const removeTimer = h.timers.find((timer) => timer.delay === 150 && !timer.cleared);
  assert.ok(removeTimer);
  removeTimer.callback();
  assert.equal(h.shell.isConnected, false);
});

test('normal warmup reveals once and a late fallback remains harmless', () => {
  const h = harness();
  h.fire();
  h.frames.shift().callback();
  h.frames.shift().callback();
  const warmup = h.timers.find((timer) => timer.delay === 700 && !timer.cleared);
  assert.ok(warmup);
  warmup.callback();
  while (h.frames.length) {
    const f = h.frames.shift();
    if (!f.cancelled) f.callback();
  }
  assert.equal(h.attributes['data-flutter-ready'], 'true');
  const removals = h.timers.filter((timer) => timer.delay === 150).length;
  const fallback = h.timers.find((timer) => timer.delay === 2000);
  assert.equal(fallback.cleared, true);
  fallback.callback();
  assert.equal(h.timers.filter((timer) => timer.delay === 150).length, removals);
});
