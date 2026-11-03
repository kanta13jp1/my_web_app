// Synthetic-only Playwright harness for a detached Dart Web candidate.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const { chromium } = require('@playwright/test');

async function main() {
  const script = fs.readFileSync(process.env.SYNTHETIC_DART_JS, 'utf8');
  const server = http.createServer((req, res) => {
    if (req.url === '/candidate.js') {
      res.writeHead(200, { 'Content-Type': 'application/javascript' });
      res.end(script);
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<!doctype html><script src="/candidate.js"></script>');
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.equal(address.address, '127.0.0.1');
  const origin = `http://127.0.0.1:${address.port}`;
  let browser;
  try {
    browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome',
      headless: true, args: ['--no-sandbox'] });
    const context = await browser.newContext({ serviceWorkers: 'block' });
    await context.route('**/*', (route) => {
      const url = new URL(route.request().url());
      return url.origin === origin ? route.continue() : route.abort();
    });
    const a = await context.newPage();
    const b = await context.newPage();
    for (const page of [a, b]) {
      await page.goto(origin);
      assert.equal(new URL(page.url()).origin, origin);
      await page.waitForFunction(() => typeof window.syntheticCandidateRun === 'function');
    }
    await a.evaluate(() => localStorage.setItem('synthetic_unassigned_legacy', 'retain-me'));
    const dbName = `codex_synthetic_payment_owner_${Date.now()}`;
    const call = (page, arg) => page.evaluate(async (x) => {
      return JSON.parse(await window.syntheticCandidateRun(JSON.stringify(x)));
    }, arg);
    const base = { database: dbName, owner: 'fake-a', expectedRevision: 0,
      requestId: 'r-a', value: 'a1' };
    assert.equal((await call(a, { ...base, database: 'not-a-synthetic-db' })).status, 'invalid');
    assert.equal((await call(a, base)).status, 'recoveryHold');
    // Explicit fixture enrollment only: the candidate itself cannot initialize rows.
    await a.evaluate(async (name) => {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open(name, 1);
        request.onupgradeneeded = () => request.result.createObjectStore('synthetic_owner_state_v1');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      await new Promise((resolve, reject) => {
        const tx = db.transaction('synthetic_owner_state_v1', 'readwrite');
        const store = tx.objectStore('synthetic_owner_state_v1');
        for (const owner of ['fake-a', 'fake-b']) {
          store.put(JSON.stringify({ schema: 1, owner, baseRevision: 0,
            revision: 0, value: owner === 'fake-a' ? 'a0' : 'b0', receipts: [] }), owner);
        }
        tx.oncomplete = resolve; tx.onabort = () => reject(new Error('fixture abort'));
      });
      db.close();
    }, dbName);
    const raw = (page, owner) => page.evaluate(async ({ database, name }) => {
      const db = await new Promise((resolve, reject) => {
        const r = indexedDB.open(database); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error);
      });
      try {
        return await new Promise((resolve, reject) => {
          const tx = db.transaction('synthetic_owner_state_v1', 'readonly');
          const r = tx.objectStore('synthetic_owner_state_v1').get(name);
          r.onsuccess = () => resolve(r.result ?? null); r.onerror = () => reject(r.error);
        });
      } finally { db.close(); }
    }, { database: dbName, name: owner });
    const putRaw = (page, owner, value) => page.evaluate(async (x) => {
      const db = await new Promise((resolve, reject) => {
        const r = indexedDB.open(x.database); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error);
      });
      try {
        await new Promise((resolve, reject) => {
          const tx = db.transaction('synthetic_owner_state_v1', 'readwrite');
          tx.objectStore('synthetic_owner_state_v1').put(x.value, x.owner);
          tx.oncomplete = resolve; tx.onabort = () => reject(new Error('fixture write abort'));
        });
      } finally { db.close(); }
    }, { database: dbName, owner, value });
    // Keep one real IDB transaction alive until both Dart calls create queued txs.
    await a.evaluate((database) => {
      window.startSyntheticHold = () => {
        window.releaseLock = false; window.lockReady = false; window.lockDone = false;
        const open = indexedDB.open(database);
        open.onsuccess = () => {
          const db = open.result;
          const tx = db.transaction('synthetic_owner_state_v1', 'readwrite');
          const store = tx.objectStore('synthetic_owner_state_v1');
          const deadline = performance.now() + 20000;
          const pulse = () => {
            const req = store.get('fake-a');
            req.onsuccess = () => {
              window.lockReady = true;
              if (window.releaseLock) return;
              if (performance.now() >= deadline) { tx.abort(); return; }
              pulse();
            };
          };
          tx.oncomplete = () => { db.close(); window.lockDone = true; };
          tx.onabort = () => { db.close(); window.lockDone = true; };
          pulse();
        };
      };
      window.startSyntheticHold();
    }, dbName);
    await a.waitForFunction(() => window.lockReady);
    for (const page of [a, b]) {
      await page.evaluate(() => {
        window.candidateTransactions = 0;
        const original = IDBDatabase.prototype.transaction;
        IDBDatabase.prototype.transaction = function (...args) {
          const tx = original.apply(this, args);
          if (args[1] === 'readwrite') window.candidateTransactions += 1;
          return tx;
        };
      });
    }
    const contender = { ...base, requestId: 'r-b', value: 'a2' };
    for (const [page, arg] of [[a, base], [b, contender]]) {
      await page.evaluate((x) => {
        window.raceResult = null;
        window.syntheticCandidateRun(JSON.stringify(x)).then((v) => { window.raceResult = JSON.parse(v); });
      }, arg);
    }
    await Promise.all([a.waitForFunction(() => window.candidateTransactions > 0),
      b.waitForFunction(() => window.candidateTransactions > 0)]);
    assert.equal(await a.evaluate(() => window.raceResult), null);
    assert.equal(await b.evaluate(() => window.raceResult), null);
    await a.evaluate(() => { window.releaseLock = true; });
    await Promise.all([a.waitForFunction(() => window.raceResult !== null),
      b.waitForFunction(() => window.raceResult !== null)]);
    const results = [await a.evaluate(() => window.raceResult), await b.evaluate(() => window.raceResult)];
    assert.deepEqual(results.map((r) => r.status).sort(), ['applied', 'versionConflict']);
    const winner = results[0].status === 'applied' ? base : contender;
    assert.equal((await call(b, winner)).status, 'historicalReceipt');
    assert.equal((await call(b, { ...winner, expectedRevision: 1 })).status, 'versionConflict');
    assert.equal(JSON.parse(await raw(b, 'fake-b')).value, 'b0');
    const later = { ...base, expectedRevision: 1, requestId: 'r-c', value: 'later' };
    assert.equal((await call(b, later)).status, 'applied');
    assert.equal((await call(a, winner)).status, 'historicalReceipt');
    assert.equal(JSON.parse(await raw(a, 'fake-a')).value, 'later');
    // An intentionally blocked synthetic transaction times out as unknown. The
    // subsequent IDB read is a barrier after the lock is released.
    const beforeTimeout = await raw(a, 'fake-a');
    await a.evaluate(() => window.startSyntheticHold());
    await a.waitForFunction(() => window.lockReady);
    const timeoutAttempt = { ...base, expectedRevision: 2,
      requestId: 'timed-out', value: 'must-not-appear' };
    const priorTxCount = await b.evaluate(() => window.candidateTransactions);
    assert.equal((await call(b, timeoutAttempt)).status, 'outcomeUnknown');
    assert.ok(await b.evaluate(() => window.candidateTransactions) > priorTxCount);
    assert.equal(await a.evaluate(() => window.lockDone), false);
    await a.evaluate(() => { window.releaseLock = true; });
    await a.waitForFunction(() => window.lockDone);
    assert.equal(await raw(b, 'fake-a'), beforeTimeout);
    // Deliberate adversarial case: a coherent prefix loss also advances the
    // co-located base revision. A safe future adapter must hold, but this
    // detached candidate lacks an independent checkpoint and may fail here.
    const prefixLoss = JSON.stringify({ schema: 1, owner: 'fake-a', baseRevision: 1,
      revision: 2, value: 'later', receipts: [{ requestId: 'r-c',
        expectedRevision: 1, revision: 2, value: 'later' }] });
    await putRaw(a, 'fake-a', prefixLoss);
    const replayAfterLoss = { ...winner, expectedRevision: 2, value: 'replayed' };
    assert.equal((await call(b, replayAfterLoss)).status, 'recoveryHold',
      'coherent receipt-prefix loss must be held, not accepted as a new request');
    assert.equal((await call(a, { ...base, owner: 'fake-missing' })).status, 'recoveryHold');
    const corrupt = JSON.stringify({ schema: 1, owner: 'fake-a', baseRevision: 0,
      revision: 2, value: 'later', receipts: [] });
    await putRaw(a, 'fake-a', corrupt);
    assert.equal((await call(b, later)).status, 'recoveryHold');
    assert.equal(await raw(a, 'fake-a'), corrupt);
    const largeValue = 'x'.repeat(8192);
    const receipts = Array.from({ length: 6 }, (_, i) => ({ requestId: `old-${i}`,
      expectedRevision: i, revision: i + 1, value: largeValue }));
    const large = JSON.stringify({ schema: 1, owner: 'fake-a', baseRevision: 0,
      revision: 6, value: largeValue, receipts });
    assert.ok(large.length <= 65536);
    await putRaw(a, 'fake-a', large);
    assert.equal((await call(b, { ...base, expectedRevision: 6, requestId: 'too-large', value: largeValue })).status, 'recoveryHold');
    assert.equal(await raw(a, 'fake-a'), large);
    // Queue an upgrade behind another tab and check the candidate closes a
    // connection that arrives after its open timeout/blocked result.
    const blockedDb = `${dbName}_blocked`;
    await a.evaluate((database) => {
      window.blockerReady = false;
      const open = indexedDB.open(database, 1);
      open.onupgradeneeded = () => open.result.createObjectStore('synthetic_owner_state_v1');
      open.onsuccess = () => { window.blockerDb = open.result; window.blockerReady = true; };
    }, blockedDb);
    await a.waitForFunction(() => window.blockerReady);
    await b.evaluate((database) => {
      window.upgradeBlocked = false; window.upgradeDone = false;
      window.targetCloses = 0; window.candidateOpenSuccess = 0;
      const close = IDBDatabase.prototype.close;
      IDBDatabase.prototype.close = function () {
        if (this.name === database && this.version === 2) window.targetCloses += 1;
        return close.call(this);
      };
      const originalOpen = IDBFactory.prototype.open;
      IDBFactory.prototype.open = function (name, ...args) {
        const request = originalOpen.call(this, name, ...args);
        if (name === database && args.length === 0) {
          request.addEventListener('success', () => { window.candidateOpenSuccess += 1; });
        }
        return request;
      };
      const upgrade = indexedDB.open(database, 2);
      upgrade.onblocked = () => { window.upgradeBlocked = true; };
      upgrade.onsuccess = () => { upgrade.result.close(); window.upgradeDone = true; };
    }, blockedDb);
    await b.waitForFunction(() => window.upgradeBlocked);
    assert.equal((await call(b, { ...base, database: blockedDb })).status, 'recoveryHold');
    await a.evaluate(() => window.blockerDb.close());
    await b.waitForFunction(() => window.upgradeDone);
    // One close is the fixture upgrade; a second is the late Dart connection.
    await b.waitForFunction(() => window.candidateOpenSuccess === 1 && window.targetCloses >= 2);
    console.log('PASS: Dart Web CAS across two queued tabs; held missing, corrupt chain and oversize without mutation');
    assert.equal(await a.evaluate(() => localStorage.getItem('synthetic_unassigned_legacy')), 'retain-me');
    console.log('PASS: synthetic timeout prevents delayed put; delayed open connection is closed');
    console.log('PASS: synthetic unassigned legacy sentinel was unchanged');
    console.log('LIMITATION: synthetic DB only; no real Auth, owner provenance, old writer, restart durability or server CAS');
    await context.close();
  } finally {
    try { if (browser) await browser.close(); }
    finally { await new Promise((resolve) => server.close(resolve)); }
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
