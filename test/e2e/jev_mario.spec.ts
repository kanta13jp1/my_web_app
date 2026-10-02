import { test, expect, type Page } from '@playwright/test';

test('LightGBM worker plays without consent or API; records assistance and stops',async({page},info)=>{
 test.setTimeout(130000);
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#screen').evaluate(()=>localStorage.setItem('jev-mario-retry-world8-v1',JSON.stringify([280,440,640,1350].map(x=>({stage:1,room:'overworld',x,y:192,count:12,kind:'stalled'})))));
 await page.reload();
 await expect(lab.locator('#volume')).toHaveValue('100');await expect(lab.locator('#volume-value')).toHaveText('100%');
 await expect(lab.locator('#consent')).not.toBeChecked();await lab.locator('#play-student').click();
 await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});
 await expect(lab.locator('#student-status')).toContainText('探索変更',{timeout:15000});
 if(info.project.name==='desktop')await expect(lab.locator('#status')).toContainText('1-1クリア！',{timeout:100000});
 await screenshot(page,info.outputPath('world11-student.png'));await lab.locator('#stop').click();
 const before=await lab.locator('#progress').textContent();await page.waitForTimeout(350);await expect(lab.locator('#progress')).toHaveText(before!);
 if(info.project.name==='desktop'){
  const pending=page.waitForEvent('download');await lab.locator('#export').click();const d=await pending;await d.saveAs(info.outputPath('world11-student.json'));
  const stream=await d.createReadStream();let raw='';for await(const b of stream!)raw+=b.toString();const data=JSON.parse(raw);
  const clear=data.stage_results.find((r:any)=>r.course_id===1&&r.phase==='won');expect(clear).toBeTruthy();expect(Object.values(clear.items_collected).reduce((n:number,v:any)=>n+Number(v),0)).toBeGreaterThan(0);
 }
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
 await down.scrollIntoViewIfNeeded();const box=await down.boundingBox();expect(box).not.toBeNull();
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
 await expect(lab.locator('#status')).toContainText('2-4クリア！ 次のステージへ進みます');await page.waitForTimeout(1800);await lab.locator('#presentation').screenshot({path:info.outputPath('world24-rescue.png')});await expect(lab.locator('#stage')).toHaveValue('9',{timeout:7000});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:2,stage:4,course_id:8,phase:'won'});
 await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('3-1をリセット');
});


test('3-1 night scene, Peach bonus ending, export and reset',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('9');await expect(lab.locator('#mode-note')).toContainText('原作と異なるアレンジ');await expect(lab.locator('#restart-local')).toHaveText('3-1を最初から');await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await lab.locator('#presentation').screenshot({path:info.outputPath('world31-night.png')});
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('3-1クリア！ 次のステージへ進みます');await page.waitForTimeout(2500);await lab.locator('#presentation').screenshot({path:info.outputPath('world31-peach.png')});await expect(lab.locator('#stage')).toHaveValue('10',{timeout:7000});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:3,stage:1,course_id:9,phase:'won'});
 await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('3-2をリセット');
});


test('3-2 projectile scene, final Peach ending and reset',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('10');await expect(lab.locator('#restart-local')).toHaveText('3-2を最初から');await expect(lab.locator('#mode-note')).toContainText('原作と異なるアレンジ');await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=736;this.p.y=192;this.camera=640;original.call(this);};});
 await page.waitForTimeout(150);await lab.locator('#presentation').screenshot({path:info.outputPath('world32-enemies.png')});
 await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('3-2をリセット');await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('3-2クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('11',{timeout:7000});await lab.locator('#presentation').screenshot({path:info.outputPath('world32-peach.png')});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:3,stage:2,course_id:10,phase:'won'});
});


test('3-3 Lakitu scene and six fireworks finish before final recording and export',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('11');await expect(lab.locator('#restart-local')).toHaveText('3-3を最初から');await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.p.x=384;this.p.y=176;this.camera=288;original.call(this);};});
 await page.waitForTimeout(300);await lab.locator('#presentation').screenshot({path:info.outputPath('world33-lakitu.png')});
 await lab.locator('#restart-local').click();await lab.locator('#watch-manual').click();await lab.locator('#watch-record').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;(window as any).observedWorld=this;this.frames=(400-336)*24-1;this.p.x=198*16;this.p.y=160;this.p.vx=0;this.p.vy=0;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('3-3クリア！ 次のステージへ進みます');
 await expect.poll(()=>frame.evaluate(()=>(window as any).observedWorld.fireworks.length)).toBeGreaterThan(0);
 await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#presentation').screenshot({path:info.outputPath('world33-fireworks.png')});
 await expect(lab.locator('#stage')).toHaveValue('12',{timeout:10000});await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible();
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:3,stage:3,course_id:11,phase:'won',fireworks:6,finalized:true});expect(errors).toEqual([]);
});

test('remaining lives restart the same course and recording continues until game over',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('11');await lab.locator('#watch-manual').click();await lab.locator('#watch-record').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.score=2500;this.coins=7;this.p.x=600;this.p.y=260;original.call(this);};});
 await expect(lab.locator('#status')).toContainText('残り2機');await page.waitForTimeout(1600);await lab.locator('#presentation').screenshot({path:info.outputPath('world33-retry.png')});
 await expect(lab.locator('#status')).toContainText('3-3 手動プレイ中',{timeout:7000});await expect(lab.locator('#progress')).toContainText('x=32');await expect(lab.locator('#progress')).toContainText('残り2機');await expect(lab.locator('#record-status')).toContainText('録画中');await expect(lab.locator('#stage')).toHaveValue('11');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.lives=1;this.die();};});
 await expect(lab.locator('#status')).toContainText('ゲームオーバー');await expect(lab.locator('#record-result')).toBeVisible({timeout:7000});await expect(lab.locator('#progress')).toContainText('残り0機');await expect(lab.locator('#decision-summary')).toContainText('GAME OVER');await lab.locator('#presentation').screenshot({path:info.outputPath('world33-game-over.png')});await page.waitForTimeout(500);await expect(lab.locator('#status')).toContainText('ゲームオーバー');
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();const results=JSON.parse(raw).stage_results;expect(results.map((r:any)=>r.course_id)).toEqual([11,11]);expect(results[0]).toMatchObject({lives:2,score:2500,deaths:1});expect(results[1]).toMatchObject({lives:0,score:2500,deaths:2});
});

test('stop during death cancels retry; local AI can retry with a fresh worker',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.die();};});
 await expect(lab.locator('#status')).toContainText('残り2機');await lab.locator('#watch-stop').click();await page.waitForTimeout(3300);await expect(lab.locator('#status')).toContainText('停止しました');await expect(lab.locator('#decision-summary')).not.toContainText('LIVE');
 await lab.locator('#watch-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});
 await frame.evaluate(async()=>{const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const original=StudentSession.prototype.tick;let died=false;StudentSession.prototype.tick=function(world){if(!died){died=true;world.die();return 'noop';}return original.call(this,world);};});
 await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:10000});await expect(lab.locator('#progress')).toContainText('残り2機');await expect(lab.locator('#student-status')).toContainText('モデル案採用');await lab.locator('#stop').click();
});

