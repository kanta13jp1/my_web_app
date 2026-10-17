import { test, expect } from '@playwright/test';

test('API reference exposes contract, example and correction links on a narrow or wide screen', async ({ page }, testInfo) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('requestfailed', (request) => errors.push(request.url()));
  page.on('response', (response) => { if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`); });
  await page.goto('/labs/shared/reference.html');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('JSON保存 APIリファレンス');
  await expect(page.getByText('保存完了を表すPromiseや結果は返さない。', { exact: false })).toBeVisible();
  await page.getByRole('link', { name: '使用例', exact: true }).click();
  await expect(page).toHaveURL(/#examples$/);
  await expect(page.locator('#examples')).toContainText("downloadJson({ version: 1, theme: 'light' }, 'settings.json')");
  await page.getByRole('link', { name: '修正方法', exact: true }).click();
  await expect(page.getByRole('link', { name: '元のJSDocを修正' })).toHaveAttribute('href', 'https://github.com/kanta13jp1/my_web_app/blob/main/web/labs/shared/download-json.mjs');
  await expect(page.getByRole('link', { name: '文書更新ガイドと設計上の判断' })).toHaveAttribute('href', /docs\/LAB_API_REFERENCE.md$/);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.goto('/labs/shared/reference.html');
  await page.screenshot({ path: testInfo.outputPath('api-reference.png'), fullPage: true });
  expect(errors).toEqual([]);
});
