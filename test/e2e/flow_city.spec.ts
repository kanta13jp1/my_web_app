import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`); });
  page.on('requestfailed', request => errors.push(`Request failed: ${request.url()}`));
  await page.route('**/favicon.ico', route => route.fulfill({ status: 204 }));
  await page.goto('/labs/flow-city/');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('街の流れを');
  // Each test reports runtime errors as an additional assertion, not just a log.
  (page as any).__flowErrors = errors;
});

test.afterEach(async ({ page }, testInfo) => {
  await testInfo.attach('runtime-errors', { body: JSON.stringify((page as any).__flowErrors), contentType: 'application/json' });
  expect((page as any).__flowErrors).toEqual([]);
});

test('same inputs stay equal; signal candidate resets and runs visibly', async ({ page }, testInfo) => {
  await page.locator('#speed').selectOption('80');
  await page.getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(100);
  await page.getByRole('button', { name: '一時停止', exact: true }).click();
  await expect(page.locator('#difference')).toHaveText('B − A：到着 0台 / 待機 0台·tick');
  const paused = await page.locator('#clock').innerText();
  await page.waitForTimeout(250);
  await expect(page.locator('#clock')).toHaveText(paused);
  await page.getByRole('button', { name: '東行に合わせる' }).click();
  await expect(page.locator('#clock')).toHaveText('0 / 720 tick');
  await expect(page.locator('#green')).toHaveValue('26');
  await expect(page.locator('#offset')).toHaveValue('8');
  await page.getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(160);
  await page.getByRole('button', { name: '一時停止', exact: true }).click();
  await expect(page.locator('#difference')).not.toHaveText('比較を開始すると結果が出ます');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('comparison.png'), fullPage: true });
});

test('storage failure is explained and comparison remains usable', async ({ page }) => {
  await page.evaluate(() => { Storage.prototype.setItem = () => { throw new DOMException('denied', 'SecurityError'); }; });
  await page.getByRole('button', { name: '設定を保存', exact: true }).click();
  await expect(page.locator('#status')).toContainText('保存できませんでした');
  await page.getByRole('button', { name: '比較を開始', exact: true }).click();
  await expect.poll(async () => Number((await page.locator('#clock').innerText()).split(' / ')[0])).toBeGreaterThan(0);
});

test('empty restore, saved preset reload, and reset are recoverable', async ({ page }, testInfo) => {
  await page.getByRole('button', { name: '保存を復元', exact: true }).click();
  await expect(page.locator('#status')).toContainText('保存された設定がありません');
  await page.getByRole('button', { name: '東行に合わせる' }).click();
  await page.getByRole('button', { name: '設定を保存', exact: true }).click();
  await expect(page.locator('#status')).toContainText('設定を保存しました');
  await page.reload();
  await page.getByRole('button', { name: '保存を復元', exact: true }).click();
  await expect(page.locator('#green')).toHaveValue('26');
  await expect(page.locator('#offset')).toHaveValue('8');
  await expect(page.locator('#status')).toContainText('復元しました');
  await page.getByRole('button', { name: '最初から', exact: true }).click();
  await expect(page.locator('#clock')).toHaveText('0 / 720 tick');
  await expect(page.locator('#metricsA b')).toHaveText(['0', '0', '0']);
  await expect(page.locator('#metricsB b')).toHaveText(['0', '0', '0']);
  await page.screenshot({ path: testInfo.outputPath('reset.png'), fullPage: true });
});
