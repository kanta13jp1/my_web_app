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
  assert.ok(read('lib/widgets/jev_mario_view_web.dart').includes("'/labs/jev-mario/index.html?v=student-1'"));
});

test('isolated game HTML resolves every local script and stylesheet to a real asset', () => {
  const doc = new URL('web/labs/jev-mario/index.html', root);
  const html = readFileSync(doc, 'utf8');
  const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map(m => m[1]).filter(ref => !/^https?:/.test(ref));
  assert.ok(refs.includes('lab.mjs?v=student-1'));
  assert.ok(refs.includes('style.css?v=student-1'));
  for (const ref of refs) {
    const asset = new URL(ref, doc);
    assert.ok(existsSync(asset), `missing ${ref}`);
    assert.ok(!readFileSync(asset, 'utf8').trimStart().startsWith('<'), `${ref} is HTML`);
  }
});


test('game documents and their dependency graph bypass old fresh caches and revalidate', () => {
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const policy = hosting.headers.find(h => h.source === '/labs/jev-mario/**');
  assert.ok(policy, 'game assets need their own cache policy');
  const cache = policy.headers.find(h => h.key.toLowerCase() === 'cache-control').value;
  assert.match(cache, /no-cache/);
  assert.match(cache, /must-revalidate/);
  const sharedPolicy = hosting.headers.find(h => h.source === '/labs/shared/**');
  assert.ok(sharedPolicy, 'shared dependencies also need to revalidate');
  const sharedCache = sharedPolicy.headers.find(h => h.key.toLowerCase() === 'cache-control').value;
  assert.match(sharedCache, /no-cache/);
  assert.match(sharedCache, /must-revalidate/);
  const frame = read('lib/widgets/jev_mario_view_web.dart').match(/src = '([^']+)'/)[1];
  const doc = new URL(`web${frame}`, root);
  const revision = doc.searchParams.get('v');
  assert.ok(revision, 'migration URL bypasses the previous one-hour HTML cache');
  const html = readFileSync(doc, 'utf8');
  const entry = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map(m => new URL(m[1], doc)).filter(u => /\.(mjs|js|css)$/.test(u.pathname));
  const pending = [...entry], visited = new Set();
  while (pending.length) {
    const asset = pending.pop();
    if (visited.has(asset.href)) continue;
    visited.add(asset.href);
    assert.equal(asset.searchParams.get('v'), revision, `stale dependency: ${asset.pathname}`);
    assert.ok(existsSync(asset), `missing ${asset.pathname}`);
    if (!asset.pathname.endsWith('.mjs')) continue;
    const source = readFileSync(asset, 'utf8');
    for (const m of source.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) pending.push(new URL(m[1], asset));
  }
  assert.ok(visited.size >= 7, 'entry scripts, styles and all game modules checked');
});