test('cloud retry discards the dead-life response and retains the request budget',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html?slow');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await page.evaluate(()=>{(window as any).retryRequests=0;window.addEventListener('message',e=>{if(e.data?.type==='jev-mario-request')(window as any).retryRequests++;});});
 await lab.locator('#count').evaluate((el:HTMLSelectElement)=>el.add(new Option('2','2')));await lab.locator('#count').selectOption('2');await lab.locator('#consent').check();await lab.locator('#start').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const original=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=original;this.die();};});
 await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('Jev測定完了',{timeout:10000});expect(await page.evaluate(()=>(window as any).retryRequests)).toBe(2);await expect(lab.locator('#sample-detail')).toContainText('停止時キャンセル 1件');
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();const data=JSON.parse(raw);expect(data.samples[0]).toMatchObject({cancelled:true});expect(data.samples[1].observation.context.lives).toBe(2);expect(data.counts.applied).toBe(1);await expect(lab.locator('#stage')).toHaveValue('1');
});


for(const stage of [4,8,12])test(`castle ${stage} boss, Toad rescue and end result`,async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const label=`${stage/4}-4`;await lab.locator('#stage').selectOption(String(stage));await expect(lab.locator('#restart-local')).toHaveText(`${label}を最初から`);await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;this.p.x=184*16;this.p.y=176;this.camera=180*16;this.invincible=90;step.call(this);};});
 await page.waitForTimeout(150);await lab.locator('#presentation').screenshot({path:info.outputPath(`world${stage}-boss.png`)});
 await lab.locator('#watch-record').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).castleWorld=this;this.p.x=196*16;this.p.y=176;this.p.vx=0;this.p.vy=0;step.call(this);};});
 await expect(lab.locator('#status')).toContainText(`${label}クリア！ 次のステージへ進みます`);
 await expect.poll(()=>frame.evaluate(()=>(window as any).castleWorld.rescued)).toBe(true);await lab.locator('#presentation').screenshot({path:info.outputPath(`world${stage}-toad.png`)});
 await expect(lab.locator('#stage')).toHaveValue(String(stage+1),{timeout:7000});await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible();
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({course_id:stage,phase:'won',fireworks:0,finalized:true});
 await lab.locator('#stage').selectOption(String(stage));await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText(`${label}をリセット`);
});

test('underground beetle and pipe plant render, retract near player and reset',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('2');await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).plantWorld=this;this.p.x=340;this.p.y=192;this.camera=244;this.invincible=120;const plant=this.enemies.find(e=>e.kind==='piranha');plant.age=70;step.call(this);};});
 await page.waitForTimeout(150);await lab.locator('#presentation').screenshot({path:info.outputPath('world12-plant-beetle.png')});
 await frame.evaluate(()=>{const w=(window as any).plantWorld,e=w.enemies.find(e=>e.kind==='piranha');e.age=0;w.p.x=e.x;w.p.y=e.pipeY-w.p.h;w.p.vx=0;w.p.vy=0;w.input={};});await page.waitForTimeout(350);
 expect(await frame.evaluate(()=>{const w=(window as any).plantWorld,e=w.enemies.find(e=>e.kind==='piranha');return {hidden:e.hidden,age:e.age,phase:w.phase};})).toEqual({hidden:true,age:0,phase:'playing'});
 await lab.locator('#presentation').screenshot({path:info.outputPath('world12-plant-hidden.png')});await lab.locator('#stop').click();await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('1-2をリセット');expect(errors).toEqual([]);
});


test('clear and death presentation keep Mario visible despite a frozen damage blink',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const checks=await frame.evaluate(async()=>{const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;const ctx=canvas.getContext('2d')!;return ['won','dead'].map(phase=>{const g=new World11(12);g.phase=phase;g.frames=3;g.presentation=100;g.p.x=201*16;g.p.y=192;g.camera=193*16;g.invincible=0;drawWorld(ctx,g);const expected=ctx.getImageData(128,192,16,16).data.slice();g.invincible=90;drawWorld(ctx,g);const actual=ctx.getImageData(128,192,16,16).data;return actual.every((v,i)=>v===expected[i]);});});
 expect(checks).toEqual([true,true]);
});


test('4-1 Lakitu, same-course life retry and terminal fireworks recording',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('13');await expect(lab.locator('#restart-local')).toHaveText('4-1を最初から');await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');await lab.locator('#watch-record').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).world41=this;this.p.x=384;this.camera=288;this.invincible=300;step.call(this);};});
 await expect.poll(()=>frame.evaluate(()=>(window as any).world41?.enemies.some(e=>e.kind==='spiny-egg'))).toBe(true);await lab.locator('#presentation').screenshot({path:info.outputPath('world41-lakitu.png')});
 await frame.evaluate(()=>(window as any).world41.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('4-1 手動プレイ中',{timeout:7000});await expect(lab.locator('#progress')).toContainText('x=32');await expect(lab.locator('#stage')).toHaveValue('13');await expect(lab.locator('#record-status')).toContainText('録画中');
 await frame.evaluate(()=>{const g=(window as any).world41;g.frames=(400-336)*24-1;g.p.x=198*16;g.p.y=160;g.p.vx=0;g.p.vy=0;});await expect(lab.locator('#status')).toContainText('4-1クリア！ 次のステージへ進みます');
 await expect.poll(()=>frame.evaluate(()=>(window as any).world41.fireworks.length)).toBeGreaterThan(0);await lab.locator('#presentation').screenshot({path:info.outputPath('world41-fireworks.png')});await expect(lab.locator('#stage')).toHaveValue('14',{timeout:10000});await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible();
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:4,stage:1,course_id:13,phase:'won',lives:2,fireworks:6,finalized:true});expect(errors).toEqual([]);
});

test('castle lava fireball rising and falling visual fixtures are deterministic',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const board=document.createElement('div');board.id='lava-scenes';board.style.cssText='display:grid;grid-template-columns:256px 256px;gap:8px;background:#101020;width:max-content';document.body.replaceChildren(board);return [4,8,12].flatMap(stage=>[20,50].map(age=>{const g=new World11(stage),f=g.lavaBubbles[0];g.p.x=f.x-80;g.camera=f.x-100;f.timer=1;for(let i=0;i<age;i++)g.lavaBubbleStep();const before=JSON.stringify(g.snapshot());const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;board.append(canvas);drawWorld(canvas.getContext('2d'),g);return {active:f.active,visible:f.y<220,falling:f.vy>0,unchanged:before===JSON.stringify(g.snapshot())};}));});
 expect(result.map(r=>r.falling)).toEqual([false,true,false,true,false,true]);expect(result.every(r=>r.active&&r.visible&&r.unchanged)).toBe(true);await frame.locator('#lava-scenes').screenshot({path:info.outputPath('castle-lava-fireballs.png')});
});


