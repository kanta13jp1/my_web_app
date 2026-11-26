import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AstraInputError,
  calculateAstraCost,
  runFifteenCaseSelfCheck,
} from '../../web/labs/astra-price-boundary/model.mjs';

test('exact boundary 272000 vs one-token over 272001', () => {
  const atBoundary = calculateAstraCost({
    totalInput: 272000,
    cachedRead: 0,
    cachedWrite: 0,
    output: 1000,
  });
  assert.equal(atBoundary.tier, 'standard');
  assert.equal(atBoundary.actualUsd, '2.77');
  assert.equal(atBoundary.thresholdIgnoredUsd, '2.77');
  assert.equal(atBoundary.underestimateUsd, '0');

  const overBoundary = calculateAstraCost({
    totalInput: 272001,
    cachedRead: 0,
    cachedWrite: 0,
    output: 1000,
  });
  assert.equal(overBoundary.tier, 'long-context');
  assert.equal(overBoundary.actualUsd, '5.51502');
  assert.equal(overBoundary.thresholdIgnoredUsd, '2.77001');
  assert.equal(overBoundary.underestimateUsd, '2.74501');
});

test('frozen 15-case self-check matches Python Decimal results verbatim', () => {
  const report = runFifteenCaseSelfCheck();
  assert.equal(report.total, 15);
  assert.equal(report.passed, 15);
  assert.equal(report.apiCalls, 0);

  const byId = Object.fromEntries(report.rows.map((r) => [r.id, r]));
  assert.equal(byId['article-example'].actual, '8.25 USD');
  assert.equal(byId['article-example'].underestimateUsd, '3.75 USD');
  assert.equal(byId['cached-long'].actual, '4.65 USD');
  assert.equal(byId['cached-long'].underestimateUsd, '1.95 USD');
  assert.equal(byId['all-write-over'].actual, '6.800025 USD');
  assert.equal(byId['all-write-over'].underestimateUsd, '3.4000125 USD');
});

test('rejects fullwidth digits, empty input, and overlapping cache partitions', () => {
  assert.throws(
    () => calculateAstraCost({ totalInput: '２７２０００', cachedRead: '0', cachedWrite: '0', output: '0' }),
    (err) => err instanceof AstraInputError && err.code === 'NONNEGATIVE_INTEGER',
  );
  assert.throws(
    () => calculateAstraCost({ totalInput: '', cachedRead: '0', cachedWrite: '0', output: '0' }),
    (err) => err instanceof AstraInputError && err.code === 'NONNEGATIVE_INTEGER',
  );
  assert.throws(
    () => calculateAstraCost({ totalInput: '100', cachedRead: '60', cachedWrite: '41', output: '0' }),
    (err) => err instanceof AstraInputError && err.code === 'CACHE_EXCEEDS_TOTAL',
  );
});

test('result payload is JSON-serializable without BigInt TypeError', () => {
  const payload = calculateAstraCost({
    totalInput: '300000',
    cachedRead: '100000',
    cachedWrite: '100000',
    output: '1000',
  });
  const encoded = JSON.stringify(payload);
  const decoded = JSON.parse(encoded);
  assert.equal(decoded.actualUsd, '4.775');
  assert.equal(decoded.underestimateUsd, '2.375');
});
