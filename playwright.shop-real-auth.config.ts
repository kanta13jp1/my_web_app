import { defineConfig, devices } from '@playwright/test';

// Deliberately independent of the default production E2E configuration.
if (process.env.GITHUB_ACTIONS !== 'true' ||
    process.env.RUNNER_ENVIRONMENT !== 'github-hosted' ||
    process.env.E2E_BASE_URL !== 'http://127.0.0.1:7357') {
  throw new Error('Real Auth tests require the disposable GitHub-hosted lane');
}

export default defineConfig({
  testDir: './test/e2e-real-auth',
  testMatch: 'shop_real_auth.spec.ts',
  timeout: 180_000,
  expect: { timeout: 20_000 },
  workers: 1,
  retries: 0,
  fullyParallel: false,
  reporter: [['list'], ['json', { outputFile: 'shop-real-auth-evidence/browser-results.json' }]],
  outputDir: '.shop-real-auth-browser-temp',
  use: {
    baseURL: 'http://127.0.0.1:7357',
    actionTimeout: 20_000,
    serviceWorkers: 'block',
    trace: 'off', video: 'off', screenshot: 'off',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
});
