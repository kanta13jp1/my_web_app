import { test, expect, type Page } from '@playwright/test';
test('ROM-free 1-1 manual play, pause and restart need no API', async ({page},info)=>{
  const errors: string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
  await expect(lab.locator('#mode')).toHaveValue('recreation');
  await lab.locator('#play-local').click();
  await page.keyboard.down('ArrowRight');await page.waitForTimeout(450);await page.keyboard.down('Space');await page.waitForTimeout(250);await page.keyboard.up('Space');await page.keyboard.up('ArrowRight');
  await expect(lab.locator('#progress')).not.toContainText('x=32 ');
  await lab.locator('#stop').click();const stopped=await lab.locator('#progress').textContent();await page.waitForTimeout(250);await expect(lab.locator('#progress')).toHaveText(stopped!);
  await expect(lab.locator('#counts')).toHaveText('0 / 0 / 0');
  await screenshot(page,info.outputPath('world11-manual.png'));
  await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('リセット');
  expect(errors).toEqual([]);
});
test('Jev bridge controls the recreation',async({page},info)=>{
  await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
  await expect(lab.locator('#status')).toContainText('準備完了');await lab.locator('#consent').check();await lab.locator('#start').click();
  await expect(lab.locator('#counts')).not.toHaveText('0 / 0 / 0');await page.waitForTimeout(300);await lab.locator('#stop').click();
  await expect(lab.locator('#state')).toContainText('previous_response_ms');await expect(lab.locator('#action')).toHaveText('操作: noop');
  await screenshot(page,info.outputPath('world11-jev-fixture.png'));
});
async function screenshot(page: Page, path: string) {
  // Expand only the test harness height so the full iframe document is visible.
  await page.locator('iframe').evaluate((element) => {
    const frame = element as HTMLIFrameElement;
    frame.style.height = `${frame.contentDocument!.documentElement.scrollHeight}px`;
    frame.contentWindow!.scrollTo(0, 0);
  });
  await page.screenshot({ path, fullPage: true });
}

test('fixed-state benchmark produces labelled measurements and export', async ({ page }, info) => {
  const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto('/test/e2e/jev_mario_harness.html');
  const lab = page.frameLocator('iframe');
  await expect(lab.locator('#status')).toContainText('準備完了');
  await lab.locator('#mode').selectOption('fixture');
  expect(await lab.locator('body').evaluate(() => innerWidth)).toBe(page.viewportSize()!.width);
  await lab.getByRole('button', { name: 'Jev測定を開始', exact: true }).click();
  await expect(lab.locator('#status')).toContainText('同意');
  await lab.locator('#consent').check();
  await lab.locator('#start').click();
  await expect(lab.locator('#counts')).toHaveText('20 / 0 / 0', { timeout: 15000 });
  await expect(lab.locator('#rtt')).toContainText('ms');
  await expect(lab.locator('#age')).toHaveText('—');
  await expect(lab.locator('#mode-note')).toContainText('実ゲームのプレイ結果ではありません');
  const download = page.waitForEvent('download'); await lab.locator('#export').click();
  expect((await download).suggestedFilename()).toBe('jev-mario-measurement.json');
  await screenshot(page, info.outputPath('fixture-measurement.png'));
  expect(errors).toEqual([]);
});
test('provider failure stops and explicit retry recovers', async ({ page }, info) => {
  await page.goto('/test/e2e/jev_mario_harness.html?error');
  const lab = page.frameLocator('iframe'); await expect(lab.locator('#status')).toContainText('準備完了');
  await lab.locator('#mode').selectOption('fixture');
  expect(await lab.locator('body').evaluate(() => innerWidth)).toBe(page.viewportSize()!.width);
  await lab.locator('#consent').check(); await lab.locator('#start').click();
  await expect(lab.locator('#last-error')).toContainText('API利用上限');
  await expect(lab.locator('#counts')).toHaveText('0 / 1 / 0');
  await screenshot(page, info.outputPath('fixture-error.png'));
  await lab.locator('#start').click(); await expect(lab.locator('#counts')).toHaveText('20 / 0 / 0', { timeout: 15000 });
});
test('late response after stop cannot resume controls; missing/invalid ROM explained', async ({ page }, info) => {
  await page.goto('/test/e2e/jev_mario_harness.html?slow');
  const lab = page.frameLocator('iframe'); await expect(lab.locator('#status')).toContainText('準備完了');
  await lab.locator('#mode').selectOption('fixture');
  expect(await lab.locator('body').evaluate(() => innerWidth)).toBe(page.viewportSize()!.width);
  await lab.locator('#consent').check(); await lab.locator('#start').click(); await lab.locator('#stop').click();
  await expect(lab.locator('#counts')).toHaveText('0 / 1 / 0');
  await page.waitForTimeout(1200); // Deliberately cover the late-response boundary.
  await expect(lab.locator('#action')).toHaveText('操作: noop');
  await lab.locator('#mode').selectOption('game'); await lab.locator('#start').click();
  await expect(lab.locator('#status')).toContainText('ROM');
  await lab.locator('#rom').setInputFiles({name:'invalid.nes',mimeType:'application/octet-stream',buffer:Buffer.from('invalid')});
  await expect(lab.locator('#last-error')).toContainText('SMB1 ROM');
  await screenshot(page, info.outputPath('fixture-rom-error.png'));
  const overflow = await lab.locator('body').evaluate(el => el.scrollWidth > innerWidth);
  expect(overflow).toBe(false);
});
