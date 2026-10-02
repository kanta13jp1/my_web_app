'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { existsSync } = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { readSandboxConfiguration } = require('./paddle_sandbox_config.cjs');

const common = {
  PADDLE_SANDBOX_E2E: 'true',
  PADDLE_SANDBOX_CLIENT_TOKEN: 'test_unit_placeholder',
  PADDLE_SANDBOX_PRICE_ID: 'pri_unit_placeholder',
  PADDLE_SANDBOX_CUSTOMER_PORTAL_URL:
    'https://sandbox-customer-portal.paddle.com/cpl_0123456789',
  SUPABASE_URL: 'https://development.invalid',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_unit_placeholder',
};
// Parser fixtures only. Never sent to Paddle or used as a real VAT scenario.
const b2b = {
  PADDLE_SANDBOX_B2B_EMAIL: 'unit@example.invalid',
  PADDLE_SANDBOX_B2B_TAX_IDENTIFIER: 'unit-only-not-a-valid-tax-id',
  PADDLE_SANDBOX_B2B_COUNTRY_CODE: 'GB',
  PADDLE_SANDBOX_B2B_COUNTRY_NAME: 'United Kingdom',
  PADDLE_SANDBOX_B2B_POSTAL_CODE: 'unit-postal',
  PADDLE_SANDBOX_B2B_BUSINESS_NAME: 'Unit test fixture',
  PADDLE_SANDBOX_B2B_EXPECTED_TAX: '0',
};

test('static validation needs no credentials and disables every real scenario', () => {
  assert.deepEqual(readSandboxConfiguration({}), {
    realSandboxEnabled: false, b2bVatEnabled: false,
  });
});

test('basic matrix runs without any B2B values', () => {
  assert.deepEqual(readSandboxConfiguration(common), {
    realSandboxEnabled: true, b2bVatEnabled: false,
  });
});

test('populated B2B values do not implicitly enable VAT', () => {
  assert.equal(readSandboxConfiguration({ ...common, ...b2b }).b2bVatEnabled, false);
});

test('VAT requires both explicit flags', () => {
  assert.throws(() => readSandboxConfiguration({
    PADDLE_SANDBOX_B2B_VAT_E2E: 'true',
  }), /requires PADDLE_SANDBOX_E2E=true/);
});

test('explicit VAT accepts complete configuration, including zero expected tax', () => {
  assert.deepEqual(readSandboxConfiguration({
    ...common, ...b2b, PADDLE_SANDBOX_B2B_VAT_E2E: 'true',
  }), { realSandboxEnabled: true, b2bVatEnabled: true });
});

for (const name of Object.keys(b2b)) {
  test(`explicit VAT fails closed when ${name} is missing or blank`, () => {
    for (const missing of [undefined, '', '  ']) {
      assert.throws(() => readSandboxConfiguration({
        ...common, ...b2b, PADDLE_SANDBOX_B2B_VAT_E2E: 'true', [name]: missing,
      }), new RegExp(`${name} is required`));
    }
  });
}

for (const [name, value] of [
  ['PADDLE_SANDBOX_CLIENT_TOKEN', 'live_never_use'],
  ['PADDLE_SANDBOX_PRICE_ID', 'pro_wrong_kind'],
  ['PADDLE_SANDBOX_CUSTOMER_PORTAL_URL', 'https://customer-portal.paddle.com/cpl_0123456789'],
  ['PADDLE_SANDBOX_CUSTOMER_PORTAL_URL', `${common.PADDLE_SANDBOX_CUSTOMER_PORTAL_URL}?token=private`],
  ['SUPABASE_URL', ''],
  ['SUPABASE_PUBLISHABLE_KEY', 'sb_secret_never_use'],
]) {
  test(`basic preflight rejects unsafe or missing ${name}: ${value.slice(0,12)}`, () => {
    assert.throws(() => readSandboxConfiguration({ ...common, [name]: value }));
  });
}

test('B2B country and tax formats are checked only for explicit VAT', () => {
  for (const invalid of [
    { PADDLE_SANDBOX_B2B_COUNTRY_CODE: 'gb' },
    { PADDLE_SANDBOX_B2B_EXPECTED_TAX: '-1' },
    { PADDLE_SANDBOX_B2B_EXPECTED_TAX: '0.09' },
  ]) {
    assert.doesNotThrow(() => readSandboxConfiguration({ ...common, ...b2b, ...invalid }));
    assert.throws(() => readSandboxConfiguration({
      ...common, ...b2b, ...invalid, PADDLE_SANDBOX_B2B_VAT_E2E: 'true',
    }));
  }
});

test('malformed opt-in flags fail instead of silently skipping selected tests', () => {
  for (const name of ['PADDLE_SANDBOX_E2E', 'PADDLE_SANDBOX_B2B_VAT_E2E']) {
    assert.throws(() => readSandboxConfiguration({ ...common, [name]: 'TRUE' }), /must be true or false/);
  }
});

test('CLI rejects missing VAT configuration before browser work without leaking values', () => {
  const result = spawnSync(process.execPath, [path.join(__dirname, 'paddle_sandbox_config.cjs')], {
    env: { ...common, PADDLE_SANDBOX_B2B_VAT_E2E: 'true' }, encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /PADDLE_SANDBOX_B2B_EMAIL is required/);
  for (const value of Object.values(common).filter(value => value !== 'true')) {
    assert.equal(result.stderr.includes(value), false);
  }
});

// Cloud-only collection/skip checks: no browser or Paddle network call is needed.
const playwrightCli = path.join(__dirname, '../node_modules/@playwright/test/cli.js');
const cloudOnly = { skip: !existsSync(playwrightCli) };
function runGuardedSpec(env, args = []) {
  const inherited = Object.fromEntries(Object.entries(process.env).filter(
    ([name]) => !name.startsWith('PADDLE_') && !name.startsWith('PLAYWRIGHT_'),
  ));
  return spawnSync(process.execPath, [
    playwrightCli, 'test', 'test/e2e/paddle_sandbox_checkout.spec.ts',
    '--project=chromium', '--retries=0', '--reporter=json', ...args,
  ], {
    cwd: path.join(__dirname, '..'),
    env: { ...inherited, ...env }, encoding: 'utf8', timeout: 30_000,
  });
}

test('static mode skips all four cases without launching a browser', cloudOnly, () => {
  const result = runGuardedSpec({});
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.stats.skipped, 4);
  assert.equal(report.stats.expected, 0);
  assert.equal(report.stats.unexpected, 0);
});

test('basic opt-in skips B2B before page fixtures without B2B configuration', cloudOnly, () => {
  const result = runGuardedSpec(common, ['--grep', 'business VAT ID']);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.stats.skipped, 1);
  assert.equal(report.stats.expected, 0);
  assert.equal(report.stats.unexpected, 0);
});

test('misconfigured explicit VAT fails during collection, before any payment', cloudOnly, () => {
  const result = runGuardedSpec({ ...common, PADDLE_SANDBOX_B2B_VAT_E2E: 'true' }, ['--list']);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /PADDLE_SANDBOX_B2B_EMAIL is required/);
});
