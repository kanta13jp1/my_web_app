import { test, expect, type Page } from '@playwright/test';

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

async function openFixture(page: Page, errors: string[]) {
  page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
  page.on('console', (msg) => {
    if (msg.type() === 'error' && !isIgnoredConsoleError(msg.text())) {
      errors.push(`console.error: ${msg.text()}`);
    }
  });
  await page.goto('/');
  await expect(
    page.getByRole('button', { name: '自動スクロール開始', exact: true }),
  ).toBeVisible({ timeout: 30_000 });
  await expect(page.locator('#seo-shell')).toHaveCount(0, {
    timeout: 15_000,
  });
  await expect(
    page.getByRole('group', { name: /表示キー: D#/ }),
  ).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(350);
}

test('renders horizontal U-FRET style chord diagrams, Capo 3 conversion, dark sheet, and scroll', async ({
  page,
}, info) => {
  const errors: string[] = [];
  await openFixture(page, errors);

  await page.screenshot({ path: info.outputPath('01-original-key-light.png') });

  const capoPlus = page.getByRole('button', { name: 'カポを1つ上げる', exact: true });
  await capoPlus.click();
  await capoPlus.click();
  await capoPlus.click();
  await expect(page.getByRole('group', { name: /Capo 3/ })).toBeVisible();
  await expect(
    page.getByRole('group', { name: /表示キー: C/ }),
  ).toBeVisible();
  await expect(page.getByRole('group', { name: /C\/B/ })).toBeVisible();
  await page.mouse.move(4, 4);
  await page.waitForTimeout(450);
  await page.screenshot({ path: info.outputPath('02-capo3-light.png') });

  await page.getByRole('button', { name: 'ダーク表示', exact: true }).click();
  await expect(
    page.getByRole('button', { name: '白紙譜面', exact: true }),
  ).toBeVisible();
  await page.mouse.move(4, 4);
  await page.waitForTimeout(450);
  await page.screenshot({ path: info.outputPath('03-capo3-dark.png') });

  // Test auto-scroll motion via start -> pause button
  await page
    .getByRole('button', { name: '自動スクロール開始', exact: true })
    .click();
  await page.waitForTimeout(1200);
  await page
    .getByRole('button', { name: '自動スクロール停止', exact: true })
    .click();
  await page.mouse.move(4, 4);
  await page.waitForTimeout(450);
  await page.screenshot({ path: info.outputPath('04-scrolled-chorus.png') });

  expect(errors, `Unexpected browser errors: ${errors.join('; ')}`).toEqual([]);
});