test('4-2 vertical lift carries Mario and keyboard jump leaves it; stop and reset restore the course',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('14');await expect(lab.locator('#restart-local')).toHaveText('4-2を最初から');await lab.locator('#watch-manual').click();await expect(lab.locator('#audio-status')).toContainText('音声ON');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).world42=this;const l=this.lifts[0];this.p.x=l.x+8;this.p.y=l.y-this.p.h;this.p.vy=0;this.p.grounded=true;this.p.liftId=l.id;this.camera=this.p.x-96;step.call(this);};});
 await expect.poll(()=>frame.evaluate(()=>(window as any).world42?.p.liftId)).toBe(0);const y=await frame.evaluate(()=>(window as any).world42.p.y);await expect.poll(()=>frame.evaluate(()=>(window as any).world42.p.y)).toBeLessThan(y-4);await lab.locator('#presentation').screenshot({path:info.outputPath('world42-lift.png')});
 await lab.locator('#screen').focus();await page.keyboard.down('Space');await expect(lab.locator('#posture')).toContainText('上昇');expect(await frame.evaluate(()=>(window as any).world42.p.liftId)).toBeUndefined();await page.keyboard.up('Space');await lab.locator('#stop').click();await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('4-2をリセット');expect(await frame.evaluate(()=>(window as any).world42.lifts[0].y)).toBe(176);expect(errors).toEqual([]);
});

test('4-2 remaining life HUD, same-course restart and final underground recording',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;await lab.locator('#stage').selectOption('14');await lab.locator('#watch-manual').click();await lab.locator('#watch-record').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).world42=this;this.die();};});
 await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('4-2 手動プレイ中',{timeout:7000});await expect(lab.locator('#progress')).toContainText('x=32');await expect(lab.locator('#progress')).toContainText('残り2機');await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#presentation').screenshot({path:info.outputPath('world42-lives-retry.png')});
 await frame.evaluate(()=>{const g=(window as any).world42;g.p.x=196*16;g.p.y=180;g.p.vx=0;g.p.vy=0;});await expect(lab.locator('#status')).toContainText('4-2クリア！ 次のステージへ進みます');await expect(lab.locator('#stage')).toHaveValue('15',{timeout:7000});await expect(lab.locator('#record-status')).toContainText('録画中');await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible();await lab.locator('#presentation').screenshot({path:info.outputPath('world42-clear.png')});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();expect(JSON.parse(raw).stage_results.at(-1)).toMatchObject({world:4,stage:2,course_id:14,phase:'won',lives:2,fireworks:0,finalized:true});
});

test('wing animation and live life-counter render independently of physics',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{const {World11,drawWorld}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const g=new World11(14);g.camera=560;g.p.x=592;g.enemies=g.enemies.filter(e=>e.kind==='paratroopa');const canvas=document.createElement('canvas');canvas.width=256;canvas.height=240;canvas.style.cssText='width:min(100%,512px);image-rendering:pixelated';canvas.id='wing-fixture';document.body.replaceChildren(canvas);const ctx=canvas.getContext('2d')!;g.frames=0;drawWorld(ctx,g);const a=ctx.getImageData(77,192,20,16).data.slice(),lives=ctx.getImageData(24,4,72,8).data.slice();g.frames=8;g.lives=2;const before=JSON.stringify(g.snapshot());drawWorld(ctx,g);const b=ctx.getImageData(77,192,20,16).data,counter=ctx.getImageData(24,4,72,8).data;return {wingChanged:b.some((v,i)=>v!==a[i]),counterChanged:counter.some((v,i)=>v!==lives[i]),unchanged:JSON.stringify(g.snapshot())===before};});
 expect(result).toEqual({wingChanged:true,counterChanged:true,unchanged:true});await frame.locator('#wing-fixture').screenshot({path:info.outputPath('world42-winged-koopa-hud.png')});
});


test('4-3 beanstalk keyboard climb, jump release and reset',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await lab.locator('#stage').selectOption('15');await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).w43=this;this.enemies=[];this.hitBlock(12,9);for(let i=0;i<120;i++)this.vineStep();Object.assign(this.p,{x:192,y:104,vx:0,vy:0,grounded:false});this.input.up=true;step.call(this);};});
 await expect(lab.locator('#posture')).toContainText('つるを登る');await lab.locator('#screen').focus();await page.keyboard.down('ArrowUp');await expect.poll(()=>frame.evaluate(()=>(window as any).w43.p.y)).toBeLessThan(80);await page.keyboard.up('ArrowUp');await lab.locator('#presentation').screenshot({path:info.outputPath('world43-vine.png')});await page.keyboard.down('Space');await expect(lab.locator('#posture')).toContainText('上昇');await page.keyboard.up('Space');await lab.locator('#restart-local').click();await expect(lab.locator('#progress')).toContainText('4-3をリセット');expect(await frame.evaluate(()=>(window as any).w43.vines.length)).toBe(0);expect(errors).toEqual([]);
});
test('shell carry touch control and keyboard throw operate without damaging Mario',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;await lab.locator('#watch-manual').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).shellWorld=this;this.enemies=[{x:50,y:192,w:14,h:16,vx:0,vy:0,kind:'shell',dead:0}];step.call(this);};});
 const control=lab.locator('[data-key="carry"]');await control.scrollIntoViewIfNeeded();const box=(await control.boundingBox())!;await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await expect.poll(()=>frame.evaluate(()=>(window as any).shellWorld?.enemies[0].carried)).toBe(true);await lab.locator('#presentation').screenshot({path:info.outputPath('shell-held.png')});await page.mouse.up();await expect.poll(()=>frame.evaluate(()=>(window as any).shellWorld.enemies[0].vx)).toBe(4);expect(await frame.evaluate(()=>(window as any).shellWorld.phase)).toBe('playing');await lab.locator('#stop').click();
});
test('4-3 fireworks advance to 4-4, retry preserves lives and final castle rescue records terminal outcome',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;await lab.locator('#stage').selectOption('15');await lab.locator('#watch-manual').click();await lab.locator('#watch-record').click();
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).campaign=this;this.frames=(400-331)*24-1;Object.assign(this.p,{x:198*16,y:160,vx:0,vy:0});step.call(this);};});
 await expect(lab.locator('#status')).toContainText('4-3クリア！ 次のステージへ進みます');await frame.waitForFunction(()=>(window as any).campaign.fireworks.length>0,null,{polling:'raf'});await lab.locator('#presentation').screenshot({path:info.outputPath('world43-fireworks.png')});await expect(lab.locator('#stage')).toHaveValue('16',{timeout:10000});await expect(lab.locator('#record-status')).toContainText('録画中');await frame.evaluate(()=>(window as any).campaign.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('4-4 手動プレイ中',{timeout:7000});
 await frame.evaluate(()=>{const g=(window as any).campaign;g.p.x=184*16;g.p.y=176;g.camera=180*16;g.invincible=300;});await expect.poll(()=>frame.evaluate(()=>(window as any).campaign.bossFlames.length)).toBeGreaterThan(0);await lab.locator('#presentation').screenshot({path:info.outputPath('world44-boss.png')});await frame.evaluate(()=>{const g=(window as any).campaign;g.p.x=196*16;g.p.y=176;g.p.vx=0;g.p.vy=0;});await expect(lab.locator('#status')).toContainText('4-4クリア！ 次のステージへ進みます');await expect.poll(()=>frame.evaluate(()=>(window as any).campaign.rescued)).toBe(true);await lab.locator('#presentation').screenshot({path:info.outputPath('world44-toad.png')});await expect(lab.locator('#stage')).toHaveValue('17',{timeout:7000});await lab.locator('#stop').click();await expect(lab.locator('#record-result')).toBeVisible({timeout:7000});
 const download=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await download).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();const results=JSON.parse(raw).stage_results;expect(results.at(-1)).toMatchObject({world:4,stage:4,lives:2,phase:'won',fireworks:0,finalized:true});expect(results.map((r:any)=>r.course_id)).toEqual([15,16,16]);expect(results[0]).toMatchObject({fireworks:1,finalized:true});
});

