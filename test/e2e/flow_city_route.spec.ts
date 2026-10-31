import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
  page.on('requestfailed', request => errors.push(`Request failed: ${request.url()}`));
  await page.route('**/favicon.ico', route => route.fulfill({ status: 204 }));
  await page.route('http://127.0.0.1:54321/**', async route => {
    const request = route.request();
    const path = new URL(request.url()).pathname;
    const method = request.method();
    if (
      ['/rest/v1/site_statistics', '/rest/v1/growth_metrics', '/rest/v1/public_memos'].includes(path) &&
      method === 'GET'
    ) {
      await route.fulfill({
        status: 200, contentType: 'application/json',
        headers: { 'content-range': '*/0' }, body: '[]',
      });
    } else if (path === '/rest/v1/guest_presence' && method === 'POST') {
      await route.fulfill({ status: 204, body: '' });
    } else if (
      (path === '/functions/v1/schedule-hub' || path === '/functions/v1/growth-hub') &&
      method === 'POST'
    ) {
      await route.fulfill({
        status: 200, contentType: 'application/json',
        body: JSON.stringify({ success: true, skipped: true, fixture: true }),
      });
    } else {
      errors.push(`Unexpected fixture API: ${method} ${path}`);
      await route.fulfill({ status: 501, body: 'Undefined test fixture' });
    }
  });
  await page.goto('/flow-city', { waitUntil: 'domcontentloaded' });
  const iframe = page.locator('iframe[title="FLOW CITY 信号条件の比較実験"]');
  await expect(iframe).toBeVisible({ timeout: 60_000 });
  await expect(iframe).toHaveAttribute('src', '/labs/flow-city/index.html');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('heading', { level: 1 })).toContainText('街の流れを');
  // Each test reports runtime errors as an additional assertion, not just a log.
  (page as any).__flowErrors = errors;
});

test.afterEach(async ({ page }, testInfo) => {
  await testInfo.attach('runtime-errors', { body: JSON.stringify((page as any).__flowErrors), contentType: 'application/json' });
  expect((page as any).__flowErrors).toEqual([]);
});

test('same inputs stay equal; signal candidate resets and runs visibly', async ({ page }, testInfo) => {
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#speed').selectOption('80');
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(100);
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '一時停止', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#difference')).toHaveText('B − A：到着 0台 / 待機 0台·tick');
  const paused = await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock').innerText();
  await page.waitForTimeout(250);
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock')).toHaveText(paused);
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '東行に合わせる' }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock')).toHaveText('0 / 720 tick');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#green')).toHaveValue('26');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#offset')).toHaveValue('8');
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(160);
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '一時停止', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#difference')).not.toHaveText('比較を開始すると結果が出ます');
  expect(await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('html').evaluate((element: HTMLElement) => element.scrollWidth <= element.clientWidth)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('comparison.png'), fullPage: true });
  const city = page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]');
  const clockBeforeFocus = await city.locator('#clock').innerText();
  await city.getByRole('button', { name: '比較に集中', exact: true }).click();
  await expect(city.locator('#focus')).toHaveAttribute('aria-pressed', 'true');
  await expect(city.locator('#clock')).toHaveText(clockBeforeFocus);
  await expect(city.locator('#summaryA b')).toHaveText(await city.locator('#metricsA b').allTextContents());
  await expect(city.locator('#summaryB b')).toHaveText(await city.locator('#metricsB b').allTextContents());
  await city.locator('.comparison-summary').screenshot({ path: testInfo.outputPath('comparison-summary.png') });
  await page.screenshot({ path: testInfo.outputPath('focused-comparison.png'), fullPage: true });
  await city.getByRole('button', { name: '通常表示へ', exact: true }).click();
  await expect(city.locator('#focus')).toHaveAttribute('aria-pressed', 'false');

});

test('storage failure is explained and comparison remains usable', async ({ page }) => {
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('html').evaluate(() => { Storage.prototype.setItem = () => { throw new DOMException('denied', 'SecurityError'); }; });
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '設定を保存', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#status')).toContainText('保存できませんでした');
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(0);
});

test('empty restore, saved preset reload, and reset are recoverable', async ({ page }, testInfo) => {
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '保存を復元', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#status')).toContainText('保存された設定がありません');
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '東行に合わせる' }).click();
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '設定を保存', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#status')).toContainText('設定を保存しました');
  await page.reload();
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '保存を復元', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#green')).toHaveValue('26');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#offset')).toHaveValue('8');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#status')).toContainText('復元しました');
  await page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').getByRole('button', { name: '最初から', exact: true }).click();
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#clock')).toHaveText('0 / 720 tick');
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#metricsA b')).toHaveText(['0', '0', '0']);
  await expect(page.frameLocator('iframe[title="FLOW CITY 信号条件の比較実験"]').locator('#metricsB b')).toHaveText(['0', '0', '0']);
  await page.screenshot({ path: testInfo.outputPath('reset.png'), fullPage: true });
});
