import { test, expect, type Page } from '@playwright/test';
test('ROM-free 1-1 manual play, pause and restart need no API', async ({page},info)=>{
  const errors: string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
  await expect(lab.locator('#mode')).toHaveValue('recreation');
  await lab.locator('#play-local').click();
  await page.keyboard.down('ArrowRight');await page.waitForTimeout(1750);await page.keyboard.down('Space');await page.waitForTimeout(250);await page.keyboard.up('Space');await page.keyboard.up('ArrowRight');
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
  const result = await download;
  expect(result.suggestedFilename()).toBe('jev-mario-measurement.json');
  const stream = await result.createReadStream(); let raw = '';
  for await (const chunk of stream!) raw += chunk.toString();
  expect(JSON.parse(raw).max_age_ms).toBe(1500);
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


test('game scripts and styles load with their actual MIME types', async ({ page }) => {
  const failures: string[] = [];
  page.on('pageerror', error => failures.push(error.message));
  const scripts = page.waitForResponse(response => response.url().endsWith('/labs/jev-mario/lab.mjs'));
  const styles = page.waitForResponse(response => response.url().endsWith('/labs/jev-mario/style.css'));
  await page.goto('/test/e2e/jev_mario_harness.html');
  const script = await scripts;
  const style = await styles;
  expect(script.status()).toBe(200);
  expect(script.headers()['content-type']).toMatch(/javascript/);
  expect(style.status()).toBe(200);
  expect(style.headers()['content-type']).toContain('text/css');
  await expect(page.frameLocator('iframe').getByRole('button', { name: '手動で遊ぶ（API不要）' })).toBeVisible();
  expect(failures).toEqual([]);
});


test('one-second responses move the game; strict limit explains discarded controls', async ({ page }, info) => {
  await page.goto('/test/e2e/jev_mario_harness.html?latency');
  const lab = page.frameLocator('iframe');
  await expect(lab.locator('#status')).toContainText('準備完了');
  await expect(lab.locator('#max-age')).toHaveValue('1500');
  await lab.locator('#consent').check(); await lab.locator('#start').click();
  await expect(lab.locator('#action')).toHaveText('操作: right');
  await expect(lab.locator('#progress')).not.toContainText('x=32 ');
  await lab.locator('#stop').click(); await page.waitForTimeout(1100);
  await lab.locator('#restart-local').click();
  await lab.locator('#max-age').selectOption('750'); await lab.locator('#start').click();
  await expect(lab.locator('#response-warning')).toContainText('有効期限（750 ms）');
  await expect(lab.locator('#action')).toHaveText('操作: noop');
  await lab.locator('#stop').click();
  await screenshot(page, info.outputPath('response-age-warning.png'));
});


test('audio opt-in, waveform and stop lifecycle', async ({page},info)=>{
  await page.addInitScript(() => {
    const Native = window.AudioContext;
    (window as any).__audioContexts=[];
    window.AudioContext=class extends Native {
      constructor(){super();(window as any).__audioContexts.push(this);}
      createOscillator(){
        const o=super.createOscillator();const start=o.start.bind(o),stop=o.stop.bind(o);
        o.start=(when)=>{(window as any).__lastAudioStart=performance.now();start(when);};
        o.stop=(when)=>{if(when===undefined)(window as any).__audioStopped=true;stop(when);};return o;
      }
    };
  });
  await page.goto('/test/e2e/jev_mario_harness.html');
  const lab=page.frameLocator('iframe');
  await expect(lab.locator('#sound')).not.toBeChecked();
  await lab.locator('#sound').check();await expect(lab.locator('#audio-status')).toContainText('音声ON');
  await lab.locator('#play-local').click();
  await lab.locator('#volume').focus();await lab.locator('#volume').press('End');await expect(lab.locator('#volume-value')).toHaveText('100%');
  await expect.poll(()=>lab.locator('body').evaluate(()=>Number((window as any).__lastAudioStart)||0)).toBeGreaterThan(0);
  await lab.locator('#stop').click();
  expect(await lab.locator('body').evaluate(()=>(window as any).__audioStopped)).toBe(true);
  const stopped=await lab.locator('body').evaluate(()=>(window as any).__lastAudioStart);
  await page.waitForTimeout(250);
  expect(await lab.locator('body').evaluate(()=>(window as any).__lastAudioStart)).toBe(stopped);
  await lab.locator('#sound').uncheck();
  await expect(lab.locator('#audio-status')).toHaveText('ミュート');
  const signal=await lab.locator('body').evaluate(async()=>{
    const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs');
    const c=new OfflineAudioContext(1,44100,44100);
    // Offline contexts cannot resume: inject their rendering nodes behind a running facade.
    const a=new GameAudio(()=>({state:'running',currentTime:0,destination:c.destination,
      createGain:()=>c.createGain(),createOscillator:()=>c.createOscillator(),resume:async()=>{}}));
    await a.enable(true);a.tick();a.effect('coin');
    const buffer=await c.startRendering();return buffer.getChannelData(0).some(x=>Math.abs(x)>.001);
  });
  expect(signal).toBe(true);
  await screenshot(page,info.outputPath('world11-audio.png'));
});