test('world 5 course selection, life restart, progression and final rescue',async({page},info)=>{
 test.setTimeout(60000);const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 for(const id of [17,18,19,20]){
  await lab.locator('#stage').selectOption(String(id));await lab.locator('#watch-manual').click();
  await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
  await frame.waitForFunction((id)=>(window as any).fifth?.stage===id,id);if(id===18)expect(await frame.evaluate(()=>Array.from((document.getElementById('screen') as HTMLCanvasElement).getContext('2d')!.getImageData(0,0,1,1).data))).toEqual([8,16,40,255]);await lab.locator('#presentation').screenshot({path:info.outputPath(`world5-${id-16}.png`)});
  if(id===18){await frame.evaluate(()=>(window as any).fifth.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('5-2 手動プレイ中',{timeout:7000});
   // Retry constructs a new world: target the live instance, never the dead fixture.
   await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
   await frame.waitForFunction(()=>(window as any).fifth.phase==='playing');
  }
  await frame.evaluate(()=>{const g=(window as any).fifth;Object.assign(g.p,{x:(g.stage===20?196:198)*16,y:g.stage===20?176:160,vx:0,vy:0});g.frames=(400-330)*24-1;g.invincible=1000;});
  await expect(lab.locator('#status')).toContainText(`5-${id-16}クリア！`);
  await expect(lab.locator('#stage')).toHaveValue(String(id+1),{timeout:7000});
 }
 expect(errors).toEqual([]);
});

test('world 6 course selection, life restart, progression and final rescue',async({page},info)=>{
 test.setTimeout(60000);const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 for(const id of [21,22,23,24]){
  await lab.locator('#stage').selectOption(String(id));await lab.locator('#watch-manual').click();
  await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
  await frame.waitForFunction((id)=>(window as any).fifth?.stage===id,id);if(id===22)expect(await frame.evaluate(()=>Array.from((document.getElementById('screen') as HTMLCanvasElement).getContext('2d')!.getImageData(0,0,1,1).data))).toEqual([8,16,40,255]);await lab.locator('#presentation').screenshot({path:info.outputPath(`world6-${id-20}.png`)});
  if(id===22){await frame.evaluate(()=>(window as any).fifth.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('6-2 手動プレイ中',{timeout:7000});
   // Retry constructs a new world: target the live instance, never the dead fixture.
   await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
   await frame.waitForFunction(()=>(window as any).fifth.phase==='playing');
  }
  await frame.evaluate(()=>{const g=(window as any).fifth;Object.assign(g.p,{x:(g.stage===24?196:198)*16,y:g.stage===24?176:160,vx:0,vy:0});g.frames=(400-330)*24-1;g.invincible=1000;});
  await expect(lab.locator('#status')).toContainText(`6-${id-20}クリア！`);
  await expect(lab.locator('#stage')).toHaveValue(String(id+1),{timeout:7000});
 }
 expect(errors).toEqual([]);
});

test('world 7 course selection, life restart, progression and final rescue',async({page},info)=>{
 test.setTimeout(60000);const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 for(const id of [25,26,27,28]){
  await lab.locator('#stage').selectOption(String(id));await lab.locator('#watch-manual').click();
  await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
  await frame.waitForFunction((id)=>(window as any).fifth?.stage===id,id);if(id===26)expect(await frame.evaluate(()=>Array.from((document.getElementById('screen') as HTMLCanvasElement).getContext('2d')!.getImageData(0,0,1,1).data))).toEqual([32,72,160,255]);await lab.locator('#presentation').screenshot({path:info.outputPath(`world7-${id-24}.png`)});
  if(id===26){await frame.evaluate(()=>(window as any).fifth.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('7-2 手動プレイ中',{timeout:7000});
   // Retry constructs a new world: target the live instance, never the dead fixture.
   await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
   await frame.waitForFunction(()=>(window as any).fifth.phase==='playing');
  }
  await frame.evaluate(()=>{const g=(window as any).fifth;Object.assign(g.p,{x:([26,28].includes(g.stage)?196:198)*16,y:[26,28].includes(g.stage)?176:160,vx:0,vy:0});g.frames=(400-330)*24-1;g.invincible=1000;});
  await expect(lab.locator('#status')).toContainText(`7-${id-24}クリア！`);
  await expect(lab.locator('#stage')).toHaveValue(String(id+1),{timeout:7000});
 }
 expect(errors).toEqual([]);
});

test('world 8 course selection, life restart, progression and final rescue',async({page},info)=>{
 test.setTimeout(60000);const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 for(const id of [29,30,31,32]){
  await lab.locator('#stage').selectOption(String(id));await lab.locator('#watch-manual').click();
  await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
  await frame.waitForFunction((id)=>(window as any).fifth?.stage===id,id);await lab.locator('#presentation').screenshot({path:info.outputPath(`world8-${id-28}.png`)});
  if(id===30){await frame.evaluate(()=>(window as any).fifth.die());await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('8-2 手動プレイ中',{timeout:7000});
   // Retry constructs a new world: target the live instance, never the dead fixture.
   await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).fifth=this;step.call(this);};});
   await frame.waitForFunction(()=>(window as any).fifth.phase==='playing');
  }
  await frame.evaluate(()=>{const g=(window as any).fifth;Object.assign(g.p,{x:(g.stage===32?196:198)*16,y:g.stage===32?176:160,vx:0,vy:0});g.frames=(400-330)*24-1;g.invincible=1000;});
  await expect(lab.locator('#status')).toContainText(`8-${id-28}クリア！`);
  if(id<32)await expect(lab.locator('#stage')).toHaveValue(String(id+1),{timeout:7000});
  else{await expect(lab.locator('#status')).toContainText('全ステージ終了');await frame.waitForFunction(()=>(window as any).fifth.peachRescued);await expect.poll(()=>frame.evaluate(()=>{const p=(document.getElementById('screen') as HTMLCanvasElement).getContext('2d')!.getImageData(0,0,256,240).data;let n=0;for(let i=0;i<p.length;i+=4)if(p[i]===248&&p[i+1]===120&&p[i+2]===184)n++;return n;})).toBeGreaterThan(20);await lab.locator('#presentation').screenshot({path:info.outputPath('world84-rescue.png')});await expect(lab.locator('#history-rows')).toContainText('クリア',{timeout:7000});}
 }
 expect(errors).toEqual([]);
});

