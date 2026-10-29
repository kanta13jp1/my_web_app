import { defineConfig } from '@playwright/test';
import base from './playwright.config';

const raw = process.env.E2E_BASE_URL;
if (!raw) {
  throw new Error('E2E_BASE_URL must identify the loopback business execution fixture.');
}
const url = new URL(raw);
if (!['http:', 'https:'].includes(url.protocol) ||
    !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) ||
    url.username || url.password) {
  throw new Error('Business execution E2E only permits a loopback fixture.');
}

export default defineConfig({
  ...base,
  testMatch: '**/business_execution.spec.ts',
  // Deliberately re-enable only this fixture; the normal suite ignores it.
  testIgnore: [],
  forbidOnly: !!process.env.CI,
  workers: 1,
  retries: 0,
  outputDir: 'business-execution-results',
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'business-execution-report/html' }],
    ['json', { outputFile: 'business-execution-report/results.json' }],
  ],
  use: {
    ...base.use,
    baseURL: url.origin,
    trace: 'retain-on-failure',
  },
});
