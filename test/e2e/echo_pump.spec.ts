import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  const issues: string[] = [];
  page.on('console', message => {
    if (message.type() === 'error') issues.push(`console: ${message.text()}`);
  });
  page.on('requestfailed', request => issues.push(`request: ${request.url()}`));
  page.on('response', response => {
    if (response.status() >= 500) issues.push(`http: ${response.status()} ${response.url()}`);
  });
  page.on('pageerror', error => issues.push(`page: ${error.message}`));
  (page as any).__echoIssues = issues;
});

test.afterEach(async ({ page }, info) => {
  const issues: string[] = (page as any).__echoIssues;
  await info.attach('browser-issues', {
    body: JSON.stringify(issues), contentType: 'application/json',
  });
  expect(issues).toEqual([]);
});

test('power, escape and retry work in the browser', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'ゲーム開始', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', { name, exact: true });
  await expect(button('A 搬入')).toBeVisible({ timeout: 30000 });
  await page.screenshot({ path: info.outputPath('start.png'), fullPage: true });
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).map(animation =>
      animation.finished.catch(() => undefined)));
  });
  // Flutter paints on canvas: capture settled frames as the motion fallback.
  for (let frame = 0; frame < 3; frame++) {
    await page.waitForTimeout(300);
    await page.screenshot({ path: info.outputPath(`frame-${frame}.png`) });
  }
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
  await expect(button('ゲーム開始')).toBeVisible();
  await expect(button('A 搬入')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('contact failure can recover with retry', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'ゲーム開始', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', { name, exact: true });
  await expect(button('中央廊下へ')).toBeVisible({ timeout: 30000 });
  await expect(button('出口へ')).toBeDisabled();
  for (let contact = 0; contact < 3; contact++) {
    await button('中央廊下へ').click();
    await button('ポンプ室へ').click();
  }
  await expect(button('リトライ')).toBeVisible();
  await expect(button('1ターン待つ')).toBeDisabled();
  await button('リトライ').click();
  await expect(button('中央廊下へ')).toBeEnabled();
});


test('opening artwork and keyboard start', async ({ page }, info) => {
  await page.goto('/');
  const start = page.getByRole('button', { name: 'ゲーム開始', exact: true });
  await expect(start).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).map(animation =>
      animation.finished.catch(() => undefined)));
  });
  for (let frame = 0; frame < 3; frame++) {
    await page.waitForTimeout(300);
    await page.screenshot({ path: info.outputPath(`opening-${frame}.png`), fullPage: true });
  }
  await start.focus();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).toBeVisible();
  await expect(start).toHaveCount(0);
});
