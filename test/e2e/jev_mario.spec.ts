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


test('audio defaults on but starts after play; mute, waveform and stop lifecycle', async ({page},info)=>{
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
  await expect(lab.locator('#sound')).toBeChecked();
  expect(await lab.locator('body').evaluate(()=>(window as any).__audioContexts.length)).toBe(0);
  await expect(lab.locator('#audio-status')).toContainText('遊ぶボタン');
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

test('spinning coins render in the underground room without changing simulation state',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');
 const result=await page.evaluate(async()=>{
  const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs');
  const g=new World11();g.room='underground';g.camera=0;g.contents=new Map([['4,7','loose']]);g.items=[{kind:'flower',x:100,y:128,w:14,h:16}];
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;canvas.style.width='512px';canvas.style.imageRendering='pixelated';document.body.replaceChildren(canvas);
  const ctx=canvas.getContext('2d')!;g.frames=0;const before=JSON.stringify(g.snapshot());drawWorld(ctx,g);const a=ctx.getImageData(64,112,16,16).data.slice();const unchanged=JSON.stringify(g.snapshot())===before;
  g.frames=10;drawWorld(ctx,g);const b=ctx.getImageData(64,112,16,16).data;
  return {changed:a.some((v,i)=>v!==b[i]),unchanged};
 });
 expect(result).toEqual({changed:true,unchanged:true});await page.locator('canvas').screenshot({path:info.outputPath('world11-spinning-coin.png')});
});

test('underground selection, manual movement, reset and stage return',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#stage').selectOption('2');await expect(lab.locator('#progress')).toContainText('1-2');
 await lab.locator('#play-local').click();await page.keyboard.down('ArrowRight');await page.waitForTimeout(500);await page.keyboard.up('ArrowRight');
 await expect(lab.locator('#progress')).toContainText('World 1-2');await expect(lab.locator('#progress')).not.toContainText('x=32 ');
 await screenshot(page,info.outputPath('world12-manual.png'));await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('1-2をリセット');
 await lab.locator('#stage').selectOption('1');await expect(lab.locator('#progress')).toContainText('1-1');await expect(lab.locator('#counts')).toHaveText('0 / 0 / 0');expect(errors).toEqual([]);
});

test('reference dashboard shows live state and records a 16:9 playable video',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await expect(lab.locator('#presentation')).toBeVisible();
 await lab.locator('#watch-manual').click();await expect(lab.locator('#decision-summary')).toContainText('LIVE');
 await page.keyboard.down('ArrowRight');await expect(lab.locator('#decision-summary')).toContainText('操作 right');
 await page.keyboard.up('ArrowRight');await lab.locator('#watch-record').click();
 await expect(lab.locator('#record-status')).toContainText('録画中');await expect(lab.locator('#record-layout')).toBeDisabled();
 await page.waitForTimeout(1300);await lab.locator('#record-stop').click();
 await expect(lab.locator('#record-result')).toBeVisible();await lab.locator('#watch-stop').click();
 const video=lab.locator('#record-preview');await expect.poll(()=>video.evaluate((v:HTMLVideoElement)=>v.readyState)).toBeGreaterThan(0);
 expect(await video.evaluate((v:HTMLVideoElement)=>[v.videoWidth,v.videoHeight])).toEqual([1280,720]);
 const saved=page.waitForEvent('download');await lab.locator('#record-download').click();const download=await saved;await download.saveAs(info.outputPath('reference-dashboard.webm'));
 await expect(lab.locator('#decision-summary')).toContainText('PAUSED');
 await lab.locator('#presentation').screenshot({path:info.outputPath('reference-dashboard.png')});
 await lab.locator('#restart-local').click();await lab.locator('#watch-student').click();
 await expect(lab.locator('#decision-summary')).toContainText('LightGBM + search',{timeout:20000});
 await lab.locator('#presentation').screenshot({path:info.outputPath('reference-dashboard-student.png')});
 await lab.locator('#watch-stop').click();
});


test('campaign clear fixtures advance through world 1 into 2-1; recording continues',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#watch-manual').click();await lab.locator('#watch-record').click();
 for(const stage of [1,2,3,4]){
  await frame.evaluate(async(stage)=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=([2,4].includes(stage)?196:198)*16;if(stage===4)this.p.y=176;original.call(this);this.presentation=179;};},stage);
  await expect(lab.locator('#stage')).toHaveValue(String(stage+1));await expect(lab.locator('#decision-summary')).toContainText('LIVE');
  await expect(lab.locator('#record-status')).toContainText('録画中');
 }
 await expect(lab.locator('#progress')).toContainText('2-1');await lab.locator('#presentation').screenshot({path:info.outputPath('world21-campaign.png')});
 await lab.locator('#watch-stop').click();await expect(lab.locator('#record-result')).toBeVisible();
 await lab.locator('#restart-local').click();await expect(lab.locator('#stage')).toHaveValue('5');
});
test('stop during clear cancels automatic stage progression',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('1-1クリア');await lab.locator('#watch-stop').click();await page.waitForTimeout(3300);await expect(lab.locator('#stage')).toHaveValue('1');
});


