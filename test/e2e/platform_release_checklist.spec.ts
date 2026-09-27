import { test, expect, type Page } from '@playwright/test';

async function enableFlutterAccessibility(page: Page) {
  const placeholder = page.locator('flt-semantics-placeholder').first();
  await placeholder.waitFor({ state: 'attached', timeout: 5_000 }).catch(
    () => undefined,
  );
  if ((await placeholder.count()) > 0) {
    await placeholder.evaluate((element) => (element as HTMLElement).click());
  }
}

test('platform release checklist starts each platform as untested', async ({ page }) => {
  await page.goto('/#/platform-release-checklist');
  await enableFlutterAccessibility(page);
  await expect(page.getByText('プラットフォーム別リリース確認', { exact: true })).toBeVisible();
  await expect(page.getByText('未確認', { exact: true })).toHaveCount(3);
});

test('platform release checklist reloads a platform result and note', async ({ page }) => {
  await page.goto('/#/platform-release-checklist');
  await enableFlutterAccessibility(page);
  await page.getByText('未確認', { exact: true }).nth(0).click();
  await page.getByText('確認済み', { exact: true }).click();
  await page.getByLabel('Web の確認メモ').fill('Chrome で確認');
  await page.waitForTimeout(300);
  await page.reload();
  await enableFlutterAccessibility(page);
  await expect(page.getByText('確認済み', { exact: true })).toHaveCount(1);
  await expect(page.getByLabel('Web の確認メモ')).toHaveValue('Chrome で確認');
});

test('platform release checklist restores a cleared result and note', async ({ page }) => {
  await page.goto('/#/platform-release-checklist');
  await enableFlutterAccessibility(page);
  await page.getByText('未確認', { exact: true }).nth(0).click();
  await page.getByText('確認済み', { exact: true }).click();
  await page.getByLabel('Web の確認メモ').fill('Chrome で確認');
  await page.getByRole('button', { name: '確認内容を空にする' }).click();
  await expect(page.getByText('未確認', { exact: true })).toHaveCount(3);
  await page.getByRole('button', { name: '元に戻す' }).click();
  await expect(page.getByText('確認済み', { exact: true })).toHaveCount(1);
  await expect(page.getByLabel('Web の確認メモ')).toHaveValue('Chrome で確認');
});
