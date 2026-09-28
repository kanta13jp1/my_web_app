// node --test scripts/jwenv_lab/merge.test.mjs : merge_shards.mjs joins 34 shard records or refuses.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const script = join(root, 'scripts/jwenv_lab/merge_shards.mjs');
const read = (p) => JSON.parse(readFileSync(join(root, p), 'utf8'));
const samples = [
  ...read('web/labs/expense-comparison/results.json').samples.map((s) => ({ ...s, set: 'original' })),
  ...read('web/labs/jwenv/holdout.json').samples.map((s) => ({ ...s, set: 'holdout' })),
];

function shardFiles(dir, { drop = null, duplicate = false } = {}) {
  samples.forEach((s, i) => {
    if (i === drop) return;
    const row = {
      set: s.set, id: s.id, text: s.text, expected: s.expected,
      a: { choice: s.expected ?? 'other', p: 0.9, review: false },
      b: { choice: s.expected ?? 'other', p: s.expected ? 0.8 : 0.3, review: !s.expected, expected_in_top8: s.expected ? true : null },
      stage1_ms: 10 + i, stage2_ms: 20 + i,
    };
    const rows = duplicate && i === 1 ? [row, { ...row, id: samples[0].id }] : [row];
    writeFileSync(join(dir, `results-shard-${String(i).padStart(2, '0')}.json`), JSON.stringify({
      shard: i, of: 34, sample_ids: [s.id], rows, inputs_sha256: 'x', app_revision: 'y', model: { sha256: 'm' },
      engine: { revision: 'e' }, recorded_at: `2026-09-28T00:00:${String(i).padStart(2, '0')}Z`, load_ms: 5, run_id: '1',
      environment: { adapter: 'google / swiftshader', browser: 'chromium', runner: { cpu_model: 'cpu' } },
      network: { requests: 3, external_requests: [] },
    }));
  });
}

function merge(opts) {
  const dir = mkdtempSync(join(tmpdir(), 'jwenv-shards-'));
  try {
    shardFiles(dir, opts);
    execFileSync(process.execPath, [script, dir, join(dir, 'out.json')], { stdio: 'pipe' });
    return JSON.parse(readFileSync(join(dir, 'out.json'), 'utf8'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('34 shards merge in page order with the pre-registered metrics', () => {
  const r = merge();
  assert.equal(r.methods.rows.length, 34);
  assert.deepEqual(r.methods.rows.map((row) => row.id), samples.map((s) => s.id));
  assert.deepEqual(r.methods.summary.holdout.b, { referenced: 12, matches: 12, false_reviews: 0, review_required: 8, flagged: 8 });
  assert.equal(r.methods.summary.original.a.flagged, 0);
  assert.deepEqual(r.methods.adoption, { b_flags_more: true, match_drop: 0, adopt: true });
  assert.equal(r.recorded_at, '2026-09-28T00:00:33Z');
});

test('a missing shard or a duplicated memo stops the merge', () => {
  assert.throws(() => merge({ drop: 5 }), /missing shards: 5/);
  assert.throws(() => merge({ duplicate: true }), /duplicate row/);
});
