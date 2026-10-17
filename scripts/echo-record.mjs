import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync,statSync} from 'node:fs';
import {spawn,execFileSync} from 'node:child_process';
const origin='https://my-web-app-b67f4.web.app',out='echo-recording';
const expected=process.env.EXPECTED_PRODUCTION_SHA;
mkdirSync(out,{recursive:true});
async function version(){const v=await(await fetch(`${origin}/version.json`,{cache:'no-store'})).json();assert.equal(v.commit,expected);return v;}
const before=await version(),errors=[],events=[];
const browser=await chromium.launch({headless:false,ignoreDefaultArgs:['--mute-audio']});
const context=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP',recordVideo:{dir:out,size:{width:1440,height:1080}}});
const page=await context.newPage(),video=page.video(),start=Date.now();
const audio=spawn('ffmpeg',['-y','-f','pulse','-i','echo.monitor','-c:a','pcm_s16le',`${out}/browser-audio.wav`],{stdio:['pipe','ignore','inherit']});
const stopped=new Promise((resolve,reject)=>audio.once('exit',code=>code===0?resolve():reject(new Error(`audio ${code}`))));
const hold=ms=>new Promise(r=>setTimeout(r,ms));
const b=name=>page.getByRole('button',{name,exact:true});
const mark=action=>events.push({seconds:(Date.now()-start)/1000,action});
page.on('pageerror',e=>errors.push(e.message));
async function top(){await page.mouse.move(720,540);await page.mouse.wheel(0,-10000);await hold(250);}
async function click(name,wait=500){await b(name).click({timeout:15000});mark(name);await hold(wait);}
async function load(){await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});const a=page.locator('flt-semantics-placeholder');await a.waitFor({state:'attached',timeout:60000});await a.dispatchEvent('click');await b('ゲーム開始').waitFor({timeout:60000});await hold(2500);}
async function explore(retain){
  await click('ゲーム開始');await click('スキップして開始');
  await b('保守メモを調べる').waitFor({timeout:20000});await top();
  if(retain){await page.screenshot({path:`${out}/room.png`});await hold(3000);}
  await click('設備寄りに見る',1500);
  await click('保守メモを調べる',300);
  await page.getByText('夜間保守メモ 1 / 2',{exact:true}).waitFor({timeout:15000});
  if(retain){await page.screenshot({path:`${out}/memo-one.png`});await hold(3500);}
  await click('次のページ',500);
  await page.getByText('夜間保守メモ 2 / 2',{exact:true}).waitFor();
  if(retain){await page.screenshot({path:`${out}/memo-two.png`});await hold(3500);}
  await click('メモを閉じる',700);
  await click('中央廊下の扉を調べる',300);
  await b('扉を開けて進む').waitFor({timeout:15000});
  if(retain){await page.screenshot({path:`${out}/door.png`});await hold(3500);}
  await click('戻る',700);
  await click('中央廊下の扉を調べる',400);
  await b('扉を開けて進む').waitFor({timeout:15000});
  await click('扉を開けて進む',1000);
  await page.getByText('ターン 1',{exact:true}).first().waitFor({timeout:15000});
  await top();if(retain){await page.screenshot({path:`${out}/hall.png`});await hold(4000);}
}
let ready,after;
try{
  await load();await explore(false);await hold(2500);
  await load();await page.evaluate(()=>document.fonts.ready);await hold(2500);
  ready=(Date.now()-start)/1000;mark('retained-take-start');
  await click('音をON',1000);await hold(1800);await explore(true);
  after=await version();assert.deepEqual(errors,[]);
}finally{
  writeFileSync(`${out}/evidence.json`,JSON.stringify({before,after,ready,events,errors,method:'Public production room exploration with ordinary controls; full UI warm-up; clean headed Chromium + dedicated PulseAudio; no microphone/cookies/game-state injection'},null,2));
  await context.close();await browser.close();audio.stdin.write('q');await stopped;
}
const raw=await video.path(),final=`${out}/echo-pump-room-x.mp4`;
execFileSync('ffmpeg',['-y','-ss',String(ready),'-i',raw,'-ss',String(ready),'-i',`${out}/browser-audio.wav`,'-map','0:v:0','-map','1:a:0','-shortest','-c:v','libx264','-preset','medium','-b:v','650k','-pix_fmt','yuv420p','-c:a','aac','-b:a','64k','-movflags','+faststart',final],{stdio:'inherit'});
const probe=JSON.parse(execFileSync('ffprobe',['-v','quiet','-show_format','-show_streams','-of','json',final],{encoding:'utf8'}));
assert(statSync(final).size<5000000);assert(+probe.format.duration>25&&+probe.format.duration<65);
const levels=spawn('ffmpeg',['-hide_banner','-i',final,'-af','volumedetect','-vn','-f','null','-']);let levelText='';levels.stderr.on('data',x=>levelText+=x);await new Promise(r=>levels.on('exit',r));
writeFileSync(`${out}/audio-level.txt`,levelText);assert(!levelText.includes('mean_volume: -inf'));
execFileSync('ffmpeg',['-y','-i',final,'-vf','fps=5,scale=480:360,tile=5x5','-vsync','vfr',`${out}/contact-%02d.jpg`],{stdio:'ignore'});
writeFileSync(`${out}/media-check.json`,JSON.stringify({raw,final,trim:ready,speed:1,bytes:statSync(final).size,probe},null,2));
