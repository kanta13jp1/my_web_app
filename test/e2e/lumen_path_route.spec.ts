import { expect, test } from '@playwright/test';

test('integrated route supports solve, undo, three colors and reload', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(`console: ${message.text()}`);
  });
  page.on('requestfailed', request => errors.push(`request: ${request.url()}`));
  page.on('response', response => {
    if (response.status() >= 400) errors.push(`HTTP ${response.status()}: ${response.url()}`);
  });
  // The existing visual-test build points shared shell services at this
  // deliberately isolated origin. Stub only observed shell endpoints; keep
  // all request/console/error assertions, and never intercept Lumen assets.
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
  const response = await page.goto('/lumen-path', { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBe(true);
  expect(new URL(page.url()).pathname).toBe('/lumen-path');
  const iframe = page.locator('iframe[title="LUMEN PATH 光の経路パズル"]');
  await expect(iframe).toBeVisible({ timeout: 60_000 });
  await page.locator('#seo-shell').waitFor({ state: 'detached', timeout: 10_000 });
  await expect(iframe).toHaveAttribute('src', '/labs/lumen-path/index.html');
  const puzzle = page.frameLocator('iframe[title="LUMEN PATH 光の経路パズル"]');
  await expect(puzzle.locator('#moves')).toHaveText('0');
  await expect(puzzle.locator('#next')).toBeDisabled();
  await page.screenshot({ path: info.outputPath('integrated-initial.png'), fullPage: true });

  await puzzle.getByRole('button', { name: /鏡 1/ }).click();
  await expect(puzzle.locator('#lit')).toHaveText('1 / 1 LIGHTS');
  await expect(puzzle.locator('#next')).toBeEnabled();
  await puzzle.getByRole('button', { name: '一手戻す' }).click();
  await expect(puzzle.locator('#moves')).toHaveText('0');
  await expect(puzzle.locator('#next')).toBeDisabled();
  await puzzle.locator('#level').selectOption('2');
  for (let i = 1; i <= 3; i++) {
    await puzzle.getByRole('button', { name: new RegExp(`鏡 ${i}、`) }).click();
  }
  await expect(puzzle.locator('#lit')).toHaveText('3 / 3 LIGHTS');
  await expect(puzzle.locator('#status')).toContainText('3色すべて点灯');
  await puzzle.locator('#board').screenshot({ path: info.outputPath('integrated-solved-board.png') });
  await puzzle.getByRole('button', { name: '最初から' }).scrollIntoViewIfNeeded();
  const frameBounds = await iframe.boundingBox();
  expect(frameBounds).not.toBeNull();
  expect(frameBounds!.x).toBeGreaterThanOrEqual(0);
  expect(frameBounds!.x + frameBounds!.width).toBeLessThanOrEqual(page.viewportSize()!.width + 1);
  expect(await puzzle.locator('html').evaluate(element => element.scrollWidth <= element.clientWidth)).toBe(true);
  await page.screenshot({ path: info.outputPath('integrated-solved.png'), fullPage: true });

  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(iframe).toBeVisible({ timeout: 60_000 });
  await expect(puzzle.locator('#moves')).toHaveText('0');
  await expect(puzzle.locator('#title')).toHaveText('最初の反射');
  await expect(puzzle.locator('#next')).toBeDisabled();
  await info.attach('runtime-errors', {
    body: JSON.stringify(errors, null, 2), contentType: 'application/json',
  });
  expect(errors).toEqual([]);
});
