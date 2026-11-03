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
          const db = await window.openSynthetic();
          try {
            return await new Promise((resolve, reject) => {
              const tx = db.transaction(['records', 'receipts'], 'readwrite');
              window.syntheticEvents.push(`created:${input.requestId}`);
              const records = tx.objectStore('records');
              const receipts = tx.objectStore('receipts');
              let result = { status: 'unknown' };
              const key = [input.owner, input.requestId];
              const readReceipt = () => {
                const receiptRead = receipts.get(key);
                receiptRead.onsuccess = () => {
                window.syntheticEvents.push(`read:${input.requestId}`);
                const prior = receiptRead.result;
                if (prior) {
                  result = prior.payload === input.payload &&
                    prior.expectedRevision === input.expectedRevision
                    ? { status: 'alreadyApplied', revision: prior.revision }
                    : { status: 'requestIdConflict' };
                  return;
                }
                const recordRead = records.get(input.owner);
                recordRead.onsuccess = () => {
                  const old = recordRead.result;
                  if (!old) { result = { status: 'missing' }; return; }
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
    assert.equal((await apply(tabB, winner)).status, 'alreadyApplied');
    assert.equal((await apply(tabB, { ...winner, payload: 'changed' })).status, 'requestIdConflict');
    assert.equal((await apply(tabB, { ...winner, expectedRevision: 99 })).status, 'requestIdConflict');
    const second = { owner: 'fake-a', expectedRevision: 1, requestId: 'r-c', payload: 'later' };
    assert.equal((await apply(tabB, second)).status, 'applied');
    assert.equal((await apply(tabA, winner)).status, 'alreadyApplied');
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
    assert.equal((await apply(tabA, winner)).status, 'alreadyApplied');
    assert.equal(await read(tabA, 'fake-a'), null);
    console.log('PASS: synthetic multi-tab CAS, receipt reuse, abort, owner isolation and uninitialized-record rejection');
    console.log('LIMITATION: historical receipt does not prove current record exists');
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
