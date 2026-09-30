import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: '.', testMatch: 'jev_mario.spec.ts', workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'jev-mario-report', open: 'never' }]],
  use: { baseURL: 'http://127.0.0.1:8765', trace: 'retain-on-failure' },
  webServer: { command: 'python3 -m http.server 8765 --bind 127.0.0.1', cwd: '../..', url: 'http://127.0.0.1:8765', reuseExistingServer: false },
  projects: [{name:'desktop',use:{...devices['Desktop Chrome']}}, {name:'mobile',use:{...devices['Pixel 7']}}],
});
