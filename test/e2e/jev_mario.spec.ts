import { test, expect, type Page } from '@playwright/test';

test('LightGBM worker plays without consent or API; records assistance and stops',async({page},info)=>{
 test.setTimeout(90000);
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await expect(lab.locator('#consent')).not.toBeChecked();await lab.locator('#play-student').click();
 await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});
 await expect(lab.locator('#student-status')).toContainText('探索変更',{timeout:15000});
 if(info.project.name==='desktop')await expect(lab.locator('#status')).toContainText('1-1クリア！',{timeout:60000});
 await screenshot(page,info.outputPath('world11-student.png'));await lab.locator('#stop').click();
 const before=await lab.locator('#progress').textContent();await page.waitForTimeout(350);await expect(lab.locator('#progress')).toHaveText(before!);
 await expect(lab.locator('#counts')).toHaveText('0 / 0 / 0');await expect(lab.locator('#consent')).not.toBeChecked();expect(errors).toEqual([]);
});
test('keyboard and touch crouch recover; walk and jump poses render',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#play-local').click();
 await page.keyboard.down('ArrowDown');await expect(lab.locator('#posture')).toContainText('しゃがみ');
 await screenshot(page,info.outputPath('world11-crouch.png'));
 await page.keyboard.up('ArrowDown');await expect(lab.locator('#posture')).toContainText('待機');
 await lab.locator('#screen').focus();await page.keyboard.down('ArrowRight');
 await expect(lab.locator('#posture')).toContainText('歩く');
 await page.keyboard.down('Space');await expect(lab.locator('#posture')).toContainText('上昇');
 await screenshot(page,info.outputPath('world11-jump.png'));
 await page.keyboard.up('Space');await page.keyboard.up('ArrowRight');
 await lab.locator('#restart-local').click();await lab.locator('#play-local').click();
 const down=lab.getByRole('button',{name:'しゃがむ・土管に入る'});
 const box=await down.boundingBox();expect(box).not.toBeNull();
 await page.mouse.move(box!.x+box!.width/2,box!.y+box!.height/2);await page.mouse.down();
 await expect(lab.locator('#posture')).toContainText('しゃがみ');
 await page.mouse.up();await expect(lab.locator('#posture')).toContainText('待機');
 await lab.locator('#stop').click();
});
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
  expect(JSON.parse(raw).samples[0].observation.state.player).toBeDefined();
  expect(JSON.parse(raw).samples[0].arrival.state.player).toBeDefined();
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
  await expect(lab.locator('#counts')).toHaveText('0 / 0 / 0');
  await expect(lab.locator('#sample-detail')).toContainText('キャンセル 1件');
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
  const scripts = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/labs/jev-mario/lab.mjs'));
  const styles = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/labs/jev-mario/style.css'));
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

test('loss presentation and retry remain usable with sound enabled',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#sound').check();await lab.locator('#play-local').click();
 await lab.locator('#screen').focus();await page.keyboard.down('ArrowRight');
 await expect(lab.locator('#posture')).toContainText('ミス',{timeout:10000});await page.keyboard.up('ArrowRight');
 await page.waitForTimeout(500);await screenshot(page,info.outputPath('world11-death-motion.png'));
 await page.waitForTimeout(2600);await screenshot(page,info.outputPath('world11-try-again.png'));
 await lab.locator('#restart-local').click();await expect(lab.locator('#posture')).toContainText('待機');
 await lab.locator('#play-local').click();await expect(lab.locator('#status')).toContainText('手動プレイ中');await lab.locator('#stop').click();
});


test('record gameplay with audio, preview and download; record again silently',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#sound').check();await lab.locator('#record-start').click();
 await expect(lab.locator('#record-status')).toContainText('ゲーム音あり');
 await lab.locator('#play-local').click();await page.keyboard.down('Space');
 await page.waitForTimeout(1800);await page.keyboard.up('Space');await lab.locator('#record-stop').click();
 await expect(lab.locator('#record-result')).toBeVisible();await lab.locator('#stop').click();
 const video=lab.locator('#record-preview');
 await expect.poll(()=>video.evaluate((v:HTMLVideoElement)=>v.readyState)).toBeGreaterThanOrEqual(2);
 expect(await video.evaluate((v:HTMLVideoElement)=>[v.videoWidth,v.videoHeight])).toEqual([256,240]);
 await video.evaluate((v:HTMLVideoElement)=>v.play());
 await expect.poll(()=>video.evaluate((v:HTMLVideoElement)=>v.currentTime)).toBeGreaterThan(0);
 // A decoded audio track verifies that game sound reached the encoded recording.
 const audioTracks=await video.evaluate((v:HTMLVideoElement)=>{
  const stream=(v as HTMLVideoElement & {captureStream():MediaStream}).captureStream();
  const count=stream.getAudioTracks().length;stream.getTracks().forEach(t=>t.stop());return count;
 });expect(audioTracks).toBe(1);
 await video.evaluate((v:HTMLVideoElement)=>v.pause());
 const downloadPromise=page.waitForEvent('download');await lab.locator('#record-download').click();
 const download=await downloadPromise;expect(download.suggestedFilename()).toMatch(/^jev-mario-.*\.webm$/);
 await download.saveAs(info.outputPath('gameplay-audio.webm'));
 const stream=await download.createReadStream();let bytes=0;for await(const chunk of stream!)bytes+=chunk.length;expect(bytes).toBeGreaterThan(1000);
 await screenshot(page,info.outputPath('recording-ready.png'));
 await lab.locator('#sound').uncheck();await lab.locator('#record-start').click();
 await expect(lab.locator('#record-status')).toContainText('音声なし');
 await lab.locator('#play-local').click();await page.waitForTimeout(1200);await lab.locator('#record-stop').click();
 await expect(lab.locator('#record-status')).toContainText('ダウンロード');
 await expect(lab.locator('#record-start')).toBeEnabled();await lab.locator('#stop').click();
});

