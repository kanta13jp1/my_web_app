import { expect, test, type Page } from '@playwright/test';

test.use({ trace: 'retain-on-failure' });

const ignoredConsoleFragments = [
  'ResizeObserver loop',
  'service worker',
  'ServiceWorker',
  'flutter_service_worker',
  'Cache.addAll',
];

function isIgnoredConsoleError(text: string): boolean {
  return ignoredConsoleFragments.some((fragment) => text.includes(fragment));
}

function isAllowedSameOriginRequest(url: string): boolean {
  return (
    url.startsWith('http://127.0.0.1:7359/') ||
    url.startsWith('http://localhost:7359/') ||
    url.startsWith('data:') ||
    url.startsWith('blob:')
  );
}

function isAllowedHostFontFallback(url: string): boolean {
  return (
    url.startsWith('https://fonts.gstatic.com/') ||
    url.startsWith('https://fonts.googleapis.com/')
  );
}

async function openFlutterHost(page: Page) {
  const errors: string[] = [];
  const externalRequests: string[] = [];

  page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
  page.on('console', (msg) => {
    if (msg.type() === 'error' && !isIgnoredConsoleError(msg.text())) {
      errors.push(`console.error: ${msg.text()}`);
    }
  });
  page.on('request', (req) => {
    const url = req.url();
    if (isAllowedSameOriginRequest(url)) {
      return;
    }
    let frameUrl = '';
    try {
      frameUrl = req.frame()?.url() ?? '';
    } catch {
      frameUrl = '';
    }
    if (frameUrl.includes('/labs/guitar-pro-studio/')) {
      externalRequests.push(`lab-iframe: ${url}`);
      return;
    }
    if (!isAllowedHostFontFallback(url)) {
      externalRequests.push(`host: ${url}`);
    }
  });

  await page.goto('/');
  await expect(page.locator('#seo-shell')).toHaveCount(0, { timeout: 20_000 });
  const proTab = page.getByRole('button', { name: /プロ譜面ラボ/ });
  await expect(proTab).toBeVisible({ timeout: 30_000 });
  return { errors, externalRequests, proTab };
}

test('switches to 4th tab プロ譜面ラボ, renders same-origin alphaTab iframe, and tears down cleanly', async ({
  page,
}, info) => {
  const { errors, externalRequests, proTab } = await openFlutterHost(page);

  await proTab.click();

  const iframeEl = page.locator('iframe[title="プロ譜面ラボ (alphaTab)"]');
  await expect(iframeEl).toBeVisible({ timeout: 15_000 });
  await expect(iframeEl).toHaveAttribute(
    'src',
    '/labs/guitar-pro-studio/index.html',
  );

  const frame = page.frameLocator('iframe[title="プロ譜面ラボ (alphaTab)"]');
  await expect(frame.locator('#score-viewport')).toHaveAttribute(
    'data-render-state',
    'ready',
    { timeout: 25_000 },
  );
  await expect(frame.locator('#alphaTab-surface svg').first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(frame.locator('.studio-footer')).toContainText(
    'alphaTab 1.9.0 (MPL-2.0)',
  );
  await page.waitForTimeout(400);
  await page.screenshot({ path: info.outputPath('05-flutter-host-pro-tab.png') });

  if ((page.viewportSize()?.width ?? 1440) < 600) {
    await frame.locator('#score-viewport').scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    await page.screenshot({
      path: info.outputPath('06-flutter-host-pro-tab-score.png'),
    });
  }

  const catalogTab = page.getByRole('button', { name: /練習カタログ/ });
  await expect(catalogTab).toBeVisible();
  await catalogTab.click();
  await expect(iframeEl).toHaveCount(0, { timeout: 10_000 });

  expect(externalRequests, `External requests: ${externalRequests.join(', ')}`).toEqual([]);
  expect(errors, `Unexpected browser errors: ${errors.join('; ')}`).toEqual([]);
});
