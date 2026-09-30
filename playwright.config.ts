import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL ?? 'https://my-web-app-b67f4.web.app';
const jsonOutputFile =
  process.env.PLAYWRIGHT_JSON_OUTPUT_NAME ?? 'playwright-report/results.json';

export default defineConfig({
  testDir: './test/e2e',
  outputDir: process.env.PLAYWRIGHT_TEST_OUTPUT_DIR ?? 'test-results',
  timeout: 30_000,
  expect: {
    timeout: 7_500,
    toHaveScreenshot: {
      animations: 'disabled',
      caret: 'hide',
      maxDiffPixelRatio: 0.002,
      scale: 'css',
    },
  },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 1,
  reporter: process.env.CI
    ? [
        ['list'],
        ['html', { open: 'never', outputFolder: 'playwright-report/html' }],
        ['json', { outputFile: jsonOutputFile }],
      ]
    : [['list'], ['html', { open: 'never', outputFolder: 'playwright-report/html' }]],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 1000 },
      },
    },
    {
      name: 'mobile-chrome',
      use: {
        ...devices['Pixel 5'],
      },
    },
  ],
});