test('recording unsupported leaves manual gameplay usable',async({page})=>{
 await page.addInitScript(()=>{Object.defineProperty(window,'MediaRecorder',{value:undefined});});
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await expect(lab.locator('#record-start')).toBeDisabled();await expect(lab.locator('#record-status')).toContainText('対応していません');
 await lab.locator('#play-local').click();await expect(lab.locator('#status')).toContainText('手動プレイ中');await lab.locator('#stop').click();
});

test('mode change finalizes recording and fixture disables capture',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#play-local').click();await lab.locator('#record-start').click();await page.waitForTimeout(1200);
 await lab.locator('#mode').selectOption('fixture');await expect(lab.locator('#record-result')).toBeVisible();
 await expect(lab.locator('#record-start')).toBeDisabled();await expect(lab.locator('#record-stop')).toBeDisabled();
 await lab.locator('#mode').selectOption('recreation');await expect(lab.locator('#record-start')).toBeEnabled();
});


test('local assistance is opt-in, exports attribution and can return to Jev-only',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html?slow');const lab=page.frameLocator('iframe');
 await expect(lab.locator('#status')).toContainText('準備完了');
 await expect(lab.locator('#controller')).toHaveValue('jev_only');
 await lab.locator('#controller').selectOption('jev_plus_local');await lab.locator('#consent').check();await lab.locator('#start').click();
 await expect(lab.locator('#assist-status')).toContainText('ローカル補助:',{timeout:12000});
 await lab.locator('#stop').click();const download=page.waitForEvent('download');await lab.locator('#export').click();
 const stream=await (await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();
 const data=JSON.parse(raw);expect(data.controller).toBe('jev_plus_local');expect(data.local_interventions.length).toBeGreaterThan(0);
 expect(data.samples[0].observation.context.hazards).toBeDefined();
 await screenshot(page,info.outputPath('local-reaction-comparison.png'));
 await lab.locator('#controller').selectOption('jev_only');await expect(lab.locator('#status')).toContainText('操作方式');
 await lab.locator('#restart-local').click();await lab.locator('#play-local').click();await expect(lab.locator('#status')).toContainText('手動');
});


test('prediction input is opt-in, exported and absent in the baseline', async ({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await expect(lab.locator('#status')).toContainText('準備完了');await expect(lab.locator('#input-profile')).toHaveValue('baseline');
 await lab.locator('#input-profile').selectOption('prediction_v1');await lab.locator('#consent').check();await lab.locator('#start').click();
 await expect(lab.locator('#state')).toContainText('projected_gap');await expect(lab.locator('#counts')).not.toHaveText('0 / 0 / 0');await lab.locator('#stop').click();
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await (await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();
 const log=JSON.parse(raw);expect(log.input_profile).toBe('prediction_v1');expect(log.samples[0].observation.state.prediction.horizon_ms).toBe(1000);
 await screenshot(page,info.outputPath('prediction-input.png'));
 await lab.locator('#input-profile').selectOption('baseline');await lab.locator('#restart-local').click();await lab.locator('#start').click();await expect(lab.locator('#state')).not.toContainText('projected_gap');await lab.locator('#stop').click();
});

test('stomp score and fire impact render in a deterministic canvas fixture',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;await frame.waitForSelector('#screen');
 const result=await frame.evaluate(async()=>{const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs');const g=new World11();Object.assign(g.p,{x:100,y:175,vx:0,vy:2,grounded:false});g.input={jump:true};g.wasJump=true;g.enemies=[{x:100,y:192,w:14,h:16,vx:0,vy:0,kind:'goomba',dead:0}];g.step();g.effects.push({kind:'burst',x:125,y:190,life:9});const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;canvas.style.width='512px';canvas.dataset.testid='feedback-fixture';document.body.prepend(canvas);drawWorld(canvas.getContext('2d'),g);return {score:g.score,bounce:g.p.vy,popups:g.effects.filter(f=>f.kind==='score').length};});
 expect(result.score).toBe(100);expect(result.bounce).toBeLessThan(-3.5);expect(result.popups).toBe(1);await screenshot(page,info.outputPath('stomp-score-fixture.png'));
});
