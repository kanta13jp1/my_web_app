import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './test/e2e',
  testMatch: 'aero_lab.spec.ts',
  // Software WebGL on shared CI runners is substantially slower than a GPU.
  timeout: 120000,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { outputFolder: 'aero-lab-report', open: 'never' }]],
  use: {
    baseURL: 'http://127.0.0.1:4173',
    screenshot: 'only-on-failure',
    launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] },
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1440, height: 1100 } } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
  webServer: {
    command: 'python3 -m http.server 4173 --bind 127.0.0.1 --directory web',
    url: 'http://127.0.0.1:4173/labs/aero-lab/index.html',
    reuseExistingServer: false,
  },
});
