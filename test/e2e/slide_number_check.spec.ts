import { test, expect, type Page } from '@playwright/test';
async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByRole('button', { name: '数字を確認する', exact: true })).toBeVisible({ timeout: 30000 });
}
async function check(page: Page) {
  await page.getByRole('button', { name: '数字を確認する', exact: true }).click();
}
test('growth uses the baseline', async ({ page }, info) => {
  await open(page);
  await check(page);
  await expect(page.getByRole('group', { name: '増加率: 25.00%', exact: false })).toBeVisible();
  await page.screenshot({ path: info.outputPath('growth.png') });
});
test('rates distinguish points and relative growth', async ({ page }, info) => {
  await open(page);
  await page.getByRole('switch').click();
  await page.getByRole('textbox').nth(0).fill('10');
  await page.getByRole('textbox').nth(1).fill('15');
  await check(page);
  await expect(page.getByRole('group', { name: '増加率: 50.00%', exact: false })).toBeVisible();
  await expect(page.getByRole('group', { name: 'ポイント差: 5.00ポイント', exact: false })).toBeVisible();
  await page.screenshot({ path: info.outputPath('points.png') });
});
test('invalid baseline clears the result and can recover', async ({ page }, info) => {
  await open(page);
  await check(page);
  await page.getByRole('textbox').nth(0).fill('0');
  await expect(page.getByRole('group', { name: '増加率: 25.00%', exact: false })).toHaveCount(0);
  await check(page);
  await expect(page.getByRole('group', { name: /基準は0より大きく/ })).toBeVisible();
  await page.getByRole('textbox').nth(0).fill('80');
  await check(page);
  await expect(page.getByRole('group', { name: '増加率: 25.00%', exact: false })).toBeVisible();
  await page.screenshot({ path: info.outputPath('recovered.png') });
});
