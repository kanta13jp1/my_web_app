// node --test scripts/jwenv_lab/core.test.mjs : checks the lab's request builders against the vendored upstream validator.
import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const lab = join(root, 'web/labs/jwenv');
const core = await import(pathToFileURL(join(lab, 'core.mjs')));
// jev.js has no imports; copy it to .mjs so Node loads it as ESM regardless of package.json.
const tmp = mkdtempSync(join(tmpdir(), 'jwenv-'));
copyFileSync(join(lab, 'vendor/jwenv-8263b81/src/jev.js'), join(tmp, 'jev.mjs'));
const jev = await import(pathToFileURL(join(tmp, 'jev.mjs')));
const reference = JSON.parse(readFileSync(join(root, 'web/labs/expense-comparison/results.json'), 'utf8'));

test('the article example is a valid request for the upstream validator', () => {
  assert.doesNotThrow(() => jev.validate(structuredClone(core.ARTICLE_EXAMPLE), jev.MODEL_ALIASES));
});

test('12 categories as one choice question are rejected with status 422', () => {
  const request = core.limitCheckRequest(reference.categories);
  assert.equal(Object.keys(request.questions.category.criteria).length, 12);
  assert.throws(() => jev.validate(request, jev.MODEL_ALIASES), (e) => {
    assert.ok(e instanceof jev.JevError);
    assert.equal(e.code, 'too_many_options');
    assert.equal(e.status, 422);
    return true;
  });
});

test('the same categories fit as 12 yes/no questions in one request', () => {
  const request = core.expenseRequest('ローソンで買い物', reference.categories, core.EXPENSE_DOMAIN);
  assert.equal(Object.keys(request.questions).length, 12);
  assert.ok(Object.values(request.questions).every((q) => q.type === 'noul'));
  assert.doesNotThrow(() => jev.validate(request, jev.MODEL_ALIASES));
});

test('ranking picks the highest P(yes) and flags weak winners for review', () => {
  const answers = { a: { type: 'noul', noul: 0.2 }, b: { type: 'noul', noul: 0.7 }, c: { type: 'noul', noul: 0.4 } };
  const ranked = core.rankNoul(answers, ['a', 'b', 'c']);
  assert.deepEqual(ranked.map((r) => r.id), ['b', 'c', 'a']);
  assert.deepEqual(core.pickCategory(ranked), { choice: 'b', p: 0.7, review: false });
  assert.equal(core.pickCategory(core.rankNoul({ a: { type: 'noul', noul: 0.3 } }, ['a'])).review, true);
  assert.throws(() => core.rankNoul({ a: { type: 'choice' } }, ['a']));
});

test('confidence helper equals the upstream normalized-entropy formula', () => {
  for (const p of [[0.25, 0.25, 0.25, 0.25], [0.98, 0.01, 0.005, 0.005], [1, 0], [0.6, 0.3, 0.1]]) {
    assert.ok(Math.abs(core.normalizedEntropyConfidence(p) - jev.confidenceOf(p)) < 1e-12);
  }
  assert.equal(core.normalizedEntropyConfidence([0.25, 0.25, 0.25, 0.25]), 0);
});

test('agreement counts only samples with a reference', () => {
  const rows = [{ expected: 'x', k: 'x' }, { expected: 'y', k: 'x' }, { expected: null, k: 'x' }];
  assert.deepEqual(core.agreement(rows, 'k'), { referenced: 2, matches: 1 });
  assert.equal(core.median([3, 1, 2]), 2);
  assert.equal(core.median([4, 1, 2, 3]), 2.5);
  assert.ok(core.isHtmlFallback('<!doctype html>'));
  assert.ok(!core.isHtmlFallback('{"a":1}'));
});
