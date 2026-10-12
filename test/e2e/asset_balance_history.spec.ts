import { test, expect } from '@playwright/test';

test.use({ timezoneId: 'Asia/Tokyo' });

test('shows minute timestamps and distinct same-day history without writes', async ({ page }, info) => {
  const financialWrites: string[] = [];
  page.on('request', request => {
    if (/\/rest\/v1\/(cfo_assets|wealth_struggles)/.test(request.url()) &&
        !['GET', 'HEAD', 'OPTIONS'].includes(request.method())) {
      financialWrites.push(request.method());
    }
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: '残高履歴', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.getByText('残高日時 2026-10-11 17:44 JST', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('balance-timestamp.png') });
  await page.getByRole('button', { name: '残高履歴', exact: true }).click();
  await expect(page.getByText('サンプル銀行の残高履歴', { exact: true })).toBeVisible();
  for (const timestamp of ['2026-10-11 17:44 JST', '2026-10-11 02:18 JST', '2026-10-09 17:39 JST']) {
    await expect(page.getByRole('group', { name: new RegExp(timestamp.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')) })).toBeVisible();
  }
  await expect(page.getByRole('group', { name: /JST.*¥12,000/ })).toHaveCount(2);
  await expect(page.getByRole('group', { name: /2026-10-09 17:39 JST.*¥-5,000/ })).toBeVisible();
  await page.screenshot({ path: info.outputPath('balance-history.png') });
  await page.getByRole('button', { name: '閉じる', exact: true }).click();
  await expect(page.getByText('サンプル銀行の残高履歴', { exact: true })).toHaveCount(0);
  expect(financialWrites).toEqual([]);
});
