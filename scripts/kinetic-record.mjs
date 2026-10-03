// Record the real deployed UI only, after exact production revision validation.
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const origin='https://my-web-app-b67f4.web.app',out='kinetic-recording';
const expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[a-f0-9]{40}$/);mkdirSync(out,{recursive:true});
async function version(){const r=await fetch(`${origin}/version.json`,{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version(),browser=await chromium.launch({headless:true});
const errors=[],events=[];const hold=ms=>new Promise(r=>setTimeout(r,ms));
async function phase(lab,wanted){await lab.locator('#phase').filter({hasText:new RegExp(`^${wanted}$`)}).waitFor({timeout:20000});}
const smoke=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP'});
const route=await smoke.newPage();route.on('pageerror',e=>errors.push(e.message));
await route.goto(`${origin}/kinetic-forge`,{waitUntil:'domcontentloaded'});
const lab=route.frameLocator('iframe[title="KINETIC FORGE 描画コース実験"]');
await lab.locator('#play').waitFor({timeout:60000});
await lab.locator('#play').click();await phase(lab,'TRY AGAIN');
await lab.locator('#retry').click();await lab.locator('#sample').click();
await lab.locator('#play').click();await phase(lab,'ARRIVED');
await route.screenshot({path:`${out}/production-route.png`});await smoke.close();
const context=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP',recordVideo:{dir:out,size:{width:1440,height:1080}}});
const page=await context.newPage(),video=page.video(),start=Date.now();
const mark=action=>events.push({seconds:(Date.now()-start)/1000,action});
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
async function draw(a,b){
  const box=await page.locator('#board').boundingBox();assert(box);
  await page.mouse.move(box.x+a[0]/900*box.width,box.y+a[1]/540*box.height);await page.mouse.down();
  for(let i=1;i<=16;i++){await page.mouse.move(box.x+(a[0]+(b[0]-a[0])*i/16)/900*box.width,box.y+(a[1]+(b[1]-a[1])*i/16)/540*box.height);await hold(45);}
  await page.mouse.up();
}
let after;
try{
  await page.goto(`${origin}/labs/kinetic-forge/index.html`,{waitUntil:'networkidle'});
  await page.locator('#play').waitFor();mark('ready');
  await page.locator('#sample').click();await hold(700);await page.locator('#play').click();
  await phase(page,'ARRIVED');mark('opening-arrival');await hold(2000);
  await page.locator('#retry').click();await page.locator('#clear').click();
  await draw([80,180],[350,280]);mark('short-ramp-drawn');await hold(700);
  await page.locator('#play').click();await phase(page,'TRY AGAIN');mark('short-ramp-failed');await hold(2000);
  await page.locator('#retry').click();await page.locator('#undo').click();
  assert.match(await page.locator('#line-count').innerText(),/^0 /);mark('undo');await hold(900);
  await draw([80,180],[760,440]);mark('corrected-ramp-drawn');await hold(700);
  await page.locator('#play').click();await phase(page,'ARRIVED');mark('drawn-course-arrival');await hold(3500);
  for(const level of ['1','2']){
    await page.locator('#level').selectOption(level);await page.locator('#sample').click();mark(`sample-level-${level}`);await hold(1000);
    await page.locator('#play').click();await phase(page,'ARRIVED');mark(`arrival-level-${level}`);await hold(4000);
  }
  await page.screenshot({path:`${out}/solved.png`});
  const length=(Date.now()-start)/1000-events.find(e=>e.action==='ready').seconds;
  if(length<34)await hold((34-length)*1000);
  after=await version();assert.deepEqual(errors,[]);
}finally{
  await context.close();await browser.close();
  writeFileSync(`${out}/evidence.json`,JSON.stringify({before,after,events,errors,method:'Actual deployed app with ordinary clicks and pointer drags; clean context, no user cookies/audio/generated footage',passed:Boolean(after)&&errors.length===0},null,2));
}
const raw=await video.path(),trim=events.find(e=>e.action==='ready').seconds,final=`${out}/kinetic-forge-x.mp4`;
execFileSync('ffmpeg',['-y','-i',raw,'-ss',String(trim),'-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',final]);
const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_streams','-show_format','-of','json',final]));
assert(probe.streams.some(s=>s.codec_name==='h264'&&s.width===1440&&s.height===1080));
assert(Number(probe.format.duration)>=30&&Number(probe.format.duration)<=60);
writeFileSync(`${out}/media-check.json`,JSON.stringify({raw,final,trim,speed:1,probe},null,2));
for(const second of [1,8,20,30])execFileSync('ffmpeg',['-y','-ss',String(second),'-i',final,'-frames:v','1',`${out}/frame-${second}.jpg`]);
