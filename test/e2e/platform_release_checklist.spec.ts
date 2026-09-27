import { test, expect } from '@playwright/test';

test('platform release checklist keeps default status separate and restores a clear', async ({ page }) => {
  await page.goto('http://127.0.0.1:7358/platform-release-checklist');
  await expect(page.getByRole('heading', { name: 'プラットフォーム別リリース確認' })).toBeVisible();

  const selects = page.getByLabel('確認状態');
  await expect(selects).toHaveCount(3);
  await expect(selects.nth(0)).toHaveValue('untested');
  await selects.nth(0).selectOption('passed');
  await page.getByLabel('Web の確認メモ').fill('Chrome で確認');
  await page.getByRole('button', { name: '確認内容を空にする' }).click();
  await expect(selects.nth(0)).toHaveValue('untested');
  await page.getByRole('button', { name: '元に戻す' }).click();
  await expect(selects.nth(0)).toHaveValue('passed');
  await expect(page.getByLabel('Web の確認メモ')).toHaveValue('Chrome で確認');
});
