// Real production browser recording. No cookies, generated footage or private UI hooks.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const origin='https://my-web-app-b67f4.web.app', out='lumen-recording';
const expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[a-f0-9]{40}$/); mkdirSync(out,{recursive:true});
async function version(){const r=await fetch(`${origin}/version.json`,{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version(), browser=await chromium.launch({headless:true});
const errors=[],events=[];
const smoke=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP'});
const route=await smoke.newPage(); route.on('pageerror',e=>errors.push(e.message));
await route.goto(`${origin}/lumen-path`,{waitUntil:'domcontentloaded'});
const lab=route.frameLocator('iframe');
await lab.locator('#lit').waitFor({timeout:60000});
await lab.getByRole('button',{name:/鏡 1、/}).click();
assert.equal(await lab.locator('#lit').innerText(),'1 / 1 LIGHTS');
await lab.locator('#undo').click(); assert.equal(await lab.locator('#lit').innerText(),'0 / 1 LIGHTS');
await route.screenshot({path:`${out}/production-route.png`}); await smoke.close();
const context=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP',recordVideo:{dir:out,size:{width:1440,height:1080}}});
const page=await context.newPage(),video=page.video(),start=Date.now();
const mark=action=>events.push({seconds:(Date.now()-start)/1000,action});
const hold=ms=>new Promise(r=>setTimeout(r,ms));
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
let after;
try{
  await page.goto(`${origin}/labs/lumen-path/index.html`,{waitUntil:'networkidle'});
  await page.locator('#lit').waitFor(); mark('ready'); await hold(2000);
  await page.getByRole('button',{name:/鏡 1、/}).click(); mark('room1-solved');
  assert.equal(await page.locator('#lit').innerText(),'1 / 1 LIGHTS'); await hold(4000);
  await page.locator('#undo').click(); mark('undo');
  assert.equal(await page.locator('#lit').innerText(),'0 / 1 LIGHTS'); await hold(3000);
  await page.locator('#level').selectOption('1'); mark('room2'); await hold(2000);
  for(let i=0;i<3;i++){
    const prior=await page.locator('#moves').innerText();
    await page.locator('#hint').click(); assert.equal(await page.locator('#moves').innerText(),prior);
    await hold(1000); await page.locator('button.hinted').click(); mark(`room2-mirror-${i+1}`); await hold(2000);
  }
  assert.equal(await page.locator('#lit').innerText(),'1 / 1 LIGHTS'); await hold(2000);
  await page.locator('#next').click(); mark('room3'); await hold(2000);
  for(let i=1;i<=3;i++){await page.getByRole('button',{name:new RegExp(`鏡 ${i}、`)}).click();mark(`room3-mirror-${i}`);await hold(2500);}
  assert.equal(await page.locator('#lit').innerText(),'3 / 3 LIGHTS');
  await page.screenshot({path:`${out}/solved.png`}); await hold(6000);
  after=await version(); assert.deepEqual(errors,[]);
}finally{
  await context.close();await browser.close();
  writeFileSync(`${out}/evidence.json`,JSON.stringify({before,after,events,errors,method:'Actual public production UI, normal clicks, no cookies/audio/generated frames',passed:Boolean(after)&&errors.length===0},null,2));
}
const raw=await video.path(), trim=events.find(e=>e.action==='ready').seconds, final=`${out}/lumen-path-x.mp4`;
execFileSync('ffmpeg',['-y','-i',raw,'-ss',String(trim),'-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',final]);
const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_streams','-show_format','-of','json',final]));
assert(probe.streams.some(s=>s.codec_name==='h264'&&s.width===1440&&s.height===1080));
assert(Number(probe.format.duration)>=30&&Number(probe.format.duration)<=60);
writeFileSync(`${out}/media-check.json`,JSON.stringify({raw,final,trim,speed:1,probe},null,2));
for(const second of [1,8,22,36])execFileSync('ffmpeg',['-y','-ss',String(second),'-i',final,'-frames:v','1',`${out}/frame-${second}.jpg`]);
