#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const args = process.argv.slice(2);
const outIndex = args.indexOf('--out');
const outputPath = outIndex >= 0 ? args[outIndex + 1] : undefined;
const inputPaths = args.filter((arg, index) => {
  return arg !== '--out' && index !== outIndex + 1;
});

if (inputPaths.length === 0) {
  console.error(
    'Usage: node scripts/summarize_playwright_results.mjs <results.json>... [--out <summary.md>]',
  );
  process.exit(2);
}

const summaries = inputPaths.map(readSummary);
const totals = summaries.reduce(
  (acc, summary) => {
    acc.total += summary.total;
    acc.passed += summary.passed;
    acc.failed += summary.failed;
    acc.skipped += summary.skipped;
    acc.flaky += summary.flaky;
    return acc;
  },
  { total: 0, passed: 0, failed: 0, skipped: 0, flaky: 0 },
);

const lines = [
  '# Playwright Evidence Summary',
  '',
  `Status: ${totals.failed === 0 ? 'PASS' : 'FAIL'}`,
  `Total: ${totals.total} / Passed: ${totals.passed} / Failed: ${totals.failed} / Flaky: ${totals.flaky} / Skipped: ${totals.skipped}`,
  '',
  '## Result Files',
  ...summaries.map(
    (summary) =>
      `- ${summary.path}: ${summary.total} total, ${summary.failed} failed`,
  ),
];

const failures = summaries.flatMap((summary) => summary.failures);
if (failures.length > 0) {
  lines.push('', '## Copyable Failure Notes');
  for (const failure of failures) {
    lines.push(
      `- ${failure.project}: ${failure.title} (${failure.status})`,
      `  ${failure.error}`,
    );
  }
} else {
  lines.push('', '## Copyable Failure Notes', '- No failing Playwright tests.');
}

lines.push(
  '',
  'Artifacts to attach or inspect: `playwright-report/` and `test-results/`.',
);

const output = `${lines.join('\n')}\n`;
if (outputPath) {
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, output);
}

process.stdout.write(output);

function readSummary(path) {
  if (!existsSync(path)) {
    return {
      path,
      total: 0,
      passed: 0,
      failed: 1,
      skipped: 0,
      flaky: 0,
      failures: [
        {
          project: 'unknown',
          title: path,
          status: 'missing',
          error: 'Playwright JSON result file was not found.',
        },
      ],
    };
  }

  const report = JSON.parse(readFileSync(path, 'utf8'));
  const tests = [];
  collectTests(report.suites || [], tests);

  return {
    path,
    total: tests.length,
    passed: tests.filter((test) => test.outcome === 'expected').length,
    failed: tests.filter((test) => test.outcome === 'unexpected').length,
    skipped: tests.filter((test) => test.outcome === 'skipped').length,
    flaky: tests.filter((test) => test.outcome === 'flaky').length,
    failures: tests
      .filter((test) => test.outcome === 'unexpected')
      .map((test) => ({
        project: test.project,
        title: test.title,
        status: test.status,
        error: test.error,
      })),
  };
}

function collectTests(suites, tests) {
  for (const suite of suites) {
    collectTests(suite.suites || [], tests);
    for (const spec of suite.specs || []) {
      for (const testCase of spec.tests || []) {
        const results = testCase.results || [];
        const lastResult = results[results.length - 1] || {};
        tests.push({
          project: testCase.projectName || 'default',
          title: [...(suite.titlePath || []), spec.title]
            .filter(Boolean)
            .join(' > '),
          outcome: testCase.outcome || testCase.status,
          status: lastResult.status || testCase.outcome,
          error:
            lastResult.error?.message ||
            lastResult.errors?.[0]?.message ||
            'No error message recorded.',
        });
      }
    }
  }
}
