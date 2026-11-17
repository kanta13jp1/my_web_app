// Exercises the installed Playwright reporters without launching a browser.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cli = join(root, 'node_modules/@playwright/test/cli.js');
const summarizer = join(root, 'scripts/summarize_playwright_results.mjs');

for (const workflow of ['minimal-e2e-gate.yml', 'e2e-smoke.yml']) {
  test(`${workflow}: consecutive suites retain both JSON, HTML and attachments`, (t) => {
    const dir = mkdtempSync(join(root, '.playwright-report-contract-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    mkdirSync(join(dir, 'specs'));
    const config = join(dir, 'playwright.config.ts');
    writeFileSync(config, `
import baseConfig from '../playwright.config';
export default { ...baseConfig, testDir: './specs', retries: 0,
  projects: [{ name: 'report-contract' }] };
`);
    writeFileSync(join(dir, 'specs/report.spec.ts'), `
import { test, expect } from '@playwright/test';
import { writeFileSync } from 'node:fs';
test('records evidence without a browser', async ({}, testInfo) => {
  const marker = testInfo.outputPath('marker.txt');
  writeFileSync(marker, 'retained');
  await testInfo.attach('marker', { path: marker, contentType: 'text/plain' });
  expect(1).toBe(1);
});
`);
    const source = readFileSync(join(root, '.github/workflows', workflow), 'utf8');
    const paths = [...source.matchAll(
      /PLAYWRIGHT_JSON_OUTPUT_NAME: ([^\r\n]+)\r?\n\s+PLAYWRIGHT_HTML_OUTPUT_DIR: ([^\r\n]+)\r?\n\s+PLAYWRIGHT_TEST_OUTPUT_DIR: ([^\r\n]+)/g,
    )];
    assert.equal(paths.length, 2, 'both suites must isolate all reporter outputs');
    const retained = [];
    for (const [, json, html, artifacts] of paths) {
      const result = spawnSync(process.execPath, [cli, 'test', '--config', config], {
        cwd: root, encoding: 'utf8', timeout: 60_000,
        env: { ...process.env, CI: 'true',
          PLAYWRIGHT_JSON_OUTPUT_NAME: join(dir, json),
          PLAYWRIGHT_HTML_OUTPUT_DIR: join(dir, html),
          PLAYWRIGHT_TEST_OUTPUT_DIR: join(dir, artifacts),
        },
      });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      const report = JSON.parse(readFileSync(join(dir, json), 'utf8'));
      const tests = report.suites.flatMap((suite) => suite.specs.flatMap((spec) => spec.tests));
      assert.equal(tests.length, 1);
      assert.equal(tests[0].status, 'expected');
      retained.push([join(dir, json), readFileSync(join(dir, json))]);
      retained.push([join(dir, html, 'index.html'), readFileSync(join(dir, html, 'index.html'))]);
      const attachment = tests[0].results[0].attachments[0].path;
      assert.ok(existsSync(attachment));
      retained.push([attachment, readFileSync(attachment)]);
      for (const [path, content] of retained) {
        assert.deepEqual(readFileSync(path), content, `${path} must survive later suites`);
      }
    }
    const summary = spawnSync(process.execPath, [summarizer,
      ...paths.map(([, json]) => join(dir, json)), '--out', join(dir, 'summary.md'),
    ], { encoding: 'utf8' });
    assert.equal(summary.status, 0, summary.stdout + summary.stderr);
    assert.match(summary.stdout, /Total: 2 \/ Passed: 2 \/ Failed: 0/);
  });
}