test('API campaign discards previous-stage response and preserves remaining call budget',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html?slow');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await page.evaluate(()=>{(window as any).campaignRequests=[];window.addEventListener('message',e=>{if(e.data?.type==='jev-mario-request')(window as any).campaignRequests.push(e.data.state.stage);});});
 await lab.locator('#count').evaluate((el:HTMLSelectElement)=>el.add(new Option('2','2')));await lab.locator('#count').selectOption('2');
 await lab.locator('#consent').check();await lab.locator('#start').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;original.call(this);this.presentation=179;};});
 await expect(lab.locator('#stage')).toHaveValue('2',{timeout:10000});await expect(lab.locator('#status')).toContainText('測定完了');
 expect(await page.evaluate(()=>(window as any).campaignRequests)).toEqual([1,2]);
 await expect(lab.locator('#sample-detail')).toContainText('停止時キャンセル 1件');
});


test('pixel scenery and HUD render representative course scenes without altering state',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');
 const result=await page.evaluate(async()=>{
  const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');
  const board=document.createElement('div');board.style.cssText='display:grid;grid-template-columns:repeat(2,256px);gap:8px;background:#111;padding:8px;width:520px';board.dataset.testid='pixel-scenes';
  const labels=document.createElement('p');labels.textContent='FIXED VISUAL FIXTURES: start / pipes / goal / stage 1-3';document.body.replaceChildren(labels,board);
  let unchanged=true;
  for(const [stage,x]of [[1,32],[1,700],[1,3120],[3,650]]){const g=new World11(stage);g.camera=Math.max(0,x-100);g.p.x=x;const before=JSON.stringify(g.snapshot());const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;board.append(canvas);drawWorld(canvas.getContext('2d'),g);unchanged&&=JSON.stringify(g.snapshot())===before;}
  return unchanged;
 });
 expect(result).toBe(true);await page.locator('[data-testid="pixel-scenes"]').screenshot({path:info.outputPath('pixel-scenes.png')});
});

test('castle axe finish progresses automatically into the second world',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('4');await expect(lab.locator('#progress')).toContainText('1-4');await expect(lab.locator('#sound')).toBeChecked();
 await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=196*16;this.p.y=176;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('1-4クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('5',{timeout:7000});await expect(lab.locator('#progress')).toContainText('2-1');
 await lab.locator('#presentation').screenshot({path:info.outputPath('world21-transition.png')});
 await lab.locator('#restart-local').click();await lab.locator('#watch-manual').click();await expect(lab.locator('#progress')).toContainText('playing');await lab.locator('#watch-stop').click();
});
test('castle visual fixtures show fire bars, lava gaps and the axe bridge',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');
 await page.evaluate(async()=>{
  const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs');
  const board=document.createElement('div');board.id='castle-scenes';board.style.cssText='display:grid;grid-template-columns:256px 256px;gap:8px;background:#101020;padding:8px;width:max-content';
  const label=document.createElement('p');label.textContent='FIXED VISUAL FIXTURES: castle entrance / fire and lava / bridge / axe';document.body.replaceChildren(label,board);
  for(const x of [32,400,2900,3100]){const g=new World11(4);g.camera=Math.max(0,x-96);g.p.x=x;g.p.y=x>2800?176:192;const c=document.createElement('canvas');c.width=256;c.height=240;board.append(c);drawWorld(c.getContext('2d'),g);}
 });
 await page.locator('#castle-scenes').screenshot({path:info.outputPath('castle-scenes.png')});
});

test('2-1 direct selection, API world-stage payload, terminal finish and exported labels',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('5');await expect(lab.locator('#restart-local')).toHaveText('2-1を最初から');
 await page.evaluate(()=>{(window as any).worldRequests=[];window.addEventListener('message',e=>{if(e.data?.type==='jev-mario-request')(window as any).worldRequests.push({world:e.data.state.world,stage:e.data.state.stage});});});
 await lab.locator('#consent').check();await lab.locator('#start').click();await expect.poll(()=>page.evaluate(()=>(window as any).worldRequests.length)).toBeGreaterThan(0);
 await lab.locator('#stop').click();expect(await page.evaluate(()=>(window as any).worldRequests[0])).toEqual({world:2,stage:1});
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('2-1クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('6',{timeout:7000});
 await lab.locator('#presentation').screenshot({path:info.outputPath('world21-clear.png')});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await (await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();const data=JSON.parse(raw);expect(data.world).toBe(2);expect(data.stage).toBe(1);expect(data.stage_results.at(-1)).toMatchObject({world:2,stage:1,label:'2-1',course_id:5});
 await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('2-2をリセット');
});
test('2-1 terrain and reference-style pipe silhouettes render across camera clipping',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');
 await page.evaluate(async()=>{
  const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs');const board=document.createElement('div');board.id='world21-scenes';board.style.cssText='display:grid;grid-template-columns:256px 256px;gap:8px;background:#101020;padding:8px;width:max-content';
  const label=document.createElement('p');label.textContent='FIXED VISUAL FIXTURES: 2-1 entrance / pipe / gap / goal';document.body.replaceChildren(label,board);
  for(const x of [32,500,740,3100]){const g=new World11(5);g.camera=Math.max(0,x-96);g.p.x=x;const c=document.createElement('canvas');c.width=256;c.height=240;board.append(c);drawWorld(c.getContext('2d'),g);}
 });
 await page.locator('#world21-scenes').screenshot({path:info.outputPath('world21-scenes.png')});
});


