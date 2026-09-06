import { test, expect } from '@playwright/test';

const path = '/labs/aero-lab/index.html';

test('engine controls, layout, reload and visible 3D render', async ({ page }, info) => {
  const errors: string[] = [];
  const external: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => { if (!request.url().startsWith('http://127.0.0.1:4173/')) external.push(request.url()); });
  await page.goto(path);
  await expect(page.locator('#scene-status')).toBeHidden();
  await expect(page.locator('canvas')).toBeVisible();
  await expect(page.locator('[data-stage]')).toHaveCount(5);
  await page.getByRole('button', { name: '60%', exact: true }).click();
  await expect(page.locator('#power-value')).toHaveText('60');
  const thrust = Number(await page.locator('#thrust').textContent());
  await page.getByRole('switch', { name: '効率低下を試す' }).check();
  expect(Number(await page.locator('#thrust').textContent())).toBeLessThan(thrust);
  await page.getByRole('switch', { name: '効率低下を試す' }).uncheck();
  await expect(page.locator('#thrust')).toHaveText(String(thrust));
  await page.getByRole('button', { name: '分解する', exact: true }).click();
  await expect(page.locator('#explode-value')).toHaveText('100%');
  await expect(page.locator('#mode')).toHaveText('EXPLODED VIEW');
  await page.getByRole('button', { name: '回転を止める' }).click();
  await expect(page.locator('#running-status')).toHaveText('Ⅱ PAUSED');
  await page.locator('[data-stage="combustor"]').click();
  await expect(page.locator('#title')).toHaveText('燃焼器');
  await expect(page.locator('#detail')).toBeVisible();
  await page.getByRole('button', { name: '部位の選択を解除' }).click();
  await expect(page.locator('#detail')).toBeHidden();
  await page.locator('#flow').uncheck();
  await expect(page.locator('#flow')).not.toBeChecked();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: info.outputPath('aero-lab.png'), fullPage: true });
  await page.reload();
  await expect(page.locator('#scene-status')).toBeHidden();
  await expect(page.locator('#power-value')).toHaveText('35');
  expect(errors).toEqual([]);
  expect(external).toEqual([]);
});

test('missing module gives a readable error instead of an endless loader', async ({ page }) => {
  await page.route('**/scene.js', (route) => route.abort());
  await page.goto(path);
  await expect(page.getByRole('alert')).toContainText('実験室を読み込めませんでした');
});

test('recording cancellation is recoverable and never requests a microphone', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(navigator.mediaDevices, 'getDisplayMedia', { value: async (options: DisplayMediaStreamOptions) => {
      if (options.audio !== false) throw new Error('Audio must remain disabled');
      throw new DOMException('Cancelled', 'NotAllowedError');
    } });
  });
  await page.goto(path);
  await expect(page.locator('#scene-status')).toBeHidden();
  await page.getByRole('button', { name: '画面を録画' }).click();
  await expect(page.locator('#record-message')).toContainText('キャンセル');
  await expect(page.locator('#record')).toBeEnabled();
  await expect(page.locator('#download')).toBeHidden();
});
