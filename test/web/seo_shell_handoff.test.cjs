const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const html = readFileSync(path.join(__dirname, '../../web/index.html'), 'utf8');
const marker = "window.addEventListener('flutter-first-frame'";
const blocks = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)]
  .map((match) => match[1]).filter((script) => script.includes(marker));
assert.equal(blocks.length, 1, 'Exercise the actual deployed handoff script');
const source = blocks[0].slice(blocks[0].indexOf(marker));

function browser({ hasShell = true } = {}) {
  let now = 0;
  let nextId = 1;
  const timers = new Map();
  const frames = new Map();
  const listeners = new Map();
  const writes = [];
  const attributes = new Map();
  let removals = 0;
  const shell = {
    isConnected: true,
    setAttribute(name, value) {
      writes.push([name, value]);
      attributes.set(name, value);
    },
    remove() {
      removals += 1;
      this.isConnected = false;
    },
  };
  const window = {
    addEventListener(name, callback, options) {
      listeners.set(name, { callback, once: options?.once });
    },
    setTimeout(callback, delay) {
      const id = nextId++;
      timers.set(id, { callback, at: now + delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
    requestAnimationFrame(callback) {
      const id = nextId++;
      frames.set(id, callback);
      return id;
    },
    cancelAnimationFrame(id) { frames.delete(id); },
  };
  vm.runInNewContext(source, {
    window,
    document: { getElementById: () => hasShell ? shell : null },
    requestAnimationFrame: window.requestAnimationFrame,
  }, { filename: 'web/index.html#flutter-first-frame' });

  function advance(ms) {
    const target = now + ms;
    for (;;) {
      const due = [...timers].filter(([, timer]) => timer.at <= target)
        .sort((a, b) => a[1].at - b[1].at || a[0] - b[0])[0];
      if (!due) break;
      const [id, timer] = due;
      timers.delete(id);
      now = timer.at;
      timer.callback();
    }
    now = target;
  }

  return {
    shell, attributes, writes,
    get removals() { return removals; },
    get pending() { return timers.size + frames.size; },
    firstFrame() {
      const listener = listeners.get('flutter-first-frame');
      if (!listener) return;
      if (listener.once) listeners.delete('flutter-first-frame');
      listener.callback();
    },
    advance,
    paint(count = 1) {
      for (let i = 0; i < count; i += 1) {
        advance(16);
        const ready = [...frames.values()];
        frames.clear();
        ready.forEach((callback) => callback(now));
      }
    },
  };
}

test('boot failure leaves the readable shell visible without a first frame', () => {
  const page = browser();
  page.advance(60000);
  assert.equal(page.shell.isConnected, true);
  assert.equal(page.attributes.has('data-flutter-ready'), false);
  assert.equal(page.pending, 0);
});

test('normal paints preserve font warmup and the brief fade', () => {
  const page = browser();
  page.firstFrame();
  page.paint(2);
  page.advance(699);
  assert.equal(page.attributes.has('data-flutter-ready'), false);
  page.advance(1);
  page.paint(11);
  assert.equal(page.attributes.has('data-flutter-ready'), false);
  page.paint();
  assert.equal(page.attributes.get('data-flutter-ready'), 'true');
  assert.equal(page.attributes.get('aria-hidden'), 'true');
  assert.equal(page.shell.isConnected, true);
  page.advance(150);
  assert.equal(page.shell.isConnected, false);
  page.advance(60000);
  assert.equal(page.removals, 1);
  assert.equal(page.pending, 0);
});

for (const [name, prepare] of [
  ['before the first animation callback', () => {}],
  ['between the initial animation callbacks', (page) => page.paint()],
  ['during the font warmup timer', (page) => page.paint(2)],
  ['during stabilization paints', (page) => {
    page.paint(2);
    page.advance(700);
    page.paint(4);
  }],
]) {
  test(`stalled rendering ${name} cannot retain the shell after startup`, () => {
    const page = browser();
    page.firstFrame();
    prepare(page);
    // Advance timers only: animation callbacks remain paused indefinitely.
    page.advance(2150);
    assert.equal(page.attributes.get('data-flutter-ready'), 'true');
    assert.equal(page.attributes.get('aria-hidden'), 'true');
    assert.equal(page.shell.isConnected, false);
    assert.equal(page.pending, 0, 'Cancel unfinished warmup work on handoff');
    page.paint(20);
    page.advance(60000);
    assert.equal(page.removals, 1);
    assert.equal(page.writes.filter(([name]) => name === 'data-flutter-ready').length, 1);
  });
}

test('duplicate first-frame events cannot restart or repeat the handoff', () => {
  const page = browser();
  page.firstFrame();
  page.advance(1000);
  page.firstFrame();
  page.advance(1150);
  assert.equal(page.shell.isConnected, false);
  page.firstFrame();
  page.paint(20);
  page.advance(60000);
  assert.equal(page.removals, 1);
  assert.equal(page.writes.filter(([name]) => name === 'data-flutter-ready').length, 1);
  assert.equal(page.pending, 0);
});

test('a page without the shell needs no handoff work', () => {
  const page = browser({ hasShell: false });
  page.firstFrame();
  assert.equal(page.pending, 0);
});
