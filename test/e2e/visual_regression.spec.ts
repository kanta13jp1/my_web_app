import { expect, Page, test, TestInfo } from '@playwright/test';

type VisualTarget = {
  name: string;
  route: string;
};

const visualTargets: VisualTarget[] = [
  { name: 'landing', route: '/' },
  { name: 'privacy', route: '/privacy' },
  { name: 'terms', route: '/terms' },
];

const fixedBrowserTime = new Date('2026-01-15T03:00:00.000Z');

test.describe('reviewed Flutter Web visual baselines', () => {
  for (const target of visualTargets) {
    test(`${target.name} matches its reviewed baseline`, async (
      { page },
      testInfo,
    ) => {
      await installDeterministicBrowserState(page);

      const response = await page.goto(target.route, {
        waitUntil: 'domcontentloaded',
      });
      expect(response?.ok(), `${target.route} should return HTTP 2xx/3xx`).toBe(
        true,
      );
      expect(new URL(page.url()).pathname).toBe(target.route);

      await waitForFlutterSurface(page);
      await attachBaselineMetadata(testInfo, target);

      await expect(page).toHaveScreenshot(`${target.name}.png`, {
        fullPage: true,
      });
    });
  }
});

async function installDeterministicBrowserState(page: Page) {
  await page.clock.setFixedTime(fixedBrowserTime);
  await page.addInitScript(() => {
    Math.random = () => 0.5;
    window.localStorage.clear();
    window.sessionStorage.clear();
  });
}

async function waitForFlutterSurface(page: Page) {
  await page.waitForFunction(
    () =>
      document.querySelector('flutter-view, flt-glass-pane') != null,
    undefined,
    { timeout: 60_000 },
  );
  await page.locator('#seo-shell').waitFor({
    state: 'detached',
    timeout: 10_000,
  });
  await page.evaluate(async () => {
    await document.fonts.ready;
  });
  await page.waitForLoadState('networkidle', { timeout: 3_000 }).catch(
    () => undefined,
  );
  await page.waitForTimeout(500);
}

async function attachBaselineMetadata(
  testInfo: TestInfo,
  target: VisualTarget,
) {
  await testInfo.attach(`${target.name}-visual-contract`, {
    body: JSON.stringify(
      {
        route: target.route,
        project: testInfo.project.name,
        viewport: testInfo.project.use.viewport,
        fixedBrowserTime: fixedBrowserTime.toISOString(),
        maxDiffPixelRatio: 0.002,
        comparison: 'Playwright pixel baseline',
      },
      null,
      2,
    ),
    contentType: 'application/json',
  });
}
