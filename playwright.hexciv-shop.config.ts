import { defineConfig } from '@playwright/test';
import baseConfig from './playwright.config';

// Opt-in fixture suite: kept outside the normal/public E2E discovery directory.
export default defineConfig({
  ...baseConfig,
  testDir: './test/e2e-fixtures',
  testMatch: 'hexciv_shop_fixture.spec.ts',
  retries: 0,
  use: { ...baseConfig.use, serviceWorkers: 'block' },
});
