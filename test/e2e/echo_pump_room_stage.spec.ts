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
  const beforeLongWalk = await page.evaluate(() => (window as any).__roomSteps);
  await button('中央廊下の扉を調べる').click();
  await page.mouse.move(100, 200);await page.mouse.wheel(0, -30000);
  await page.waitForTimeout(200);
  await page.screenshot({path: info.outputPath('walk-cycle-first.png'), scale:'css'});
  await page.waitForTimeout(300);
  await page.screenshot({path: info.outputPath('walk-cycle-repeat.png'), scale:'css'});
  await expect(button('扉を開けて進む')).toBeVisible();
  expect(await page.evaluate(() => (window as any).__roomSteps)-beforeLongWalk).toBeGreaterThan(2);
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


for (const missingArt of [false, true]) {
test(`find, inspect and install the fuse ${missingArt ? 'with image failure' : 'with Blender art'} without spending turns on the inventory`, async ({ page }, info) => {
  let imageRequests = 0;
  await page.route('**/assets/echo_pump/fuse_blender.png', async route => {
    imageRequests++;
    if (missingArt) await route.abort(); else await route.continue();
  });
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  await page.goto('/');
  await button('ゲーム開始').click();
  await button('スキップして開始').click();
  await button('所持品を開く').click();
  await expect(page.getByText('所持品は空', { exact: true })).toBeVisible();
  await button('所持品を閉じる').click();
  await expect(page.getByText('ターン 0', { exact: true })).toBeVisible();
  await page.getByRole('checkbox', { name: 'B 整備', exact: true }).click();
  await page.getByRole('checkbox', { name: 'A 搬入', exact: true }).click();
  await button('中央廊下へ').click();
  await button('工具庫へ').click();
  await page.mouse.move(100, 200);
  await page.mouse.wheel(0, 30000);
  await page.waitForTimeout(300);
  await page.screenshot({ path: info.outputPath('fuse-shelf.png'), scale: 'css' });
  await button('ヒューズを回収').click();
  await expect(button('ヒューズを回収')).toBeDisabled();
  await button('所持品を開く').click();
  await expect(page.getByText('所持数 1', { exact: true })).toBeVisible();
  await expect(button('このヒューズで修理')).toHaveCount(0);
  expect(imageRequests).toBeGreaterThan(0);
  await page.screenshot({ path: info.outputPath('inventory-carried.png'), scale: 'css' });
  await button('所持品を閉じる').click();
  await expect(page.getByText('ターン 5', { exact: true })).toBeVisible();
  await button('中央廊下へ').click();
  await button('ポンプ室へ').click();
  await button('所持品を開く').click();
  await button('このヒューズで修理').click();
  await expect(page.getByText('ターン 8', { exact: true })).toBeVisible();
  await button('所持品を開く').click();
  await expect(page.getByText('ポンプへ装着済み', { exact: true })).toBeVisible();
  await expect(page.getByText('所持数 0', { exact: true })).toBeVisible();
  await expect(button('このヒューズで修理')).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('inventory-installed.png'), scale: 'css' });
  await button('所持品を閉じる').click();
  await expect(page.getByText('ターン 8', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});

}

for (const missingWorkshop of [false, true]) {
test(`workshop artwork, power and collection ${missingWorkshop ? 'with image fallback' : 'with scenery'}`, async ({page}, info) => {
  test.setTimeout(90000);
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.emulateMedia({reducedMotion: missingWorkshop ? 'reduce' : 'no-preference'});
  if (missingWorkshop) await page.route('**/workshop_background.png', route => route.abort());
  const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', {name, exact:true});
  const scene = (powered: boolean, collected: boolean) => page.getByRole('img', {name:`工具庫の探索画像：${powered ? 'B整備通電' : 'B整備停止'}、${collected ? 'ヒューズ回収済み' : 'ヒューズ未回収'}`, exact:true});
  await page.goto('/');await button('ゲーム開始').click();await button('スキップして開始').click();
  async function act(...names: string[]) {for (const name of names) {await button(name).click();await expect(button('演出をスキップ')).toHaveCount(0);}}
  await act('中央廊下へ','工具庫へ');
  await page.mouse.move(100,200);await page.mouse.wheel(0,30000);await page.waitForTimeout(350);
  await expect(scene(false,false)).toBeAttached();
  await page.screenshot({path:info.outputPath('workshop-locked.png'),scale:'css'});
  await act('中央廊下へ','管理室へ','B 整備','A 搬入','中央廊下へ','工具庫へ');
  await page.mouse.move(100,200);await page.mouse.wheel(0,30000);await page.waitForTimeout(350);
  await expect(scene(true,false)).toBeAttached();
  await page.waitForTimeout(800);await page.screenshot({path:info.outputPath('workshop-lit.png'),scale:'css'});
  await button('ヒューズを回収').click();
  await expect(scene(true,true)).toBeAttached();
  if (!missingWorkshop) {await page.waitForTimeout(150);await page.screenshot({path:info.outputPath('workshop-collecting.png'),scale:'css'});}
  await page.waitForTimeout(800);await page.mouse.move(100,200);await page.mouse.wheel(0,30000);await page.waitForTimeout(200);
  await page.screenshot({path:info.outputPath('workshop-collected.png'),scale:'css'});
  await expect(button('ヒューズを回収')).toBeDisabled();
  await button('所持品を開く').click();await expect(page.getByText('所持数 1',{exact:true})).toBeVisible();
  await button('所持品を閉じる').click();await expect(page.getByText('ターン 9',{exact:true}).first()).toBeAttached();
  expect(errors).toEqual([]);
});
}
