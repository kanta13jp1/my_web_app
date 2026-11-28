import assert from 'node:assert/strict';
import test from 'node:test';
import {
  FROZEN_CASES,
  FROZEN_RESPONSES,
  evaluateSkillJsonResponse,
  runTwentyTrialSelfCheck,
} from '../../web/labs/skill-json-check/model.mjs';

test('preserves tab delimiter in fenced csv JSON and flags legacy trim bug', () => {
  const csvCase = FROZEN_CASES.find((c) => c.id === 'csv');
  const fencedCsv = `\`\`\`json\n${JSON.stringify(csvCase.expected)}\n\`\`\``;
  const res = evaluateSkillJsonResponse({
    rawOutput: fencedCsv,
    requiredKeys: Object.keys(csvCase.expected),
    exampleObject: csvCase.example,
    expectedObject: csvCase.expected,
    allowExtraKeys: false,
  });
  assert.equal(res.strictJsonPass, false);
  assert.equal(res.fenceStripped, true);
  assert.equal(res.decision, 'remediated');
  assert.deepEqual(res.missingKeys, []);
  assert.deepEqual(res.legacyTrimBlockedKeys, ['delimiter']);
  assert.equal(res.matchesExpected, true);
});

test('blocks copied sample values, blank whitespace fields, extra keys, and broken JSON', () => {
  const deployCase = FROZEN_CASES.find((c) => c.id === 'deploy');
  const res = evaluateSkillJsonResponse({
    rawOutput: JSON.stringify({
      service: 'demo',
      replicas: 3,
      region: 'ap-northeast-1',
      health_path: '   ',
      timeout_s: 17,
      extra_key: 1,
    }),
    requiredKeys: Object.keys(deployCase.expected),
    exampleObject: deployCase.example,
    allowExtraKeys: false,
  });
  assert.equal(res.decision, 'blocked');
  assert.deepEqual(res.missingKeys, ['health_path']);
  assert.deepEqual(res.extraKeys, ['extra_key']);
  assert.deepEqual(res.copiedExampleKeys, ['service']);

  const broken = evaluateSkillJsonResponse({
    rawOutput: '{"service":"delta"',
    requiredKeys: ['service'],
  });
  assert.equal(broken.decision, 'blocked');
  assert.equal(broken.violations[0].code, 'invalid_json_syntax');
});

test('20-trial frozen self-check matches replay.py and isolates 4 legacy trim false blocks', () => {
  assert.equal(FROZEN_RESPONSES.length, 20);
  const report = runTwentyTrialSelfCheck();
  assert.equal(report.total, 20);
  assert.equal(report.apiCalls, 0);

  assert.equal(report.summary.A.n, 10);
  assert.equal(report.summary.A.strictPass, 7);
  assert.equal(report.summary.A.semanticPass, 10);
  assert.equal(report.summary.A.fenced, 3);
  assert.equal(report.summary.A.legacyTrimFalseBlock, 2);
  assert.equal(report.summary.A.fixedBlock, 0);

  assert.equal(report.summary.B.n, 10);
  assert.equal(report.summary.B.strictPass, 9);
  assert.equal(report.summary.B.semanticPass, 10);
  assert.equal(report.summary.B.fenced, 1);
  assert.equal(report.summary.B.legacyTrimFalseBlock, 2);
  assert.equal(report.summary.B.fixedBlock, 0);
});
