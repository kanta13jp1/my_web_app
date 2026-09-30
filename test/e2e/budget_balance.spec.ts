import { test, expect, type Page } from '@playwright/test';

const labels = ['毎月の手取り', '必須生活費・返済', '年払い・臨時支出', '現金の予備費積立', '今の楽しみ', '投資積立'];
const input = (page: Page, i: number) => page.getByRole('textbox', { name: new RegExp(`^${labels[i]}`) });
async function amount(page: Page, i: number, value: string) {
  await input(page, i).focus();
  await expect(input(page, i)).toBeFocused();
  await input(page, i).fill(value);
}
async function example(page: Page) {
  const values = ['230000', '110000', '120000', '10000', '20000', '50000'];
  for (let i = 0; i < values.length; i++) await amount(page, i, values[i]);
}
const calculate = (page: Page) => page.getByRole('button', { name: '配分を確認する', exact: true }).click();
test.beforeEach(async ({ page }) => {
  await page.goto('/budget-financial-planner?tab=simulation');
  await expect(page.getByText('今と将来の配分チェック', { exact: true })).toBeVisible({ timeout: 60000 });
});

test('annual costs and allocations show the actual remainder', async ({ page }, info) => {
  await example(page);
  await calculate(page);
  await expect(page.getByText('配分後の残り 30,000円', { exact: true })).toBeVisible();
  await expect(page.getByText('年間支出の月割り：10,000円', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('allocation-normal.png') });
});

test('unknown and malformed costs are not zero; correcting the field recovers', async ({ page }, info) => {
  await example(page);
  await amount(page, 2, '');
  await calculate(page);
  await expect(page.getByText('未確認です。金額を確認し、支出がない場合は0を入力してください', { exact: true })).toBeVisible();
  await expect(page.getByText('配分後の残り 30,000円', { exact: true })).toHaveCount(0);
  await amount(page, 2, '-1');
  await calculate(page);
  await expect(page.getByText('0以上の整数で入力してください（例：230000）', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('allocation-invalid.png') });
  await amount(page, 2, '0');
  await calculate(page);
  await expect(page.getByText('配分後の残り 40,000円', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('allocation-recovered.png') });
});

test('changed input invalidates old result, deficit is explicit, reload forgets trial data', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await example(page);
  await calculate(page);
  await amount(page, 5, '150000');
  await expect(page.getByText('配分後の残り 30,000円', { exact: true })).toHaveCount(0);
  await calculate(page);
  await expect(page.getByText('毎月 70,000円の不足', { exact: true })).toBeVisible();
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a =>
      a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`allocation-deficit-${i}.png`) });
    await page.waitForTimeout(250);
  }
  await page.reload();
  await expect(page.getByText('今と将来の配分チェック', { exact: true })).toBeVisible({ timeout: 60000 });
  await input(page, 0).focus();
  await expect(input(page, 0)).toHaveValue('');
  await expect(page.getByText('毎月 70,000円の不足', { exact: true })).toHaveCount(0);
  expect(errors).toEqual([]);
});
