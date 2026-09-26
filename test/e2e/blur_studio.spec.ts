import { test, expect } from '@playwright/test';

const route = '/labs/blur-studio/index.html';

test('adjust background, disable effect, and recover with reset', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('requestfailed', r => errors.push(r.url()));
  await page.goto(route);
  await expect(page.getByRole('heading', { level: 1 })).toContainText('やわらかく');
  const slider = page.getByLabel('ぼかしの強さ');
  await slider.focus();
  await slider.press('Home');
  await slider.press('ArrowRight');
  await expect(page.locator('#status')).toHaveText('Apricot · 1 px');
  await page.getByLabel('色の組み合わせ').selectOption('iris');
  await expect(page.locator('#status')).toHaveText('Iris · 1 px');
  await page.getByLabel('ぼかし効果を使う').uncheck();
  await expect(slider).toBeDisabled();
  await expect(page.locator('#status')).toHaveText('Iris · ぼかしなし');
  await page.getByRole('button', { name: '最初の設定に戻す' }).click();
  await expect(slider).toBeEnabled();
  await expect(slider).toHaveValue('28');
  await expect(page.getByLabel('ぼかし効果を使う')).toBeChecked();
  await expect(page.locator('#status')).toHaveText('Apricot · 28 px');
  await page.screenshot({ path: info.outputPath('blur-studio.png'), fullPage: true });
  expect(errors).toEqual([]);
});

test('static comparison remains readable without JavaScript', async ({ browser }, info) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.goto(new URL(route, info.project.use.baseURL as string).href);
  await expect(page.getByText('JavaScriptが無効のため', { exact: false })).toBeVisible();
  await expect(page.getByLabel('ぼかしの強さ')).toBeDisabled();
  await expect(page.getByText('余白の時間', { exact: true })).toHaveCount(2);
  await page.screenshot({ path: info.outputPath('no-javascript.png'), fullPage: true });
  await context.close();
});

test('narrow viewport, larger text, and reduced motion retain usable controls', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto(route);
  await page.addStyleTag({ content: 'html { font-size: 200%; }' });
  await expect(page.getByRole('button', { name: '最初の設定に戻す' })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  for (const control of [page.getByLabel('ぼかしの強さ'), page.getByLabel('色の組み合わせ'), page.getByRole('button', { name: '最初の設定に戻す' })]) {
    const box = await control.boundingBox();
    expect(box?.height).toBeGreaterThanOrEqual(44);
  }
  await page.getByLabel('色の組み合わせ').focus();
  await page.keyboard.press('Tab');
  await expect(page.getByLabel('ぼかし効果を使う')).toBeFocused();
  await page.keyboard.press('Space');
  await expect(page.locator('#status')).toContainText('ぼかしなし');
  await page.screenshot({ path: info.outputPath('narrow-keyboard.png'), fullPage: true });
});
