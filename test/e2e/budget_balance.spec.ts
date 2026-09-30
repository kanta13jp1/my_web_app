import { test, expect, type Page } from '@playwright/test';

const labels = ['毎月の手取り', '必須生活費・返済', '年払い・臨時支出', '現金の予備費積立', '今の楽しみ', '投資積立'];
const balanceCard = (page: Page) => page.getByRole('group', { name: /^今と将来の配分チェック / });
const result = (page: Page, title: string) => balanceCard(page).getByText(new RegExp(`^${title}(?:\\s|$)`));
const input = (page: Page, i: number) => page.getByRole('textbox', { name: new RegExp(`^${labels[i]}`) });
async function rendered(page: Page) {
  await page.evaluate(() => new Promise<void>(resolve =>
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
}
async function amount(page: Page, i: number, value: string) {
  await input(page, i).scrollIntoViewIfNeeded();
  await input(page, i).click();
  await rendered(page);
  await expect(input(page, i)).toBeFocused();
  await input(page, i).press('ControlOrMeta+A');
  await input(page, i).press('Backspace');
  if (value) await input(page, i).pressSequentially(value, { delay: 40 });
  await rendered(page);
  await expect(input(page, i)).toHaveValue(value);
}
async function example(page: Page) {
  const values = ['230000', '110000', '120000', '10000', '20000', '50000'];
  for (let i = 0; i < values.length; i++) await amount(page, i, values[i]);
  for (let i = 0; i < values.length; i++) await expect(input(page, i)).toHaveValue(values[i]);
}
const calculate = (page: Page) => page.getByRole('button', { name: '配分を確認する', exact: true }).click();
test.afterEach(async ({ page }, info) => {
  if (info.status !== info.expectedStatus) {
    await info.attach('visible-dom', { body: await page.content(), contentType: 'text/html' });
  }
});
test.beforeEach(async ({ page }) => {
  await page.goto('/budget-financial-planner?tab=simulation');
  await expect(balanceCard(page)).toBeVisible({ timeout: 20000 });
  await expect(page.getByRole('button', { name: '記録追加', exact: true })).toHaveCount(0);
});

test('annual costs and allocations show the actual remainder', async ({ page }, info) => {
  await example(page);
  await calculate(page);
  await expect(result(page, '配分後の残り 30,000円')).toBeVisible();
  await result(page, '配分後の残り 30,000円').scrollIntoViewIfNeeded();
  await expect(result(page, '配分後の残り 30,000円')).toContainText('年間支出の月割り：10,000円');
  await page.screenshot({ path: info.outputPath('allocation-normal.png') });
});

test('unknown and malformed costs are not zero; correcting the field recovers', async ({ page }, info) => {
  await example(page);
  await amount(page, 2, '');
  await calculate(page);
  await expect(balanceCard(page).getByText('未確認です。金額を確認し、支出がない場合は0を入力してください', { exact: true })).toBeVisible();
  await expect(result(page, '配分後の残り 30,000円')).toHaveCount(0);
  await amount(page, 2, '-1');
  await expect(balanceCard(page).getByText('未確認です。金額を確認し、支出がない場合は0を入力してください', { exact: true })).toHaveCount(0);
  await calculate(page);
  await expect(balanceCard(page).getByText('0以上の整数で入力してください（例：230000）', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('allocation-invalid.png') });
  await amount(page, 2, '0');
  await calculate(page);
  await expect(result(page, '配分後の残り 40,000円')).toBeVisible();
  await result(page, '配分後の残り 40,000円').scrollIntoViewIfNeeded();
  await page.screenshot({ path: info.outputPath('allocation-recovered.png') });
});

test('changed input invalidates old result, deficit is explicit, reload forgets trial data', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await example(page);
  await calculate(page);
  await amount(page, 5, '150000');
  await expect(result(page, '配分後の残り 30,000円')).toHaveCount(0);
  await calculate(page);
  await expect(result(page, '毎月 70,000円の不足')).toBeVisible();
  await result(page, '毎月 70,000円の不足').scrollIntoViewIfNeeded();
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a =>
      a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`allocation-deficit-${i}.png`) });
    await page.waitForTimeout(250);
  }
  await page.reload();
  await expect(balanceCard(page)).toBeVisible({ timeout: 20000 });
  await input(page, 0).focus();
  await expect(input(page, 0)).toHaveValue('');
  await expect(result(page, '毎月 70,000円の不足')).toHaveCount(0);
  expect(errors).toEqual([]);
});
