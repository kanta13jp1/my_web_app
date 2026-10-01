import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const script = fileURLToPath(new URL('./summarize_playwright_results.mjs', import.meta.url));

function report(status = 'expected') {
  return {
    suites: [{ suites: [{ specs: [{ title: 'sample', tests: [{
      projectName: 'chromium', status,
      results: [{ status: status === 'unexpected' ? 'failed' : 'passed', error: { message: 'sample failure' } }],
    }] }] }] }],
    errors: [],
  };
}

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'playwright-summary-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const input = join(dir, 'results.json');
  const output = join(dir, 'summary.md');
  return {
    input, output,
    write: (value) => writeFileSync(input, typeof value === 'string' ? value : JSON.stringify(value)),
    run: (...args) => spawnSync(process.execPath, [script, ...args], { encoding: 'utf8' }),
  };
}

test('single input without --out is included and passes', (t) => {
  const f = fixture(t);
  f.write(report());
  const result = f.run(f.input);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Status: PASS/);
  assert.match(result.stdout, /Total: 1 \/ Passed: 1 \/ Failed: 0/);
});

test('test failure returns nonzero and preserves a copyable summary', (t) => {
  const f = fixture(t);
  f.write(report('unexpected'));
  const result = f.run(f.input, '--out', f.output);
  assert.equal(result.status, 1);
  assert.match(readFileSync(f.output, 'utf8'), /Status: FAIL/);
  assert.match(result.stdout, /Failed: 1/);
  assert.match(result.stdout, /sample failure/);
});

for (const [name, input] of [
  ['missing', undefined],
  ['invalid JSON', '{'],
  ['invalid shape', {}],
  ['empty report', { suites: [] }],
]) {
  test(`${name} fails as an evidence error without inventing a failed test`, (t) => {
    const f = fixture(t);
    if (input !== undefined) f.write(input);
    const result = f.run(f.input, '--out', f.output);
    assert.equal(result.status, 1);
    assert.match(readFileSync(f.output, 'utf8'), /Status: FAIL/);
    assert.match(result.stdout, /Total: 0 \/ Passed: 0 \/ Failed: 0/);
    assert.match(result.stdout, /Evidence errors: 1/);
  });
}

test('a missing suite report cannot be hidden by a second passing report', (t) => {
  const f = fixture(t);
  f.write(report());
  const result = f.run(join(f.input, '..', 'missing.json'), f.input, '--out', f.output);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /Total: 1 \/ Passed: 1 \/ Failed: 0/);
  assert.match(result.stdout, /Evidence errors: 1/);
});

test('runner errors fail even when recorded tests passed', (t) => {
  const f = fixture(t);
  f.write({ ...report(), errors: [{ message: 'global teardown failed' }] });
  const result = f.run(f.input, '--out', f.output);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /global teardown failed/);
});

test('missing --out value is a usage error', (t) => {
  const f = fixture(t);
  f.write(report());
  assert.equal(f.run(f.input, '--out').status, 2);
});
