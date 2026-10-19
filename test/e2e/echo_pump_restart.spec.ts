import { test, expect, Page } from '@playwright/test';

async function start(page: Page) {
  await page.goto(process.env.ECHO_PUMP_GAME_PATH || '/');
  const opening = page.getByRole('button', { name: 'ゲーム開始', exact: true });
  const semantics = page.locator('flt-semantics-placeholder');
  await Promise.race([
    opening.waitFor({ timeout: 60000 }),
    semantics.waitFor({ state: 'attached', timeout: 60000 }),
  ]);
  if (await semantics.count()) await semantics.dispatchEvent('click');
  await opening.click();
  await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
}

test('cancel restart preserves the fuse, room and power through escape', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await start(page);
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  const action = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', { name, exact: true });
  const toggle = page.getByRole('switch', { name: /キーボード操作を有効にする/ });
  await toggle.click();
  for (const name of ['B 整備', 'A 搬入', '中央廊下へ', '工具庫へ', 'ヒューズを回収']) {
    await action(name).click();
  }
  await expect(page.getByText('ターン 5', { exact: true })).toBeAttached();
  await button('最初からやり直す').click();
  await expect(page.getByText('最初からやり直しますか？', { exact: true })).toBeVisible();
  await expect(page.getByText(/現在のターン 5、所持品、設備の状態はリセット/)).toBeVisible();
  await page.screenshot({ path: info.outputPath('restart-confirmation.png'), scale: 'css' });
  for (const key of ['w', 'i', 'c']) await page.keyboard.press(key);
  await expect(button('所持品を閉じる')).toHaveCount(0);
  await button('探索を続ける').click();
  await page.waitForTimeout(1000);
  await expect(page.getByText('ターン 5', { exact: true })).toBeAttached();
  await button('所持品を開く').click();
  await expect(page.getByText('所持数 1', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('restart-cancel-keeps-fuse.png'), scale: 'css' });
  await button('所持品を閉じる').click();
  await page.waitForTimeout(1000);
  for (const name of [
    '中央廊下へ', 'ポンプ室へ', 'ヒューズで修理', '中央廊下へ', '管理室へ',
    'B 整備', 'C 排水', '1ターン待つ', '1ターン待つ', '中央廊下へ',
    'ポンプ室へ', '隔壁を閉じる', '排水ポンプを起動', '中央廊下へ', '管理室へ', '出口へ',
  ]) await action(name).click();
  await expect(button('リトライ')).toBeVisible();
  await button('リトライ').click();
  await expect(page.getByText('ターン 0', { exact: true })).toBeAttached();
  await expect(page.getByText('最初からやり直しますか？', { exact: true })).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('dismiss restart keeps progress and confirm resets once with missing artwork', async ({ page }, info) => {
  test.setTimeout(90000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/assets/echo_pump/*.png', route => route.abort());
  await start(page);
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  await button('1ターン待つ').click();
  await expect(page.getByText('ターン 1', { exact: true })).toBeAttached();
  await button('最初からやり直す').click();
  await expect(button('探索を続ける')).toBeVisible();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(1000);
  await expect(page.getByText('ターン 1', { exact: true })).toBeAttached();
  await button('最初からやり直す').click();
  await expect(button('探索を続ける')).toBeVisible();
  await page.mouse.click(5, 5);
  await page.waitForTimeout(1000);
  await expect(button('探索を続ける')).toHaveCount(0);
  await expect(page.getByText('ターン 1', { exact: true })).toBeAttached();
  await button('最初からやり直す').click();
  await expect(button('探索を続ける')).toBeVisible();
  await page.screenshot({ path: info.outputPath('restart-fallback-confirmation.png'), scale: 'css' });
  await button('最初からやり直す').click();
  await page.waitForTimeout(1000);
  await expect(page.getByText('ターン 0', { exact: true })).toBeAttached();
  await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).not.toBeChecked();
  await expect(page.getByRole('checkbox', { name: 'B 整備', exact: true })).not.toBeChecked();
  await button('所持品を開く').click();
  await expect(page.getByText('所持品は空', { exact: true })).toBeVisible();
  await button('所持品を閉じる').click();
  await page.waitForTimeout(1000);
  await page.screenshot({ path: info.outputPath('restart-confirmed-reset.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