test('run history survives reload, sharing errors recover and ranking renders safe text',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');let lab=page.frameLocator('iframe');await lab.locator('#stage').selectOption('17');await lab.locator('#watch-manual').click();await page.waitForTimeout(150);await lab.locator('#stop').click();await expect(lab.locator('#history-rows')).toContainText('途中停止');
 await page.reload();lab=page.frameLocator('iframe');await expect(lab.locator('#history-rows')).toContainText('5-1');
 await page.evaluate(()=>{let failed=false;window.addEventListener('message',e=>{if(e.data?.type!=='jev-mario-ranking')return;const data=e.data;if(data.action==='submit'&&!failed){failed=true;(e.source as Window).postMessage({type:'jev-mario-ranking-response',id:data.id,error:'共有履歴・ランキングはログイン後に利用できます。'},location.origin);return;}(e.source as Window).postMessage({type:'jev-mario-ranking-response',id:data.id,result:data.action==='list'?[{player:'Player-test',score:1200,reached:18,cleared:17,elapsed_ms:15000,outcome:'won'}]:{saved:true}},location.origin);});});
 await lab.locator('#history-rows button').first().click();await expect(lab.locator('#history-status')).toContainText('ログイン');await lab.locator('#history-rows button').first().click();await expect(lab.locator('#history-status')).toContainText('共有しました');
 await lab.locator('#rank-course').selectOption('17');await lab.locator('#ranking-load').click();await expect(lab.locator('#ranking-rows')).toContainText('Player-test');await expect(lab.locator('#ranking-rows')).toContainText('15.0秒');await lab.locator('#ranking-rows').locator('..').screenshot({path:info.outputPath('history-ranking.png')});await lab.locator('#rank-course').locator('..').screenshot({path:info.outputPath('history-ranking-filters.png')});
});

test('64-voice syncopated ostinato audio renders audible non-clipping room arrangements and effect tails',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs?v=student-1');const all:number[]=[],metrics:any[]=[];
  for(const room of ['overworld','underground','underwater','castle','star']){let baselineRms=0;for(const boost of [1.5,1.8]){
   const c=new OfflineAudioContext(1,48000*2,48000);let now=0;const proxy=new Proxy(c,{get(target,key){if(key==='state')return 'running';if(key==='currentTime')return now;if(key==='resume')return async()=>{};const v=Reflect.get(target,key,target);return typeof v==='function'?v.bind(target):v;}});
   const a=new GameAudio(()=>proxy);await a.enable(true);a.preamp.gain.value=boost;a.setVolume(1);a.tick(room,{star:room==='star'});a.beat=11;a.next=.12;for(now=.1;now<1.35;now+=.1)a.tick(room,{star:room==='star'});a.effect('coin');const b=await c.startRendering(),samples=b.getChannelData(0);let peak=0,sum=0;for(const x of samples){peak=Math.max(peak,Math.abs(x));sum+=x*x;if(boost===1.8)all.push(x);}const rms=Math.sqrt(sum/samples.length);if(boost===1.5)baselineRms=rms;else metrics.push({room,peak,rms,baselineRms});
  }}
  const bytes=new Uint8Array(44+all.length*2),v=new DataView(bytes.buffer);const text=(at,s)=>{for(let i=0;i<s.length;i++)v.setUint8(at+i,s.charCodeAt(i));};text(0,'RIFF');v.setUint32(4,bytes.length-8,true);text(8,'WAVE');text(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,48000,true);v.setUint32(28,96000,true);v.setUint16(32,2,true);v.setUint16(34,16,true);text(36,'data');v.setUint32(40,all.length*2,true);all.forEach((x,i)=>v.setInt16(44+i*2,Math.round(Math.max(-1,Math.min(1,x))*32767),true));let base64='';for(let i=0;i<bytes.length;i+=16384)base64+=String.fromCharCode(...bytes.subarray(i,i+16384));return {metrics,wav:btoa(base64)};
 });
 for(const m of result.metrics){expect(m.peak).toBeLessThan(1);expect(m.rms).toBeGreaterThan(.001);expect(m.rms).toBeGreaterThan(m.baselineRms*1.15);}
 await (await import('node:fs/promises')).writeFile(info.outputPath('world8-audio-preview.wav'),Buffer.from(result.wav,'base64'));
 await (await import('node:fs/promises')).writeFile(info.outputPath('world8-audio-metrics.json'),JSON.stringify(result.metrics));
 await info.attach('world8-audio-preview.wav',{body:Buffer.from(result.wav,'base64'),contentType:'audio/wav'});
 await info.attach('world8-audio-metrics.json',{body:Buffer.from(JSON.stringify(result.metrics)),contentType:'application/json'});
});

test('automatic campaign share spans retry and advancement without per-stage rows',async({page})=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await page.evaluate(()=>{(window as any).campaignShares=[];window.addEventListener('message',e=>{if(e.data?.type!=='jev-mario-ranking'||e.data.action!=='submit')return;(window as any).campaignShares.push(e.data.run);(e.source as Window).postMessage({type:'jev-mario-ranking-response',id:e.data.id,result:{saved:true}},location.origin);});});
 await lab.locator('#watch-manual').click();await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){World11.prototype.step=step;(window as any).wholeRun=this;this.score=500;this.die();};});
 await expect(lab.locator('#status')).toContainText('残り2機');await expect(lab.locator('#status')).toContainText('1-1 手動プレイ中',{timeout:7000});await expect(lab.locator('#history-rows tr')).toHaveCount(0);
 await frame.evaluate(()=>{const w=(window as any).wholeRun;w.p.x=198*16;w.p.y=160;w.invincible=1000;w.frames=(400-330)*24-1;});await expect(lab.locator('#stage')).toHaveValue('2',{timeout:7000});await expect(lab.locator('#history-rows tr')).toHaveCount(0);await lab.locator('#stop').click();await expect(lab.locator('#history-rows tr')).toHaveCount(1);await expect(lab.locator('#history-status')).toContainText('自動共有しました');
 const rows=await page.evaluate(()=>(window as any).campaignShares);expect(rows).toHaveLength(1);expect(rows[0]).toMatchObject({course:1,reached:2,cleared:1,controller:'manual',outcome:'stopped',eligible:true});expect(rows[0].elapsed_ms).toBeGreaterThan(4000);expect(rows[0].score).toBeGreaterThan(500);
});

test('shared ranking loads automatically, refreshes conditions and ignores obsolete responses',async({page},info)=>{
 await page.addInitScript(()=>{window.addEventListener('message',e=>{if(e.data?.type!=='jev-mario-ranking')return;const d=e.data;setTimeout(()=>(e.source as Window).postMessage({type:'jev-mario-ranking-response',id:d.id,result:d.action==='list'?[{player:'Player-'+d.course,score:1500,reached:d.course,cleared:d.course-1,elapsed_ms:14000}]:{saved:true}},location.origin),d.course===25?700:15);});});
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');await expect(lab.locator('#ranking-rows')).toContainText('Player-1');await expect(lab.locator('a[href="#shared-ranking"]')).toBeVisible();
 await lab.locator('#rank-course').selectOption('25');await page.waitForTimeout(250);await lab.locator('#rank-course').selectOption('26');await expect(lab.locator('#ranking-rows')).toContainText('Player-26');await page.waitForTimeout(800);await expect(lab.locator('#ranking-rows')).not.toContainText('Player-25');await lab.locator('#shared-ranking').screenshot({path:info.outputPath('shared-ranking-auto.png')});
});


