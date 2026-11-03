// Isolated synthetic experiment; not product storage or an Auth boundary.
// All owner names and values are fabricated. No production URL or data.
const assert = require('node:assert/strict');
const http = require('node:http');
const { chromium } = require('@playwright/test');

async function main() {
  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<!doctype html><title>synthetic-idb-cas</title>');
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.equal(address.address, '127.0.0.1');
  const origin = `http://127.0.0.1:${address.port}`;
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: '/usr/bin/google-chrome',
      headless: true,
      args: ['--no-sandbox'],
    });
    const context = await browser.newContext({ serviceWorkers: 'block' });
    await context.route('**/*', (route) => {
      const url = new URL(route.request().url());
      if (url.origin !== origin) return route.abort();
      return route.continue();
    });
    const tabA = await context.newPage();
    const tabB = await context.newPage();
    for (const page of [tabA, tabB]) {
      await page.goto(origin);
      assert.equal(new URL(page.url()).origin, origin);
      await page.evaluate(() => {
        window.openSynthetic = () => new Promise((resolve, reject) => {
          const request = indexedDB.open('synthetic-owner-cas-v1', 1);
          request.onupgradeneeded = () => {
            const db = request.result;
            db.createObjectStore('records', { keyPath: 'owner' });
            db.createObjectStore('receipts', { keyPath: ['owner', 'requestId'] });
          };
          request.onerror = () => reject(request.error);
          request.onsuccess = () => resolve(request.result);
        });
        window.syntheticEvents = [];
        window.releaseFirst = false;
        window.trySyntheticCas = async (input) => {
          if (typeof input.owner !== 'string' || !input.owner ||
              typeof input.requestId !== 'string' || !input.requestId ||
              typeof input.payload !== 'string' ||
              !Number.isSafeInteger(input.expectedRevision) || input.expectedRevision < 0 ||
              input.expectedRevision >= Number.MAX_SAFE_INTEGER) {
            return { status: 'invalid' };
          }
          const db = await window.openSynthetic();
          try {
            return await new Promise((resolve, reject) => {
              const tx = db.transaction(['records', 'receipts'], 'readwrite');
              window.syntheticEvents.push(`created:${input.requestId}`);
              const records = tx.objectStore('records');
              const receipts = tx.objectStore('receipts');
              let result = { status: 'unknown' };
              const key = [input.owner, input.requestId];
              const validRecord = (record) => record &&
                record.owner === input.owner &&
                Number.isSafeInteger(record.revision) && record.revision >= 0 &&
                typeof record.value === 'string';
              const validReceipt = (receipt) => receipt &&
                receipt.owner === input.owner && receipt.requestId === input.requestId &&
                Number.isSafeInteger(receipt.expectedRevision) && receipt.expectedRevision >= 0 &&
                Number.isSafeInteger(receipt.revision) &&
                receipt.revision === receipt.expectedRevision + 1 &&
                typeof receipt.payload === 'string';
              const readReceipt = () => {
                const receiptRead = receipts.get(key);
                receiptRead.onsuccess = () => {
                window.syntheticEvents.push(`read:${input.requestId}`);
                const prior = receiptRead.result;
                if (prior) {
                  if (!validReceipt(prior)) { result = { status: 'recoveryHold' }; return; }
                  if (prior.payload !== input.payload ||
                      prior.expectedRevision !== input.expectedRevision) {
                    result = { status: 'requestIdConflict' };
                    return;
                  }
                  const currentRead = records.get(input.owner);
                  currentRead.onsuccess = () => {
                    const current = currentRead.result;
                    if (!validRecord(current) ||
                        current.revision < prior.revision ||
                        (current.revision === prior.revision && current.value !== prior.payload)) {
                      result = { status: 'recoveryHold' };
                      return;
                    }
                    result = { status: 'historicalReceiptFound', revision: prior.revision,
                      currentRevision: current.revision };
                  };
                  return;
                }
                const recordRead = records.get(input.owner);
                recordRead.onsuccess = () => {
                  const old = recordRead.result;
                  if (!old) { result = { status: 'missing' }; return; }
                  if (!validRecord(old)) { result = { status: 'recoveryHold' }; return; }
                  if (old.revision !== input.expectedRevision) {
                    result = { status: 'revisionConflict', revision: old.revision };
                    return;
                  }
                  const revision = old.revision + 1;
                  records.put({ owner: input.owner, revision, value: input.payload });
                  receipts.put({ owner: input.owner, requestId: input.requestId,
                    payload: input.payload, expectedRevision: input.expectedRevision, revision });
                  result = { status: 'applied', revision };
                  if (input.forceAbort) tx.abort();
                };
                };
              };
              if (input.holdBeforeRead) {
                const deadline = performance.now() + 20000;
                const keepAlive = () => {
                  const request = records.get(input.owner);
                  request.onsuccess = () => {
                    if (!window.syntheticEvents.includes(`hold-active:${input.requestId}`)) {
                      window.syntheticEvents.push(`hold-active:${input.requestId}`);
                    }
                    if (window.releaseFirst) readReceipt();
                    else if (performance.now() >= deadline) tx.abort();
                    else keepAlive();
                  };
                };
                keepAlive();
              } else {
                readReceipt();
              }
              tx.oncomplete = () => resolve(result);
              tx.onabort = () => reject(new Error('transaction aborted'));
              tx.onerror = () => {}; // onabort reports transaction failure.
            });
          } finally { db.close(); }
        };
      });
    }
    // Synthetic fixture initialization only; missing production state is not init.
    await tabA.evaluate(async () => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        tx.objectStore('records').put({ owner: 'fake-a', revision: 0, value: 'a0' });
        tx.objectStore('records').put({ owner: 'fake-b', revision: 0, value: 'b0' });
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('fixture abort'));
      });
      db.close();
    });
    const apply = (page, input) => page.evaluate((x) => window.trySyntheticCas(x), input);
    const read = (page, owner) => page.evaluate(async (name) => {
      const db = await window.openSynthetic();
      try {
        return await new Promise((resolve, reject) => {
          const tx = db.transaction('records', 'readonly');
          const request = tx.objectStore('records').get(name);
          request.onsuccess = () => resolve(request.result ?? null);
          request.onerror = () => reject(request.error);
        });
      } finally { db.close(); }
    }, owner);
    const firstA = { owner: 'fake-a', expectedRevision: 0, requestId: 'r-a', payload: 'a1' };
    const competing = { owner: 'fake-a', expectedRevision: 0, requestId: 'r-b', payload: 'a2' };
    const firstWork = apply(tabA, { ...firstA, holdBeforeRead: true });
    await tabA.waitForFunction(() => window.syntheticEvents.includes('hold-active:r-a'));
    const secondWork = apply(tabB, competing);
    await tabB.waitForFunction(() => window.syntheticEvents.includes('created:r-b'));
    assert.equal(await tabB.evaluate(() => window.syntheticEvents.includes('read:r-b')), false);
    await tabA.evaluate(() => { window.releaseFirst = true; });
    const simultaneous = await Promise.all([firstWork, secondWork]);
    assert.deepEqual(simultaneous.map((r) => r.status), ['applied', 'revisionConflict']);
    assert.equal(await tabB.evaluate(() => window.syntheticEvents.includes('read:r-b')), true);
    assert.equal((await read(tabB, 'fake-a')).revision, 1);
    assert.deepEqual(await read(tabA, 'fake-b'), { owner: 'fake-b', revision: 0, value: 'b0' });
    const winner = simultaneous[0].status === 'applied' ? firstA : competing;
    // A result can be lost after commit; same immutable request resolves via receipt.
    assert.equal((await apply(tabB, winner)).status, 'historicalReceiptFound');
    assert.equal((await apply(tabB, { ...winner, payload: 'changed' })).status, 'requestIdConflict');
    assert.equal((await apply(tabB, { ...winner, expectedRevision: 99 })).status, 'requestIdConflict');
    const second = { owner: 'fake-a', expectedRevision: 1, requestId: 'r-c', payload: 'later' };
    assert.equal((await apply(tabB, second)).status, 'applied');
    assert.equal((await apply(tabA, winner)).status, 'historicalReceiptFound');
    assert.equal((await read(tabA, 'fake-a')).value, 'later');
    const abort = { owner: 'fake-a', expectedRevision: 2, requestId: 'r-abort', payload: 'aborted', forceAbort: true };
    await assert.rejects(apply(tabA, abort), /transaction aborted/);
    assert.equal((await read(tabB, 'fake-a')).revision, 2);
    assert.equal((await apply(tabB, { ...abort, forceAbort: false })).status, 'applied');
    assert.equal((await apply(tabA, { owner: 'fake-missing', expectedRevision: 0, requestId: 'r-missing', payload: 'x' })).status, 'missing');
    assert.equal(await read(tabB, 'fake-missing'), null);
    // A receipt proves a historical operation only, not current-state existence.
    await tabA.evaluate(async () => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        tx.objectStore('records').delete('fake-a');
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('synthetic missing-record setup aborted'));
      });
      db.close();
    });
    assert.equal((await apply(tabA, winner)).status, 'recoveryHold');
    assert.equal(await read(tabA, 'fake-a'), null);
    await tabA.evaluate(async () => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        tx.objectStore('records').put({ owner: 'fake-a', revision: 0, value: 'old' });
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('synthetic older-record setup aborted'));
      });
      db.close();
    });
    assert.equal((await apply(tabB, winner)).status, 'recoveryHold');
    await tabA.evaluate(async () => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        tx.objectStore('records').put({ owner: 'fake-a', revision: 1, value: 'corrupt' });
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('synthetic corrupt-record setup aborted'));
      });
      db.close();
    });
    assert.equal((await apply(tabB, winner)).status, 'recoveryHold');
    await tabA.evaluate(async () => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        tx.objectStore('records').put({ owner: 'fake-a', revision: 4, value: null });
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('synthetic malformed-record setup aborted'));
      });
      db.close();
    });
    assert.equal((await apply(tabB, winner)).status, 'recoveryHold');
    assert.equal((await apply(tabA, { owner: 'fake-a', expectedRevision: 4,
      requestId: 'new-on-corrupt', payload: 'x' })).status, 'recoveryHold');
    await tabA.evaluate(async (won) => {
      const db = await window.openSynthetic();
      await new Promise((resolve, reject) => {
        const tx = db.transaction(['records', 'receipts'], 'readwrite');
        tx.objectStore('records').put({ owner: 'fake-a', revision: 1, value: won.payload });
        tx.objectStore('receipts').put({ owner: 'fake-a', requestId: won.requestId,
          payload: won.payload, expectedRevision: 'corrupt', revision: 1 });
        tx.oncomplete = resolve;
        tx.onabort = () => reject(new Error('synthetic malformed-receipt setup aborted'));
      });
      db.close();
    }, winner);
    assert.equal((await apply(tabB, winner)).status, 'recoveryHold');
    assert.equal((await apply(tabA, { ...winner, owner: '' })).status, 'invalid');
    assert.equal((await apply(tabA, { ...winner, expectedRevision: Number.MAX_SAFE_INTEGER })).status, 'invalid');
    console.log('PASS: synthetic multi-tab CAS, receipt reuse, abort, owner isolation and uninitialized-record rejection');
    console.log('LIMITATION: version presence checks do not prove full integrity or detect whole-database rollback');
    console.log('LIMITATION: no real Auth/ABA fencing, old-writer exclusion, storage eviction or server CAS was tested');
    await context.close();
  } finally {
    try {
      if (browser) await browser.close();
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
