import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const origin='https://my-web-app-b67f4.web.app',out='echo-recording';
const expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[a-f0-9]{40}$/);mkdirSync(out,{recursive:true});
const hold=ms=>new Promise(r=>setTimeout(r,ms));
async function version(){const r=await fetch(`${origin}/version.json`,{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version();const browser=await chromium.launch({headless:true});
const errors=[],events=[],fontRequests=[];
// A clean context, no authentication cookies or user data.
const context=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP',recordVideo:{dir:out,size:{width:1440,height:1080}}});
const page=await context.newPage(),video=page.video(),started=Date.now();
page.on('response',r=>{if(/font|\.woff|\.ttf|\.otf/i.test(r.url()))fontRequests.push({seconds:(Date.now()-started)/1000,url:r.url(),status:r.status()});});
const mark=action=>events.push({seconds:(Date.now()-started)/1000,action});
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const button=name=>page.getByRole(/^[ABC] /.test(name)?'checkbox':'button',{name,exact:true});
async function click(name){await button(name).click({timeout:12000});mark(name);await hold(850);}
let after,ready=0;
try{
  // Rehearse the real public UI before the retained take. Flutter's canvas
  // fallback fonts can be fetched lazily as Japanese glyphs first appear.
  // Keep this warm-up in the raw recording; trim only the continuous prefix.
  await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});
  const warmAccessibility=page.locator('flt-semantics-placeholder');
  if(await warmAccessibility.count())await warmAccessibility.click({force:true});
  await button('ゲーム開始').waitFor({timeout:60000});await hold(3000);
  await click('ゲーム開始');await hold(20000);
  if(await button('スキップして開始').count())await click('スキップして開始');
  await button('A 搬入').waitFor({timeout:15000});
  for(const label of ['B 整備','A 搬入','中央廊下へ','工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ','ヒューズで修理','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ','隔壁を閉じる','排水ポンプを起動','中央廊下へ','管理室へ','出口へ'])await click(label);
  await button('リトライ').waitFor({timeout:10000});await hold(3000);
  mark('font-warmup-complete');
  await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});
  // Enable Flutter's documented accessibility activation control when necessary.
  const accessibility=page.locator('flt-semantics-placeholder');
  if(await accessibility.count())await accessibility.click({force:true});
  await button('ゲーム開始').waitFor({timeout:60000});
  await page.evaluate(()=>document.fonts.ready);await hold(4000);ready=(Date.now()-started)/1000;mark('title-ready');
  await page.screenshot({path:`${out}/title.png`});await hold(2200);
  await click('ゲーム開始');await hold(4500);
  await page.screenshot({path:`${out}/intro.png`});await click('スキップして開始');
  await button('A 搬入').waitFor({timeout:15000});
  await page.screenshot({path:`${out}/game.png`});
  // Ordinary user controls only; the same complete route used by product E2E.
  for(const label of ['B 整備','A 搬入','中央廊下へ','工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ','ヒューズで修理','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ','隔壁を閉じる','排水ポンプを起動','中央廊下へ','管理室へ','出口へ']){
    await click(label);
    if(label==='隔壁を閉じる'){
      await page.mouse.move(720,600);await page.mouse.wheel(0,600);await hold(1500);
      await page.screenshot({path:`${out}/sealed.png`});
      await page.mouse.wheel(0,-600);await hold(500);
    }
  }
  await button('リトライ').waitFor({timeout:10000});
  const body=await page.locator('body').innerText();
  writeFileSync(`${out}/final-body.txt`,body);
  assert.match(body,/脱出/);mark('escape-confirmed');
  await page.screenshot({path:`${out}/escape.png`});await hold(4500);
  after=await version();assert.deepEqual(errors,[]);
}finally{
  writeFileSync(`${out}/evidence.json`,JSON.stringify({before,after,ready,events,errors,fontRequests,method:'Actual public production UI; full ordinary-UI font warm-up before retained continuous take; no cookies/state injection; no audio',passed:!!after&&errors.length===0},null,2));
  await context.close();await browser.close();
}
const raw=await video.path(),final=`${out}/echo-pump-x.mp4`;
execFileSync('ffmpeg',['-y','-ss',String(ready),'-i',raw,'-an','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',final],{stdio:'inherit'});
const probe=JSON.parse(execFileSync('ffprobe',['-v','quiet','-show_format','-show_streams','-of','json',final],{encoding:'utf8'}));
assert(+probe.format.duration>=30&&+probe.format.duration<=65);
for(const t of [1,9,20,30])execFileSync('ffmpeg',['-y','-ss',String(t),'-i',final,'-frames:v','1',`${out}/frame-${t}.jpg`],{stdio:'ignore'});
// Dense transition samples, not just four stills. Retain for visual review.
execFileSync('ffmpeg',['-y','-i',final,'-vf','fps=5,scale=480:360,tile=5x5','-vsync','vfr',`${out}/contact-%02d.jpg`],{stdio:'ignore'});
writeFileSync(`${out}/media-check.json`,JSON.stringify({raw,final,trim:ready,speed:1,probe},null,2));
