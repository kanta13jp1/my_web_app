'use strict';
// Synthetic-only demonstration; owner labels are not authentication.
const opened = new Promise((resolve, reject) => {
  const req = indexedDB.open('synthetic-owner-probe-v1', 1);
  req.onupgradeneeded = () => {
    req.result.createObjectStore('legacy');
    req.result.createObjectStore('owned');
  };
  req.onerror = () => reject(req.error);
  req.onsuccess = () => resolve(req.result);
});

async function transact(storeName, mode, operation) {
  const db = await opened;
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    let result;
    tx.oncomplete = () => resolve(result);
    tx.onabort = () => reject(new Error('transaction aborted'));
    tx.onerror = () => {};
    operation(tx.objectStore(storeName), tx, value => { result = value; });
  });
}

window.probe = {
  putLegacy(bytes) {
    return transact('legacy', 'readwrite', s => s.put(new Uint8Array(bytes), 'unknown-owner'));
  },
  readLegacy() {
    return transact('legacy', 'readonly', (s, tx, done) => {
      s.get('unknown-owner').onsuccess = e => done(Array.from(e.target.result));
    });
  },
  put(owner, id, value) {
    return transact('owned', 'readwrite', s => s.put(value, [owner, id]));
  },
  get(owner, id) {
    return transact('owned', 'readonly', (s, tx, done) => {
      s.get([owner, id]).onsuccess = e => done(e.target.result ?? null);
    });
  },
  async abortWrite(owner, id, value) {
    const db = await opened;
    return new Promise((resolve, reject) => {
      const tx = db.transaction('owned', 'readwrite');
      tx.onabort = () => resolve('aborted');
      tx.oncomplete = () => reject(new Error('unexpected commit'));
      tx.objectStore('owned').put(value, [owner, id]).onsuccess = () => tx.abort();
    });
  },
  async startHeldIncrement(owner, id) {
    const db = await opened;
    let readyResolve;
    let release = false;
    const ready = new Promise(resolve => { readyResolve = resolve; });
    const tx = db.transaction('owned', 'readwrite');
    const done = new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onabort = () => reject(new Error('held transaction aborted'));
    });
    const store = tx.objectStore('owned');
    const get = store.get([owner, id]);
    get.onsuccess = () => {
      store.put((get.result ?? 0) + 1, [owner, id]);
      const keepAlive = () => {
        const keep = store.get(['synthetic-keepalive', 'unused']);
        keep.onsuccess = () => {
          if (readyResolve) { readyResolve(); readyResolve = null; }
          if (!release) keepAlive();
        };
      };
      keepAlive();
    };
    return {ready, done, release: () => { release = true; }};
  },
  async startIncrement(owner, id) {
    const db = await opened;
    const tx = db.transaction('owned', 'readwrite');
    const done = new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onabort = () => reject(new Error('increment transaction aborted'));
    });
    const store = tx.objectStore('owned');
    const get = store.get([owner, id]);
    get.onsuccess = () => store.put((get.result ?? 0) + 1, [owner, id]);
    return {done};
  },
};
