import { expect, test } from '@playwright/test';

test('integrated drawing route supports failure, recovery and arrival', async ({ page }, info) => {
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
  const response = await page.goto('/kinetic-forge', { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBe(true);
  expect(new URL(page.url()).pathname).toBe('/kinetic-forge');
  const iframe = page.locator('iframe[title="KINETIC FORGE 描画コース実験"]');
  await expect(iframe).toBeVisible({ timeout: 60_000 });
  await page.locator('#seo-shell').waitFor({ state: 'detached', timeout: 10_000 });
  await expect(iframe).toHaveAttribute('src', '/labs/kinetic-forge/index.html');
  const puzzle = page.frameLocator('iframe[title="KINETIC FORGE 描画コース実験"]');
  await expect(puzzle.locator('#line-count')).toContainText('0 /');
  await puzzle.locator('#play').click();
  await expect(puzzle.locator('#phase')).toHaveText('TRY AGAIN', {timeout:10000});
  await puzzle.locator('#retry').click();
  await puzzle.locator('#sample').click();
  await puzzle.locator('#undo').click();
  await expect(puzzle.locator('#line-count')).toContainText('0 /');
  await puzzle.locator('#sample').click();
  await puzzle.locator('#play').click();
  await expect(puzzle.locator('#phase')).toHaveText('ARRIVED', {timeout:20000});
  expect(await puzzle.locator('html').evaluate(e=>e.scrollWidth<=e.clientWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('integrated-arrived.png'),fullPage:true});
  await page.reload({waitUntil:'domcontentloaded'});
  await expect(iframe).toBeVisible({timeout:60000});
  await expect(puzzle.locator('#phase')).toHaveText('DESIGN MODE');
  await expect(puzzle.locator('#line-count')).toContainText('0 /');
  await info.attach('runtime-errors',{body:JSON.stringify(errors),contentType:'application/json'});
  expect(errors).toEqual([]);
});