test('delayed LightGBM worker keeps live collision assistance and exports its contribution',async({page},info)=>{
 test.setTimeout(45000);
 await page.addInitScript(()=>{const Original=window.Worker;window.Worker=class extends Original{set onmessage(fn){super.onmessage=e=>{if(e.data?.type==='decision')setTimeout(()=>fn?.call(this,e),350);else fn?.call(this,e);};}};});
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');await lab.locator('#play-student').click();
 await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:20000});await expect(lab.locator('#student-status')).toContainText('衝突回避',{timeout:15000});await page.waitForTimeout(8000);await lab.locator('#stop').click();
 const d=page.waitForEvent('download');await lab.locator('#export').click();const stream=await(await d).createReadStream();let raw='';for await(const chunk of stream!)raw+=chunk.toString();const data=JSON.parse(raw);expect(data.student.decisions).toBeGreaterThan(1);expect(data.student.control).toContain('live collision guard');expect(data.student.samples.some((s:any)=>s.worker_round_trip_ms>=300)).toBe(true);
 await (await import('node:fs/promises')).writeFile(info.outputPath('delayed-worker.json'),raw);await lab.locator('#presentation').screenshot({path:info.outputPath('delayed-worker.png')});
});


test('local retry experience survives reload and can be cleared; Luigi is selectable',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/test/e2e/jev_mario_harness.html');let frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await frame.evaluate(async()=>{const {RetryMemory}=await import('/web/labs/jev-mario/retry-memory.mjs?v=student-1');const m=new RetryMemory();m.record({phase:'dead',stage:1,room:'overworld',p:{x:300,y:192}});});
 await page.reload();const lab=page.frameLocator('iframe');await expect(lab.locator('#retry-status')).toContainText('1か所');
 await lab.locator('#character').selectOption('luigi');await lab.locator('#watch-manual').click();await lab.locator('#stop').click();await lab.locator('#presentation').screenshot({path:info.outputPath('luigi-retry.png')});
 await lab.locator('#clear-retry').click();await expect(lab.locator('#retry-status')).toContainText('0か所');await page.reload();await expect(lab.locator('#retry-status')).toContainText('0か所');expect(errors).toEqual([]);
});


test('LightGBM worker completes 2-2 and advances to 2-3 without going offscreen',async({page},info)=>{
 test.setTimeout(120000);
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe');
 await lab.locator('#stage').selectOption('6');await lab.locator('#watch-student').click();
 await expect(lab.locator('#status')).toContainText('2-2クリア！',{timeout:100000});
 await lab.locator('#presentation').screenshot({path:info.outputPath('water-autoplay-clear.png')});
 await expect(lab.locator('#stage')).toHaveValue('7',{timeout:15000});await lab.locator('#stop').click();
 const download=page.waitForEvent('download');await lab.locator('#export').click();await(await download).saveAs(info.outputPath('water-autoplay.json'));
});

 test('4-4 worker escapes the reported fire-Mario alcove',async({page},info)=>{
  test.setTimeout(45000);await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;
  await lab.locator('#stage').selectOption('16');
  await frame.evaluate(async()=>{const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick;StudentSession.prototype.tick=function(world){StudentSession.prototype.tick=tick;(window as any).alcoveWorld=world;world.power=2;Object.assign(world.p,{x:676,y:180,h:28,grounded:true});world.camera=580;world.invincible=5000;return tick.call(this,world);};});
  // Seed before the first worker observation; do not race a reply from the start position.
  await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
  await expect.poll(()=>frame.evaluate(()=>(window as any).alcoveWorld?.p.x??0),{timeout:30000}).toBeGreaterThan(736);
  await lab.locator('#stop').click();await screenshot(page,info.outputPath('castle-alcove-escape.png'));
 });

test('2-4 worker escapes a stopped crouch under a ledge',async({page},info)=>{
 test.setTimeout(45000);await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#screen').evaluate(()=>localStorage.setItem('jev-mario-retry-world8-v1',JSON.stringify([{stage:8,room:'castle',x:367,y:192,count:12,kind:'stalled'}])));await page.reload();const reloadedFrame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#stage').selectOption('8');
 await reloadedFrame.evaluate(async()=>{const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick;let seeded=false;StudentSession.prototype.tick=function(world){if(!seeded){seeded=true;(window as any).tunnelWorld=world;world.power=1;Object.assign(world.p,{x:367,y:192,h:16,vx:0,vy:0,crouching:true,grounded:true});world.camera=271;world.invincible=1200;}return tick.call(this,world);};});
 await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
 await expect.poll(()=>reloadedFrame.evaluate(()=>(window as any).tunnelWorld?.p.x??0),{timeout:30000}).toBeGreaterThan(432);
 await lab.locator('#stop').click();await screenshot(page,info.outputPath('castle24-tunnel-escape.png'));
});

test('6-2 real worker retreats from the overhang and enters the defined pipe',async({page},info)=>{
 test.setTimeout(60000);await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#stage').selectOption('22');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick,step=World11.prototype.step,enter=World11.prototype.enterRoom,exit=World11.prototype.exitRoom;(window as any).pipeEvents={entered:false,returned:null,trace:[]};let seeded=false;StudentSession.prototype.tick=function(world){if(!seeded){seeded=true;(window as any).pipeWorld=world;world.power=2;Object.assign(world.p,{x:2484,y:180,h:28,vx:0,vy:0,grounded:true});world.camera=2388;world.invincible=5000;}return tick.call(this,world);};World11.prototype.enterRoom=function(){const result=enter.call(this);if(this===(window as any).pipeWorld&&result&&this.pipeReturn.id==='22:156')(window as any).pipeEvents.entered=true;return result;};World11.prototype.exitRoom=function(){const result=exit.call(this);if(this===(window as any).pipeWorld&&result&&(window as any).pipeEvents.entered)(window as any).pipeEvents.returned={stage:this.stage,x:this.p.x,y:this.p.y,room:this.room,power:this.power,frames:this.frames};return result;};World11.prototype.step=function(){step.call(this);if(this===(window as any).pipeWorld&&this.frames%12===0){const t=(window as any).pipeEvents.trace;t.push([this.frames,this.room,this.p.x,this.p.y,this.phase,this.input]);if(t.length>180)t.shift();}};});
 await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
 try{await expect.poll(()=>frame.evaluate(()=>(window as any).pipeEvents.returned),{timeout:45000}).toBeTruthy();const result=await frame.evaluate(()=>(window as any).pipeEvents.returned);expect(result).toMatchObject({stage:22,room:'overworld',x:2544,power:2});}
 finally{await lab.locator('#stop').click();const state=await frame.evaluate(()=>(window as any).pipeEvents);await (await import('node:fs/promises')).writeFile(info.outputPath('world62-pipe-escape.json'),JSON.stringify(state));await screenshot(page,info.outputPath('world62-pipe-escape.png'));}
});


