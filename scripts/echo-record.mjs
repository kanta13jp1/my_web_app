import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync,statSync,readFileSync} from 'node:fs';
import {spawn,execFileSync} from 'node:child_process';
const origin='https://my-web-app-b67f4.web.app',out='echo-recording';
const expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[a-f0-9]{40}$/);
mkdirSync(out,{recursive:true});writeFileSync(out+'/record-source.mjs',readFileSync(new URL(import.meta.url)));
async function version(){const v=await(await fetch(origin+'/version.json',{cache:'no-store'})).json();assert.equal(v.commit,expected);return v;}
const before=await version(),errors=[],events=[];
const browser=await chromium.launch({headless:false,ignoreDefaultArgs:['--mute-audio']});
const context=await browser.newContext({viewport:{width:1440,height:1080},locale:'ja-JP',recordVideo:{dir:out,size:{width:1440,height:1080}}});
const page=await context.newPage(),video=page.video(),start=Date.now();
const audio=spawn('ffmpeg',['-y','-f','pulse','-i','echo.monitor','-c:a','pcm_s16le',out+'/browser-audio.wav'],{stdio:['pipe','ignore','inherit']});
const stopped=new Promise((resolve,reject)=>audio.once('exit',code=>code===0?resolve():reject(new Error('audio '+code))));
const hold=ms=>new Promise(r=>setTimeout(r,ms));
const b=name=>page.getByRole('button',{name,exact:true});
const inv=()=>page.getByRole('button',{name:/^所持品：/});
const txt=name=>page.getByText(name,{exact:true}).first();
const mark=action=>events.push({seconds:(Date.now()-start)/1000,action});
page.on('pageerror',e=>errors.push(e.message));
async function click(name,wait=400){await b(name).click({timeout:15000});mark(name);await hold(wait);}
async function load(){
 await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
 const deadline=Date.now()+60000;
 while(Date.now()<deadline){
  if(await b('ゲーム開始').isVisible()){await hold(2500);mark('load-ready');return;}
  const placeholder=page.locator('flt-semantics-placeholder');
  if(await placeholder.count())await placeholder.dispatchEvent('click');
  await hold(250);
 }
 await page.screenshot({path:out+'/load-failed.png'});
 throw new Error('Public game start button not visible after bounded semantics initialization');
}
async function shot(name,retain,delay=2500){if(retain){await page.screenshot({path:out+'/'+name+'.png'});await hold(delay);}}
async function run(retain){
 await click('ゲーム開始');await click('スキップして開始');
 await hold(1800);
 for(const label of ['B 整備','A 搬入']){
  await page.getByRole('checkbox',{name:label,exact:true}).click();await hold(500);
 }
 for(const [i,label] of ['中央廊下へ','工具庫へ','中央廊下へ','ポンプ室へ','中央廊下へ','管理室へ'].entries()){
  await b(label).click({timeout:15000});mark(label);
  await hold(300);
  if(retain)await page.screenshot({path:out+'/door-'+i+'-opening.png'});
  await hold(600);
  if(retain)await page.screenshot({path:out+'/door-'+i+'-closing.png'});
  await hold(1500);
  await shot('arrival-'+i,retain,1800);
 }
 await b('中央廊下へ').waitFor({state:'visible',timeout:15000});
 mark('returned-to-control-room');await shot('final-control-room',retain,3000);
}
let ready,after;
try{
 await load();await run(false);await hold(2500);
 await load();await page.evaluate(()=>document.fonts.ready);await hold(2500);
 ready=(Date.now()-start)/1000;mark('retained-take-start');
 await click('音をON',1000);await hold(1800);await run(true);await hold(2000);
 after=await version();assert.deepEqual(errors,[]);
}finally{
 writeFileSync(out+'/evidence.json',JSON.stringify({before,after,ready,events,errors,method:'Actual public door opening/blackout/closing/arrival UI, rehearsed for fonts; clean headed Chromium + dedicated audio sink; no cookies/microphone/state injection'},null,2));
 await context.close();await browser.close();audio.stdin.write('q');await stopped;
}
const raw=await video.path(),final=out+'/echo-pump-door-x.mp4';
execFileSync('ffmpeg',['-y','-ss',String(ready),'-i',raw,'-ss',String(ready),'-i',out+'/browser-audio.wav','-map','0:v:0','-map','1:a:0','-shortest','-c:v','libx264','-preset','medium','-b:v','550k','-pix_fmt','yuv420p','-c:a','aac','-b:a','64k','-movflags','+faststart',final],{stdio:'inherit'});
const probe=JSON.parse(execFileSync('ffprobe',['-v','quiet','-show_format','-show_streams','-of','json',final],{encoding:'utf8'}));
assert(statSync(final).size<5000000);assert(+probe.format.duration>25&&+probe.format.duration<65);
const levels=spawn('ffmpeg',['-hide_banner','-i',final,'-af','volumedetect','-vn','-f','null','-']);let levelText='';levels.stderr.on('data',x=>levelText+=x);await new Promise(r=>levels.on('exit',r));
writeFileSync(out+'/audio-level.txt',levelText);assert(!levelText.includes('mean_volume: -inf'));
execFileSync('ffmpeg',['-y','-i',final,'-vf','fps=5,scale=480:360,tile=5x5','-vsync','vfr',out+'/contact-%02d.jpg'],{stdio:'ignore'});
writeFileSync(out+'/media-check.json',JSON.stringify({raw,final,trim:ready,speed:1,bytes:statSync(final).size,probe},null,2));
