import { test, expect, type Page } from '@playwright/test';
test.use({ trace: 'retain-on-failure' });
async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByRole('button', { name: '概算費用を比較', exact: true })).toBeVisible({ timeout: 30000 });
}
async function enter(page: Page, value: string) {
  const input = page.getByRole('textbox').nth(2);
  await input.click();
  await expect(input).toBeFocused();
  const previous = await input.inputValue();
  await page.keyboard.press('End');
  for (let i = 0; i < previous.length; i++) await page.keyboard.press('Backspace');
  await expect(input).toHaveValue('');
  await page.keyboard.type(value);
  await expect(input).toHaveValue(value);
}
async function compare(page: Page) {
  await page.getByRole('button', { name: '概算費用を比較', exact: true }).click();
}
const quote = (page: Page) => page.getByRole('group', { name: /変更前 USD 0\.016254/ });
test('normal token cost comparison', async ({ page }, info) => {
  await open(page); await compare(page);
  await expect(quote(page)).toBeVisible();
  await expect(page.getByRole('group', { name: /変更後 USD 0\.242004/ })).toBeVisible();
  await page.screenshot({ path: info.outputPath('normal.png') });
});
test('zero requests are rejected', async ({ page }, info) => {
  await open(page); await enter(page, '0'); await compare(page);
  await expect(page.getByRole('group', { name: /回数は1以上の整数/ })).toBeVisible();
  await expect(quote(page)).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('invalid.png') });
});
test('editing clears a quote and correction recovers', async ({ page }, info) => {
  await open(page); await compare(page); await expect(quote(page)).toBeVisible();
  await enter(page, '0'); await expect(quote(page)).toHaveCount(0); await compare(page);
  await expect(page.getByRole('group', { name: /回数は1以上の整数/ })).toBeVisible();
  await enter(page, '1000'); await compare(page); await expect(quote(page)).toBeVisible();
  await page.screenshot({ path: info.outputPath('recovered.png') });
});
