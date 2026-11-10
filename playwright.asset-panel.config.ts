import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './test/browser_fixtures',
  testMatch: 'asset_panel.spec.ts',
  timeout: 120_000,
  expect: { timeout: 15_000 },
  workers: 1,
  retries: 0,
  maxFailures: 1,
  reporter: [
    ['list'],
    ['json', { outputFile: 'asset-panel-browser-results/results.json' }],
  ],
  outputDir: 'asset-panel-browser-results',
  use: {
    baseURL: 'http://127.0.0.1:7362',
    serviceWorkers: 'block',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile-390', use: { ...devices['Pixel 5'], viewport: { width: 390, height: 844 } } },
  ],
  webServer: {
    command: 'python3 scripts/serve_spa.py build/web --port 7362',
    url: 'http://127.0.0.1:7362',
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
