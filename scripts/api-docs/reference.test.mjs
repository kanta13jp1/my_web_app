import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { runInNewContext } from 'node:vm';
import { downloadJson } from '../../web/labs/shared/download-json.mjs';
import { root, sourcePath, parseDoclets, documentedFunction, renderReference, checkOutput } from './generate.mjs';

const source = readFileSync(path.join(root, sourcePath), 'utf8');
const doclets = parseDoclets();
const doc = documentedFunction(doclets);

test('generated reference is deterministic and includes contract, examples and correction path', () => {
  const first = renderReference(doclets, source);
  assert.equal(first, renderReference(parseDoclets(), source));
  for (const text of ['引数', '戻り値と例外', '使用例', '修正方法', 'BigInt', 'Promise', '元のJSDocを修正', 'ソース SHA-256']) assert.ok(first.includes(text), text);
  assert.doesNotThrow(() => checkOutput(first, first));
});

test('stale HTML fails, regenerating recovers, and changed source changes provenance', () => {
  const original = renderReference(doclets, source);
  assert.throws(() => checkOutput(original.replace('settings.json', 'old.json'), original), /Stale/);
  const updated = renderReference(doclets, source + '\n// change\n');
  assert.throws(() => checkOutput(original, updated), /Stale/);
  assert.doesNotThrow(() => checkOutput(updated, updated));
});

test('removed example or parameter description fails with a useful message', () => {
  const noExample = structuredClone(doclets);
  delete noExample.find((d) => d.kind === 'function' && d.name === 'downloadJson' && !d.undocumented).examples;
  assert.throws(() => documentedFunction(noExample), /Missing/);
  const noParam = structuredClone(doclets);
  delete noParam.find((d) => d.kind === 'function' && d.name === 'downloadJson' && !d.undocumented).params[0].description;
  assert.throws(() => documentedFunction(noParam), /Parameter/);
});

test('actual renamed source parameter rejects stale JSDoc', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'lab-reference-'));
  try {
    const file = path.join(dir, 'download-json.mjs');
    writeFileSync(file, source.replace('function downloadJson(value, filename)', 'function downloadJson(value, outputName)'));
    assert.throws(() => documentedFunction(parseDoclets(file)), /Parameter/);
  } finally { rmSync(dir, { recursive: true }); }
});

test('comment markup is escaped instead of becoming executable HTML', () => {
  const modified = structuredClone(doclets);
  modified.find((d) => d.kind === 'function' && d.name === 'downloadJson' && !d.undocumented).description = '<script>alert(1)</script>';
  const html = renderReference(modified, source);
  assert.ok(html.includes('&lt;script&gt;alert(1)&lt;/script&gt;'));
  assert.ok(!html.includes('<script>'));
});

test('the published JSDoc example produces the described JSON download', async (t) => {
  const blobs = [], links = [], cleanup = [], revoked = [];
  t.mock.method(URL, 'createObjectURL', (blob) => { blobs.push(blob); return `blob:test-${blobs.length}`; });
  t.mock.method(URL, 'revokeObjectURL', (url) => revoked.push(url));
  t.mock.method(globalThis, 'setTimeout', (callback, delay) => { cleanup.push({ callback, delay }); });
  const oldDocument = globalThis.document;
  globalThis.document = { createElement(tag) { assert.equal(tag, 'a'); const link = { click() { links.push({ href: this.href, download: this.download }); } }; return link; } };
  try {
    const importLine = "import { downloadJson } from '/labs/shared/download-json.mjs';";
    assert.ok(doc.examples[0].startsWith(importLine));
    runInNewContext(doc.examples[0].slice(importLine.length), { downloadJson, console: { error: (...args) => assert.fail(args.join(' ')) } });
    assert.deepEqual(links, [{ href: 'blob:test-1', download: 'settings.json' }]);
    assert.equal(blobs[0].type, 'application/json');
    assert.deepEqual(JSON.parse(await blobs[0].text()), { version: 1, theme: 'light' });
    assert.equal(cleanup[0].delay, 1000);
    cleanup[0].callback();
    assert.deepEqual(revoked, ['blob:test-1']);
  } finally { if (oldDocument === undefined) delete globalThis.document; else globalThis.document = oldDocument; }
});

test('circular input and BigInt throw before any URL, then valid input can recover', (t) => {
  let urls = 0, clicks = 0;
  t.mock.method(URL, 'createObjectURL', () => { urls++; return 'blob:recovery'; });
  t.mock.method(globalThis, 'setTimeout', () => {});
  const oldDocument = globalThis.document;
  globalThis.document = { createElement: () => ({ click: () => clicks++ }) };
  try {
    const circular = {}; circular.self = circular;
    assert.throws(() => downloadJson(circular, 'bad.json'), TypeError);
    assert.throws(() => downloadJson({ n: 1n }, 'bad.json'), TypeError);
    assert.equal(urls, 0);
    downloadJson({ ok: true }, 'recovered.json');
    assert.equal(urls, 1); assert.equal(clicks, 1);
  } finally { if (oldDocument === undefined) delete globalThis.document; else globalThis.document = oldDocument; }
});
