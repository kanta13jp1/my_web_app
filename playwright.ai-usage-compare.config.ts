import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: './test/e2e', testMatch: 'ai_usage_compare.spec.ts', workers: 1, retries: 0,
  reporter: [['list'], ['json', { outputFile: 'ai-usage-report/results.json' }]],
  use: { baseURL: process.env.E2E_BASE_URL || 'http://127.0.0.1:4173', screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  webServer: process.env.E2E_BASE_URL ? undefined : { command:'python3 -m http.server 4173 --directory web --bind 127.0.0.1', url:'http://127.0.0.1:4173/labs/ai-usage-compare/index.html', reuseExistingServer:false },
  projects:[{name:'desktop',use:{...devices['Desktop Chrome'],viewport:{width:1440,height:1000}}},{name:'mobile',use:{...devices['Pixel 5']}}],
});
