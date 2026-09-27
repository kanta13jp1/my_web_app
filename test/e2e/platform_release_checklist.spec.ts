import { test, expect } from '@playwright/test';

test('platform release checklist keeps default status separate and restores a clear', async ({ page }) => {
  await page.goto('/platform-release-checklist');
  await expect(page.getByText('プラットフォーム別リリース確認', { exact: true })).toBeVisible();

  const untested = page.getByText('未確認', { exact: true });
  await expect(untested).toHaveCount(3);
  await untested.nth(0).click();
  await page.getByText('確認済み', { exact: true }).click();
  await page.getByLabel('Web の確認メモ').fill('Chrome で確認');
  await page.getByRole('button', { name: '確認内容を空にする' }).click();
  await expect(page.getByText('未確認', { exact: true })).toHaveCount(3);
  await page.getByRole('button', { name: '元に戻す' }).click();
  await expect(page.getByText('確認済み', { exact: true })).toHaveCount(1);
  await expect(page.getByLabel('Web の確認メモ')).toHaveValue('Chrome で確認');
});