test('6-2 live small player passes the first entrance with active enemies and retry memory',async({page},info)=>{
 test.setTimeout(60000);await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#stage').selectOption('22');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick,step=World11.prototype.step;let seeded=false;(window as any).entranceTrace=[];StudentSession.prototype.tick=function(world){if(!seeded){seeded=true;(window as any).entranceWorld=world;Object.assign(world.p,{x:900,y:192,vx:0,vy:0,grounded:true});world.camera=804;this.failures=[{stage:22,room:'overworld',x:988,y:160,kind:'death',count:4}];}return tick.call(this,world);};World11.prototype.step=function(){step.call(this);if(this===(window as any).entranceWorld&&this.frames%12===0)(window as any).entranceTrace.push({frame:this.frames,x:this.p.x,y:this.p.y,room:this.room,phase:this.phase,input:this.input,deaths:this.deaths});};});
 await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
 try{await expect.poll(()=>frame.evaluate(()=>{const g=(window as any).entranceWorld;return g?.room==='overworld'&&g.p.x>=1100&&g.deaths===0;}),{timeout:45000}).toBeTruthy();}
 finally{await lab.locator('#stop').click();await(await import('node:fs/promises')).writeFile(info.outputPath('world62-first-entrance.json'),JSON.stringify(await frame.evaluate(()=>(window as any).entranceTrace)));await screenshot(page,info.outputPath('world62-first-entrance.png'));}
});


test('6-2 complete real worker course collects items and clears with normal hazards',async({page},info)=>{
 test.skip(info.project.name==='mobile','The complete run uses desktop; mobile entrance and overhang recovery are covered separately.');test.setTimeout(120000);
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#stage').selectOption('22');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick,step=World11.prototype.step;(window as any).courseTrace=[];(window as any).courseClear=null;(window as any).courseTotals={mushroom:0,flower:0,life:0,star:0};let previous={mushroom:0,flower:0,life:0,star:0},totalFrames=0;StudentSession.prototype.tick=function(world){(window as any).courseWorld=world;if(!(window as any).courseSeeded){(window as any).courseSeeded=true;this.failures=[{stage:22,room:'overworld',x:988,y:160,kind:'death',count:4},{stage:22,room:'overworld',x:2484,y:180,kind:'stalled',count:4}];}return tick.call(this,world);};World11.prototype.step=function(){step.call(this);if(this!==(window as any).courseWorld)return;totalFrames++;for(const kind of Object.keys(previous)){(window as any).courseTotals[kind]+=Math.max(0,this.pickups[kind]-previous[kind]);previous[kind]=this.pickups[kind];}if(this.frames%60===0)(window as any).courseTrace.push({frame:this.frames,x:this.p.x,y:this.p.y,room:this.room,phase:this.phase,lives:this.lives,pickups:{...this.pickups},input:{...this.input},power:this.power});if(this.stage===22&&this.phase==='won')(window as any).courseClear={frames:this.frames,totalFrames,x:this.p.x,lives:this.lives,deaths:this.deaths,pickups:{...(window as any).courseTotals},finalAttemptPickups:{...this.pickups},visited:[...this.visitedPipes]};};});
 await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
 try{await expect.poll(()=>frame.evaluate(()=>(window as any).courseClear),{timeout:100000}).toBeTruthy();const result=await frame.evaluate(()=>(window as any).courseClear);expect(result.pickups.mushroom).toBeGreaterThan(0);}
 finally{await lab.locator('#stop').click();await(await import('node:fs/promises')).writeFile(info.outputPath('world62-complete-worker.json'),JSON.stringify(await frame.evaluate(()=>({clear:(window as any).courseClear,trace:(window as any).courseTrace}))));await screenshot(page,info.outputPath('world62-complete-worker.png'));}
});

test('8-4 complete real worker castle collects items and clears with normal hazards',async({page},info)=>{
 test.skip(info.project.name==='mobile','The complete run uses desktop; mobile entrance and overhang recovery are covered separately.');test.setTimeout(180000);
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.parentFrame())!;await lab.locator('#stage').selectOption('32');
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const {StudentSession}=await import('/web/labs/jev-mario/student-session.mjs?v=student-1');const tick=StudentSession.prototype.tick,step=World11.prototype.step;(window as any).courseTrace=[];(window as any).courseClear=null;(window as any).courseTotals={mushroom:0,flower:0,life:0,star:0};let previous={mushroom:0,flower:0,life:0,star:0},totalFrames=0;StudentSession.prototype.tick=function(world){(window as any).courseWorld=world;return tick.call(this,world);};World11.prototype.step=function(){step.call(this);if(this!==(window as any).courseWorld)return;totalFrames++;for(const kind of Object.keys(previous)){(window as any).courseTotals[kind]+=Math.max(0,this.pickups[kind]-previous[kind]);previous[kind]=this.pickups[kind];}if(this.frames%60===0)(window as any).courseTrace.push({frame:this.frames,x:this.p.x,y:this.p.y,room:this.room,phase:this.phase,lives:this.lives,pickups:{...this.pickups},input:{...this.input},power:this.power});if(this.stage===32&&this.phase==='won')(window as any).courseClear={frames:this.frames,totalFrames,x:this.p.x,lives:this.lives,deaths:this.deaths,pickups:{...(window as any).courseTotals},finalAttemptPickups:{...this.pickups},visited:[...this.visitedPipes]};};});
 await lab.locator('#play-student').click();await expect(lab.locator('#status')).toContainText('LightGBM＋探索でプレイ中',{timeout:15000});
 try{await expect.poll(()=>frame.evaluate(()=>(window as any).courseClear),{timeout:160000}).toBeTruthy();const result=await frame.evaluate(()=>(window as any).courseClear);expect(result.pickups.mushroom).toBeGreaterThan(0);}
 finally{await lab.locator('#stop').click();await(await import('node:fs/promises')).writeFile(info.outputPath('world84-complete-worker.json'),JSON.stringify(await frame.evaluate(()=>({clear:(window as any).courseClear,trace:(window as any).courseTrace}))));await screenshot(page,info.outputPath('world84-complete-worker.png'));}
});


test('castle dominant resolves to the minor hook in rendered browser audio',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{
  const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs?v=student-1');const c=new OfflineAudioContext(1,48000*2,48000);let now=0;
  const proxy=new Proxy(c,{get(target,key){if(key==='state')return 'running';if(key==='currentTime')return now;if(key==='resume')return async()=>{};const v=Reflect.get(target,key,target);return typeof v==='function'?v.bind(target):v;}});
  const a=new GameAudio(()=>proxy);await a.enable(true);a.track='castle';a.beat=62;a.next=0;const lead:any[]=[];const tone=a.tone.bind(a);
  a.tone=(...args)=>{if(args[0]&&args[4]===.052)lead.push({note:args[0],time:args[1]});return tone(...args);};
  for(now=0;now<.4;now+=.025)a.tick('castle');const buffer=await c.startRendering(),samples=buffer.getChannelData(0);let peak=0,sum=0;for(const x of samples){peak=Math.max(peak,Math.abs(x));sum+=x*x;}
  return {lead,peak,rms:Math.sqrt(sum/samples.length),maxVoices:a.nodes.size};
 });
 expect(result.lead.slice(0,2).map(n=>n.note)).toEqual([63,64]);expect(result.lead[1].time).toBeGreaterThan(result.lead[0].time);expect(result.lead[1].time).toBeLessThan(.26);
 expect(result.peak).toBeLessThan(1);expect(result.rms).toBeGreaterThan(.001);expect(result.maxVoices).toBeLessThanOrEqual(64);
 await (await import('node:fs/promises')).writeFile(info.outputPath('castle-minor-cadence.json'),JSON.stringify(result));
});


