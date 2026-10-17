import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');

test('direct app navigation cannot be shadowed by a static directory index', () => {
  for (const path of ['web/jwenv-lab', 'web/jwenv-lab.html']) {
    assert.equal(existsSync(new URL(path, root)), false, `${path} shadows Flutter`);
  }
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const configs = Array.isArray(hosting) ? hosting : [hosting];
  assert.ok(configs.some(c => c.rewrites?.some(r => r.source === '**' && r.destination === '/index.html')));
  assert.ok(read('lib/widgets/jwenv_view_web.dart').includes("'/labs/jwenv/index.html'"));
});

test('isolated jwenv HTML resolves entry script and essential files', () => {
  const doc = new URL('web/labs/jwenv/index.html', root);
  const html = readFileSync(doc, 'utf8');
  const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map(m => m[1]).filter(ref => !/^(https?:|#)/.test(ref));
  assert.ok(refs.includes('dist/web/src/app.js'));
  for (const ref of refs) {
    const asset = new URL(ref, doc);
    assert.ok(existsSync(asset), `missing ${ref}`);
    assert.ok(!readFileSync(asset, 'utf8').trimStart().startsWith('<'), `${ref} is HTML`);
  }
});

test('jwenv assets have revalidation cache policy', () => {
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const policy = hosting.headers.find(h => h.source === '/labs/jwenv/**');
  assert.ok(policy, 'jwenv assets need their own cache policy');
  const cache = policy.headers.find(h => h.key.toLowerCase() === 'cache-control').value;
  assert.match(cache, /no-cache/);
  assert.match(cache, /must-revalidate/);
});

test('jwenv wgsl shader files exist and have content-type mapping', () => {
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const wgslHeader = hosting.headers.find(h => h.source === '**/*.wgsl');
  assert.ok(wgslHeader, 'wgsl files should have text/plain header');
  assert.equal(wgslHeader.headers[0].value, 'text/plain');

  const shaders = [
    'web/labs/jwenv/dist/web/src/shaders/attention.wgsl',
    'web/labs/jwenv/dist/web/src/shaders/matmul.wgsl',
    'web/labs/jwenv/dist/web/src/shaders/rmsnorm.wgsl',
    'web/labs/jwenv/dist/web/src/shaders/swiglu.wgsl',
  ];
  for (const shader of shaders) {
    assert.ok(existsSync(new URL(shader, root)), `missing shader ${shader}`);
  }
});
