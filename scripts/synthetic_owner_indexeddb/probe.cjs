'use strict';
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

// The outer runner must establish the OS boundary before starting this process.
if (process.platform !== 'linux') throw new Error('Linux isolated runner required');
const links = JSON.parse(cp.execFileSync('ip', ['-j', 'link', 'show'], {encoding: 'utf8'}));
if (!Array.isArray(links) || links.length !== 1 || links[0].ifname !== 'lo') {
  throw new Error('network namespace is not loopback-only');
}
const runnerTemp = fs.realpathSync(process.env.RUNNER_TEMP || '');
const profile = fs.mkdtempSync(path.join(runnerTemp, 'synthetic-idb-profile-'));
fs.chmodSync(profile, 0o700);
const playwright = require(process.argv[2]);
const app = fs.readFileSync(path.join(__dirname, 'app.js'));
const server = http.createServer((req, res) => {
  if (req.method !== 'GET') { res.writeHead(405).end(); return; }
  if (req.url === '/') {
    res.writeHead(200, {'Content-Type': 'text/html', 'Cache-Control': 'no-store'});
    res.end('<!doctype html><meta charset="utf-8"><title>Synthetic IndexedDB</title><script src="/app.js"></script>');
  } else if (req.url === '/app.js') {
    res.writeHead(200, {'Content-Type': 'text/javascript', 'Cache-Control': 'no-store'});
    res.end(app);
  } else res.writeHead(404).end();
});

(async () => {
  let context;
  await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const start = async () => {
    const ctx = await playwright.chromium.launchPersistentContext(profile, {headless: true});
    await ctx.route('**/*', async route => {
      const url = new URL(route.request().url());
      if (url.origin !== origin) return route.abort();
      return route.continue();
    });
    return ctx;
  };
  try {
    context = await start();
    const a = await context.newPage();
    const b = await context.newPage();
    a.setDefaultTimeout(15000); b.setDefaultTimeout(15000);
    await Promise.all([a.goto(origin), b.goto(origin)]);
    const legacy = [0, 255, 49, 10, 42];
    await a.evaluate(bytes => probe.putLegacy(bytes), legacy);
    assert.deepEqual(await a.evaluate(() => probe.get('A', 'value')), null);
    assert.deepEqual(await a.evaluate(() => probe.get('B', 'value')), null);
    assert.deepEqual(await a.evaluate(() => probe.readLegacy()), legacy);
    await a.evaluate(() => probe.put('B', 'value', 'B-original'));
    await a.evaluate(async () => {
      window.held = await probe.startHeldIncrement('A', 'counter');
      await window.held.ready;
    });
    // Simulate a session selection change while A's write remains in progress.
    await a.evaluate(() => { window.selectedOwner = 'B'; });
    await a.evaluate(() => window.held.release());
    await a.evaluate(() => window.held.done);
    assert.equal(await b.evaluate(() => probe.get('B', 'value')), 'B-original');
    assert.equal(await b.evaluate(() => probe.get('B', 'counter')), null);
    assert.equal(await a.evaluate(() => probe.get('A', 'counter')), 1);
    assert.equal(await a.evaluate(() => probe.abortWrite('B', 'value', 'aborted')), 'aborted');
    assert.equal(await a.evaluate(() => probe.get('B', 'value')), 'B-original');
    await a.reload();
    assert.deepEqual(await a.evaluate(() => probe.readLegacy()), legacy);
    assert.equal(await a.evaluate(() => probe.get('A', 'counter')), 1);
    await a.evaluate(async () => {
      window.held = await probe.startHeldIncrement('A', 'counter');
      await window.held.ready;
    });
    await b.evaluate(async () => {
      window.secondDone = false;
      window.second = await probe.startIncrement('A', 'counter');
      window.secondWrite = window.second.done.then(() => { window.secondDone = true; });
    });
    assert.equal(await b.evaluate(() => window.secondDone), false);
    await a.evaluate(() => window.held.release());
    await a.evaluate(() => window.held.done);
    await b.evaluate(() => window.secondWrite);
    assert.equal(await b.evaluate(() => probe.get('A', 'counter')), 3);
    assert.equal(await b.evaluate(() => probe.get('B', 'value')), 'B-original');
    assert.deepEqual(await b.evaluate(() => probe.readLegacy()), legacy);
    await context.close(); context = null;
    context = await start();
    const reopened = await context.newPage();
    await reopened.goto(origin);
    assert.equal(await reopened.evaluate(() => probe.get('A', 'counter')), 3);
    assert.equal(await reopened.evaluate(() => probe.get('B', 'value')), 'B-original');
    assert.deepEqual(await reopened.evaluate(() => probe.readLegacy()), legacy);
    console.log('PASS: synthetic legacy bytes, owner namespaces, abort, reload, two-tab ordering, browser restart');
  } finally {
    if (context) await context.close();
    await new Promise(resolve => server.close(resolve));
    // The job-owned temporary profile is left to runner teardown; no recursive deletion.
  }
})().catch(error => { console.error('Synthetic IndexedDB probe failed:', error.message); process.exitCode = 1; });