test('bass and drums alone render an octave groove with audible space',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{
  const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs?v=student-1');const c=new OfflineAudioContext(1,48000*2,48000);let now=0;
  const proxy=new Proxy(c,{get(target,key){if(key==='state')return 'running';if(key==='currentTime')return now;if(key==='resume')return async()=>{};const v=Reflect.get(target,key,target);return typeof v==='function'?v.bind(target):v;}});
  const a=new GameAudio(()=>proxy);await a.enable(true);const bass:any[]=[];const tone=a.tone.bind(a);
  a.tone=(...args)=>{if(args[4]===.105){bass.push({note:args[0],time:args[1],duration:args[2]});return tone(...args);}if(args[4]===.055)return tone(...args);};
  for(now=0;now<1.3;now+=.025)a.tick('overworld');const b=await c.startRendering(),samples=b.getChannelData(0);let peak=0,sum=0;for(const x of samples){peak=Math.max(peak,Math.abs(x));sum+=x*x;}return {bass,peak,rms:Math.sqrt(sum/samples.length)};
 });
 expect(result.bass.slice(0,2).map(n=>n.note)).toEqual([48,60]);expect(result.bass[1].duration).toBeLessThan(.145);expect(result.bass[3].time-result.bass[2].time-result.bass[2].duration).toBeGreaterThan(.3);
 expect(result.peak).toBeLessThan(1);expect(result.rms).toBeGreaterThan(.001);await (await import('node:fs/promises')).writeFile(info.outputPath('bass-drums-groove.json'),JSON.stringify(result));
});

test('manual movement brakes after release and holding jump does not auto-bounce',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step,sound=World11.prototype.sound;(window as any).jumpCount=0;World11.prototype.step=function(){if(!(window as any).controlWorld){(window as any).controlWorld=this;this.enemies=[];this.cells=new Map();this.contents=new Map();for(let x=0;x<30;x++)this.cells.set(`${x},13`,'ground');}return step.call(this);};World11.prototype.sound=function(name){if(name==='jump')(window as any).jumpCount++;return sound.call(this,name);};});
 await lab.locator('#watch-manual').click();await lab.locator('#screen').focus();await page.keyboard.down('ArrowRight');await page.waitForTimeout(300);await page.keyboard.up('ArrowRight');await expect.poll(()=>frame.evaluate(()=>(window as any).controlWorld?.p.vx),{timeout:3000}).toBe(0);
 await page.keyboard.down('Space');await expect(lab.locator('#posture')).toContainText('上昇');await page.waitForTimeout(1800);expect(await frame.evaluate(()=>(window as any).jumpCount)).toBe(1);expect(await frame.evaluate(()=>(window as any).controlWorld.p.grounded)).toBe(true);
 await page.keyboard.up('Space');await lab.locator('#stop').click();await lab.locator('#presentation').screenshot({path:info.outputPath('manual-control-response.png')});
});


test('contrasting backing timbres render distinct non-clipping browser waveforms',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{
  const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs?v=student-1');const rendered:any[]=[];
  for(const type of ['square','bass','pluck']){
   const c=new OfflineAudioContext(1,24000,48000),proxy=new Proxy(c,{get(t,k){if(k==='state')return 'running';if(k==='resume')return async()=>{};const v=Reflect.get(t,k,t);return typeof v==='function'?v.bind(t):v;}});
   const a=new GameAudio(()=>proxy);await a.enable(true);a.tone(48,0,.35,type,.08,true);
   const b=await c.startRendering(),data=b.getChannelData(0);let peak=0,sum=0;for(const x of data){peak=Math.max(peak,Math.abs(x));sum+=x*x;}
   rendered.push({type,peak,rms:Math.sqrt(sum/data.length),samples:[...data.slice(480,960)]});
  }
  return rendered;
 });
 for(const voice of result){expect(voice.rms).toBeGreaterThan(.001);expect(voice.peak).toBeLessThan(1);}
 for(let i=0;i<result.length;i++)for(let j=i+1;j<result.length;j++){const delta=result[i].samples.reduce((v,x,k)=>v+Math.abs(x-result[j].samples[k]),0)/480;expect(delta).toBeGreaterThan(.001);}
 await(await import('node:fs/promises')).writeFile(info.outputPath('contrasting-timbres.json'),JSON.stringify(result));
});


test('the opening step teaches a real jump without a tutorial overlay',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const lab=page.frameLocator('iframe'),frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 await frame.evaluate(async()=>{const {World11}=await import('/web/labs/jev-mario/world11.mjs?v=student-1');const step=World11.prototype.step;World11.prototype.step=function(){(window as any).openingWorld=this;return step.call(this);};});
 await lab.locator('#watch-manual').click();await lab.locator('#screen').focus();await page.keyboard.down('ArrowRight');
 await expect.poll(()=>frame.evaluate(()=>(window as any).openingWorld?.p.x),{timeout:5000}).toBe(148);
 await page.keyboard.down('Space');await expect.poll(()=>frame.evaluate(()=>(window as any).openingWorld?.p.x),{timeout:3000}).toBeGreaterThan(180);
 await page.keyboard.up('Space');await page.keyboard.up('ArrowRight');expect(await frame.evaluate(()=>(window as any).openingWorld.phase)).toBe('playing');await lab.locator('#stop').click();
 await lab.locator('#presentation').screenshot({path:info.outputPath('opening-step.png')});
});
test('nearby boss octave lead renders within the voice budget and without clipping',async({page},info)=>{
 await page.goto('/test/e2e/jev_mario_harness.html');const frame=page.frames().find(f=>f.url().includes('/labs/jev-mario/'))!;
 const result=await frame.evaluate(async()=>{
  const {GameAudio}=await import('/web/labs/jev-mario/audio.mjs?v=student-1');const c=new OfflineAudioContext(1,96000,48000);let now=0;
  const proxy=new Proxy(c,{get(t,k){if(k==='state')return 'running';if(k==='currentTime')return now;if(k==='resume')return async()=>{};const v=Reflect.get(t,k,t);return typeof v==='function'?v.bind(t):v;}});
  const a=new GameAudio(()=>proxy);await a.enable(true);const calls:any[]=[],tone=a.tone.bind(a);let peakVoices=0;
  a.tone=(...args)=>{calls.push(args);tone(...args);peakVoices=Math.max(peakVoices,a.nodes.size);};
  for(now=0;now<1;now+=.025)a.tick('castle',{boss:true});const b=await c.startRendering();let peak=0,sum=0;for(const x of b.getChannelData(0)){peak=Math.max(peak,Math.abs(x));sum+=x*x;}
  return {calls,peakVoices,peak,rms:Math.sqrt(sum/b.length)};
 });
 const lead=result.calls.find(x=>x[4]===.052&&x[0]>0);expect(lead).toBeTruthy();
 for(const [offset,gain]of [[12,.018],[-12,.012]])expect(result.calls.some(x=>x[0]===lead[0]+offset&&x[1]===lead[1]&&x[2]===lead[2]&&x[4]===gain)).toBeTruthy();
 expect(result.peakVoices).toBeLessThanOrEqual(64);expect(result.peak).toBeLessThan(1);expect(result.rms).toBeGreaterThan(.001);
 await(await import('node:fs/promises')).writeFile(info.outputPath('boss-octave-audio.json'),JSON.stringify(result));
});
