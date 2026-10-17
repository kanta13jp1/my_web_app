import { test, expect } from '@playwright/test';

test.setTimeout(60000);

test('room walking, memo and door preserve turn rules with real footsteps', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    (window as any).__roomSteps = 0;
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      const result = play.call(this);
      result.then(() => { if ((this.currentSrc || this.src).includes('/step.wav')) (window as any).__roomSteps++; }, () => {});
      return result;
    };
  });
  await page.goto('/');
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  await expect(button('ゲーム開始')).toBeVisible({ timeout: 30000 });
  await button('音をON').click();
  await button('ゲーム開始').click();
  await button('スキップして開始').click();
  await expect(button('保守メモを調べる')).toBeVisible();
  await page.mouse.move(100, 200);
  await page.mouse.wheel(0, -30000);
  await page.waitForTimeout(600);
  await page.screenshot({ path: info.outputPath('room-overview.png') });
  await button('設備寄りに見る').click();
  await expect(button('全景へ')).toBeVisible();
  await button('保守メモを調べる').click();
  await expect(page.getByText('夜間保守メモ 1 / 2', { exact: true })).toBeVisible();
  await expect.poll(() => page.evaluate(() => (window as any).__roomSteps)).toBe(2);
  await page.screenshot({ path: info.outputPath('memo-page-one.png') });
  await button('次のページ').click();
  await expect(page.getByText('夜間保守メモ 2 / 2', { exact: true })).toBeVisible();
  await button('メモを閉じる').click();
  await button('保守メモを調べる').click();
  await expect(page.getByText('夜間保守メモ 1 / 2', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => (window as any).__roomSteps)).toBe(2);
  await button('メモを閉じる').click();
  await button('中央廊下の扉を調べる').click();
  await expect(button('扉を開けて進む')).toBeVisible();
  await page.screenshot({ path: info.outputPath('door-confirmation.png') });
  await button('戻る').click();
  await expect(page.getByText('ターン 0', { exact: true })).toBeVisible();
  await button('中央廊下の扉を調べる').click();
  await button('扉を開けて進む').click();
  await expect(page.getByText('ターン 1', { exact: true })).toBeVisible();
  await expect(button('工具庫へ')).toBeVisible();
  await page.screenshot({ path: info.outputPath('hall-after-door.png') });
  expect(errors).toEqual([]);
});


test('first walk keeps the protagonist while the preloaded sheet is delayed', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  let releaseArt!: () => void;
  const artGate = new Promise<void>(resolve => { releaseArt = resolve; });
  let requested = false;
  await page.route('**/assets/echo_pump/character_walk.png', async route => {
    requested = true;
    await artGate;
    await route.continue();
  });
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  try {
    await page.goto('/');
    await button('ゲーム開始').click();
    await button('スキップして開始').click();
    await expect(button('保守メモを調べる')).toBeVisible();
    await expect.poll(() => requested).toBe(true);
    await page.mouse.move(100, 200);
    await page.mouse.wheel(0, -30000);
    await button('保守メモを調べる').click();
    await expect(page.getByText('歩行中…', { exact: true }).first()).toBeVisible();
    await page.screenshot({ path: info.outputPath('first-walk-art-pending.png'), scale: 'css' });
    await expect(page.getByText('夜間保守メモ 1 / 2', { exact: true })).toBeVisible();
    const response = page.waitForResponse(r => r.url().endsWith('/character_walk.png'));
    releaseArt();
    await response;
    await button('メモを閉じる').click();
    await page.waitForTimeout(300);
    await button('中央廊下の扉を調べる').click();
    await expect(page.getByText('歩行中…', { exact: true }).first()).toBeVisible();
    await page.screenshot({ path: info.outputPath('walk-art-ready.png'), scale: 'css' });
    await expect(button('扉を開けて進む')).toBeVisible();
    await button('戻る').click();
    await expect(page.getByText('ターン 0', { exact: true })).toBeVisible();
    expect(errors).toEqual([]);
  } finally {
    releaseArt();
  }
});
