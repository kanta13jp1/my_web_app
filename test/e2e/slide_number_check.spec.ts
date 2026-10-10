import { test, expect, type Page } from '@playwright/test';

test.use({ trace: 'retain-on-failure' });
test.afterEach(async ({ page }, info) => {
  if (info.status === info.expectedStatus) return;
  await info.attach('input-state', {
    body: JSON.stringify(await page.locator('input, textarea').evaluateAll(elements =>
      elements.map(element => ({
        tag: element.tagName,
        className: element.className,
        label: element.getAttribute('aria-label'),
        value: (element as HTMLInputElement).value,
        focused: element === document.activeElement,
        parent: element.parentElement?.tagName,
      }))), null, 2),
    contentType: 'application/json',
  });
});

async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByRole('button', { name: '数字を確認する', exact: true })).toBeVisible({ timeout: 30000 });
}
async function enter(page: Page, index: number, value: string) {
  const input = page.getByRole('textbox').nth(index);
  await input.click();
  await expect(input).toBeFocused();
  await input.press('ControlOrMeta+A');
  await input.press('Backspace');
  await expect(input).toHaveValue('');
  await page.keyboard.type(value);
  await expect(input).toHaveValue(value);
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
  await enter(page, 0, '10');
  await enter(page, 1, '15');
  await check(page);
  await expect(page.getByRole('group', { name: '増加率: 50.00%', exact: false })).toBeVisible();
  await expect(page.getByRole('group', { name: 'ポイント差: 5.00ポイント', exact: false })).toBeVisible();
  await page.screenshot({ path: info.outputPath('points.png') });
});
test('invalid baseline clears the result and can recover', async ({ page }, info) => {
  await open(page);
  await check(page);
  await enter(page, 0, '0');
  await expect(page.getByRole('group', { name: '増加率: 25.00%', exact: false })).toHaveCount(0);
  await check(page);
  await expect(page.getByRole('group', { name: /基準は0より大きく/ })).toBeVisible();
  await enter(page, 0, '80');
  await check(page);
  await expect(page.getByRole('group', { name: '増加率: 25.00%', exact: false })).toBeVisible();
  await page.screenshot({ path: info.outputPath('recovered.png') });
});
