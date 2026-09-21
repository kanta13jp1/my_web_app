import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');

test('direct app navigation cannot be shadowed by a static directory index', () => {
  // Firebase serves existing files/directory indexes before its SPA rewrite.
  for (const path of ['web/jev-mario-lab', 'web/jev-mario-lab.html']) {
    assert.equal(existsSync(new URL(path, root)), false, `${path} shadows Flutter`);
  }
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const configs = Array.isArray(hosting) ? hosting : [hosting];
  assert.ok(configs.some(c => c.rewrites?.some(r => r.source === '**' && r.destination === '/index.html')));
  assert.ok(read('lib/widgets/jev_mario_view_web.dart').includes("'/labs/jev-mario/index.html'"));
});

test('isolated game HTML resolves every local script and stylesheet to a real asset', () => {
  const doc = new URL('web/labs/jev-mario/index.html', root);
  const html = readFileSync(doc, 'utf8');
  const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map(m => m[1]).filter(ref => !/^https?:/.test(ref));
  assert.ok(refs.includes('lab.mjs'));
  assert.ok(refs.includes('style.css'));
  for (const ref of refs) {
    const asset = new URL(ref, doc);
    assert.ok(existsSync(asset), `missing ${ref}`);
    assert.ok(!readFileSync(asset, 'utf8').trimStart().startsWith('<'), `${ref} is HTML`);
  }
});
