import { test, expect } from '@playwright/test';

test('power, escape and retry work in the browser', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  await expect(button('A 搬入')).toBeVisible({ timeout: 30000 });
  await page.screenshot({ path: info.outputPath('start.png'), fullPage: true });
  const click = async (name: string) => {
    await button(name).click();
  };
  for (const label of [
    'B 整備', 'A 搬入', '中央廊下へ', '工具庫へ', 'ヒューズを回収',
    '中央廊下へ', 'ポンプ室へ', 'ヒューズで修理', '中央廊下へ', '管理室へ',
    'B 整備', 'C 排水', '1ターン待つ', '1ターン待つ', '中央廊下へ',
    'ポンプ室へ', '隔壁を閉じる', '排水ポンプを起動', '中央廊下へ', '管理室へ', '出口へ',
  ]) await click(label);
  await expect(button('リトライ')).toBeVisible();
  await page.screenshot({ path: info.outputPath('escaped.png'), fullPage: true });
  await click('リトライ');
  await expect(button('B 整備')).toBeVisible();
  await page.reload();
  await expect(button('A 搬入')).toBeVisible();
  expect(errors).toEqual([]);
});