test('local autoplay survives elapsed benchmark time and continues into the next course',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 // Hold a safe scene while advancing wall time; this is lifecycle coverage, not AI clear evidence.
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');(window as any).originalStep=World11.prototype.step;World11.prototype.step=function(){this.frames++;};});
 await lab.locator('#watch-student').click();await expect(lab.locator('#student-status')).toContainText('探索変更',{timeout:20000});
 await frame.evaluate(()=>{const original=performance.now.bind(performance);Object.defineProperty(performance,'now',{configurable:true,value:()=>original()+65000});});
 const before=await lab.locator('#progress').textContent();await expect(lab.locator('#progress')).not.toHaveText(before!);
 await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');World11.prototype.step=function(){if(this.stage===1){this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;(window as any).originalStep.call(this);this.presentation=179;}else this.frames++;};});
 await expect(lab.locator('#stage')).toHaveValue('2',{timeout:10000});await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中');
 await lab.locator('#presentation').screenshot({path:info.outputPath('continuous-local.png')});
 await lab.locator('#stop').click();const stopped=await lab.locator('#progress').textContent();await page.waitForTimeout(200);await expect(lab.locator('#progress')).toHaveText(stopped!);await expect(lab.locator('#counts')).toHaveText('0 / 0 / 0');
});

test('visible blur releases manual keys but preserves play and recording',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#watch-manual').click();await page.keyboard.down('ArrowRight');await expect(lab.locator('#posture')).toContainText('歩く');
 await lab.locator('#record-start').click();await expect(lab.locator('#record-status')).toContainText('録画中');
 await frame.evaluate(()=>window.dispatchEvent(new Event('blur')));await page.keyboard.up('ArrowRight');
 await expect(lab.locator('#action')).toHaveText('操作: noop');await expect(lab.locator('#status')).toContainText('手動プレイ中');await expect(lab.locator('#record-status')).toContainText('録画中');
 await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible();
});

test('autoplay ignores visible blur but hidden page stops and can restart',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#watch-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});
 await frame.evaluate(()=>window.dispatchEvent(new Event('blur')));await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中');
 await frame.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'));});
 await expect(lab.locator('#status')).toContainText('バックグラウンド');const stopped=await lab.locator('#progress').textContent();await page.waitForTimeout(200);await expect(lab.locator('#progress')).toHaveText(stopped!);
 await frame.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:false});document.dispatchEvent(new Event('visibilitychange'));});
 await lab.locator('#watch-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});await lab.locator('#stop').click();
});


test('2-2 swimming controls, underwater audio, stop/reset and terminal export',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('6');await expect(lab.locator('#restart-local')).toHaveText('2-2を最初から');await lab.locator('#watch-manual').click();
 await page.keyboard.press('Space');await expect(lab.locator('#posture')).toContainText('泳ぐ');await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await lab.locator('#presentation').screenshot({path:info.outputPath('world22-swim.png')});
 await lab.locator('#stop').click();await expect(lab.locator('#status')).toContainText('停止');await lab.locator('#restart-local').click();await expect(lab.locator('#stage')).toHaveValue('6');
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=196*16;this.p.y=180;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('2-2クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('7',{timeout:7000});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:2,stage:2,course_id:6,phase:'won'});
});


test('2-3 selection, bridge/fish scenes, reset and final campaign result',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('7');await expect(lab.locator('#restart-local')).toHaveText('2-3を最初から');await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=400;this.p.y=176;this.camera=304;this.invincible=300;original.call(this);};});
 await page.waitForTimeout(400);await lab.locator('#presentation').screenshot({path:info.outputPath('world23-bridge.png')});
 await lab.locator('#restart-local').click();await expect(lab.locator('#stage')).toHaveValue('7');await expect(lab.locator('#progress')).toContainText('2-3をリセット');
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('2-3クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('8',{timeout:7000});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:2,stage:3,course_id:7,phase:'won'});
});


test('2-4 boss scene, axe rescue, final result and reset',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('8');await expect(lab.locator('#restart-local')).toHaveText('2-4を最初から');await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=184*16;this.p.y=176;this.camera=180*16;original.call(this);};});
 await page.waitForTimeout(150);await lab.locator('#presentation').screenshot({path:info.outputPath('world24-boss.png')});
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=196*16;this.p.y=176;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('2-4クリア！ 全ステージ終了');await page.waitForTimeout(3200);await expect(lab.locator('#stage')).toHaveValue('8');await lab.locator('#presentation').screenshot({path:info.outputPath('world24-rescue.png')});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:2,stage:4,course_id:8,phase:'won'});
 await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('2-4をリセット');
});
