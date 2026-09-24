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

test('the choice limit is exactly 8 options: 8 accepted, 9 rejected', () => {
  const choice = (n) => ({ model: 'jev-latest', state: 'x', questions: { q: { type: 'choice', instructions: 'pick',
    criteria: Object.fromEntries(Array.from({ length: n }, (_, i) => [`o${i}`, null])) } } });
  assert.doesNotThrow(() => jev.validate(choice(8), jev.MODEL_ALIASES));
  assert.throws(() => jev.validate(choice(9), jev.MODEL_ALIASES), (e) => e.code === 'too_many_options' && e.status === 422);
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

test('method B asks one 8-option choice over the stage-1 top 8, with all 8 rotations', () => {
  const ids = Object.keys(reference.categories);
  const ranked = ids.map((id, i) => ({ id, p: 1 - i / 20 }));
  const request = core.stage2Request('ローソンで買い物', ranked, reference.categories, core.EXPENSE_DOMAIN);
  assert.deepEqual(Object.keys(request.questions.category.criteria), ids.slice(0, 8));
  assert.equal(request.options.permutations, 8);
  assert.doesNotThrow(() => jev.validate(request, jev.MODEL_ALIASES));
});

test('method B flags review below a 0.5 majority only', () => {
  const answer = (p) => ({ type: 'choice', choice: 'x', probabilities: { x: p, y: 1 - p }, confidence: 0 });
  assert.equal(core.decideStage2(answer(0.5)).review, false);
  assert.equal(core.decideStage2(answer(0.4999)).review, true);
  assert.throws(() => core.decideStage2({ type: 'noul' }));
});

test('summary and adoption rule follow the pre-registered definitions', () => {
  const row = (expected, a, b, top8 = true) => ({ expected, a, b: { ...b, expected_in_top8: expected ? top8 : null } });
  const rows = [
    row('x', { choice: 'x', review: false }, { choice: 'x', review: false }),
    row('y', { choice: 'x', review: false }, { choice: 'y', review: true }, false),
    row(null, { choice: 'x', review: false }, { choice: 'x', review: true }),
  ];
  const s = core.summarizeMethods(rows);
  assert.deepEqual(s.a, { referenced: 2, matches: 1, false_reviews: 0, review_required: 1, flagged: 0 });
  assert.deepEqual(s.b, { referenced: 2, matches: 2, false_reviews: 1, review_required: 1, flagged: 1 });
  assert.equal(s.b_expected_in_top8, 1);
  assert.deepEqual(core.adoptionCheck(s), { b_flags_more: true, match_drop: -1, adopt: true });
  assert.equal(core.adoptionCheck({ a: { matches: 5, flagged: 1 }, b: { matches: 3, flagged: 4 } }).adopt, false);
});

test('the holdout set is 20 unique memos: one referenced per category plus 8 needing review', () => {
  const holdout = JSON.parse(readFileSync(join(lab, 'holdout.json'), 'utf8'));
  const ids = Object.keys(reference.categories);
  assert.equal(holdout.samples.length, 20);
  assert.equal(new Set(holdout.samples.map((s) => s.id)).size, 20);
  const referenced = holdout.samples.filter((s) => s.expected);
  assert.deepEqual(referenced.map((s) => s.expected).sort(), [...ids].sort());
  assert.ok(referenced.every((s) => s.review_required === false));
  assert.ok(holdout.samples.filter((s) => !s.expected).every((s) => s.review_required === true));
  const original = new Set(reference.samples.map((s) => s.text));
  assert.ok(holdout.samples.every((s) => !original.has(s.text)));
});
