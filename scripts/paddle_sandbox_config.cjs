// Shared by the cloud preflight and Playwright. Never include values in errors.
'use strict';

const B2B_FIELDS = [
  'PADDLE_SANDBOX_B2B_EMAIL',
  'PADDLE_SANDBOX_B2B_TAX_IDENTIFIER',
  'PADDLE_SANDBOX_B2B_COUNTRY_CODE',
  'PADDLE_SANDBOX_B2B_COUNTRY_NAME',
  'PADDLE_SANDBOX_B2B_POSTAL_CODE',
  'PADDLE_SANDBOX_B2B_BUSINESS_NAME',
  'PADDLE_SANDBOX_B2B_EXPECTED_TAX',
];

function flag(env, name) {
  const value = env[name] ?? 'false';
  if (value !== 'true' && value !== 'false') {
    throw new Error(`${name} must be true or false.`);
  }
  return value === 'true';
}

function required(env, name) {
  const value = env[name];
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${name} is required for the selected sandbox scenario.`);
  }
  return value;
}

function readSandboxConfiguration(env = process.env) {
  const realSandboxEnabled = flag(env, 'PADDLE_SANDBOX_E2E');
  const b2bVatEnabled = flag(env, 'PADDLE_SANDBOX_B2B_VAT_E2E');
  if (b2bVatEnabled && !realSandboxEnabled) {
    throw new Error('B2B VAT requires PADDLE_SANDBOX_E2E=true as well.');
  }
  if (!realSandboxEnabled) return { realSandboxEnabled, b2bVatEnabled };

  if (!required(env, 'PADDLE_SANDBOX_CLIENT_TOKEN').startsWith('test_')) {
    throw new Error('PADDLE_SANDBOX_CLIENT_TOKEN must be a sandbox test_ token.');
  }
  if (!required(env, 'PADDLE_SANDBOX_PRICE_ID').startsWith('pri_')) {
    throw new Error('PADDLE_SANDBOX_PRICE_ID must be a pri_ identifier.');
  }
  if (!/^https:\/\/sandbox-customer-portal\.paddle\.com\/cpl_[a-z0-9]{10,}$/.test(
    required(env, 'PADDLE_SANDBOX_CUSTOMER_PORTAL_URL'),
  )) {
    throw new Error('PADDLE_SANDBOX_CUSTOMER_PORTAL_URL must be a stable generic sandbox portal URL.');
  }
  required(env, 'SUPABASE_URL');
  if (required(env, 'SUPABASE_PUBLISHABLE_KEY').startsWith('sb_secret_')) {
    throw new Error('A Supabase secret key must never be compiled into Flutter Web.');
  }

  // Even configured B2B values do not opt a basic run into a VAT transaction.
  if (b2bVatEnabled) {
    for (const name of B2B_FIELDS) required(env, name);
    if (!/^[A-Z]{2}$/.test(env.PADDLE_SANDBOX_B2B_COUNTRY_CODE)) {
      throw new Error('PADDLE_SANDBOX_B2B_COUNTRY_CODE must be a two-letter uppercase code.');
    }
    if (!/^[0-9]+$/.test(env.PADDLE_SANDBOX_B2B_EXPECTED_TAX)) {
      throw new Error('PADDLE_SANDBOX_B2B_EXPECTED_TAX must be a Paddle minor-unit integer.');
    }
  }
  return { realSandboxEnabled, b2bVatEnabled };
}

module.exports = { readSandboxConfiguration };

if (require.main === module) {
  try {
    const { realSandboxEnabled, b2bVatEnabled } = readSandboxConfiguration();
    console.log(`Real sandbox: ${realSandboxEnabled}; B2B VAT: ${b2bVatEnabled}.`);
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
