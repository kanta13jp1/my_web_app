import { chromium } from 'playwright';
import { spawn, execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const url = 'https://my-web-app-b67f4.web.app/labs/sound-bloom/index.html';
const expected = 'b6af1e62f642b474c767c5b4586348837f4e7f5d';
const out = 'sound-bloom-recording';
mkdirSync(out, {recursive:true});
const version = await (await fetch(new URL('/version.json', url))).json();
assert.equal(version.commit, expected, 'Production changed; review before recording');
const browser = await chromium.launch({headless:false, args:['--window-size=1440,1080', '--window-position=0,0','--disable-features=Translate,TranslateUI'], ignoreDefaultArgs:['--mute-audio']});
let recorder;
const events=[];
const started=Date.now();
const mark = (action)=>events.push({seconds:(Date.now()-started)/1000,action});
const wait = ms=>new Promise(r=>setTimeout(r,ms));
try {
  const page=await browser.newPage({viewport:{width:1440,height:1080},deviceScaleFactor:1,locale:'ja-JP'});
  const errors=[]; page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url,{waitUntil:'networkidle'});
  await page.getByRole('button',{name:'▶ 音を咲かせる'}).waitFor();
  // Scroll the real page to fit the garden and primary controls; no DOM/style edits.
  await page.keyboard.press('F11');
  await wait(1000);
  await page.locator('.garden').evaluate(el=>el.scrollIntoView({block:'start'}));
  await wait(1200);
  await page.screenshot({path:`${out}/before.png`});
  recorder=spawn('ffmpeg',['-y','-f','x11grab','-framerate','30','-video_size','1440x1080','-i',process.env.DISPLAY,
    '-f','pulse','-i','bloom.monitor','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p',
    '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',`${out}/sound-bloom-production.mp4`],
    {stdio:['pipe','ignore','inherit']});
  const recordingFinished = new Promise((resolve,reject)=>recorder.once('exit',code=>code===0?resolve():reject(new Error(`ffmpeg ${code}`))));
  await wait(3000); mark('recording-start');
  await page.getByRole('button',{name:'▶ 音を咲かせる'}).click(); mark('play-dew');
  await wait(6000);
  await page.getByRole('button',{name:'雫 2番目の音',exact:true}).click(); mark('add-dew-2');
  await wait(5000);
  await page.getByRole('button',{name:'光 5番目の音',exact:true}).click(); mark('add-light-5');
  await wait(5000);
  await page.getByRole('button',{name:'02 木漏れ日',exact:true}).click(); mark('sunlight');
  await wait(8000);
  await page.screenshot({path:`${out}/playing.png`});
  await page.getByRole('button',{name:'03 夜光',exact:true}).click(); mark('night');
  await wait(8000);
  await page.getByRole('button',{name:'■ 演奏を止める'}).click(); mark('stop');
  await wait(1500);
  recorder.stdin.write('q'); await recordingFinished; recorder=null;
  assert.deepEqual(errors,[]);
  writeFileSync(`${out}/recording-proof.json`,JSON.stringify({url,version,events,errors,method:'Real headed Chromium production UI; Xvfb screen and PulseAudio sink captured together; no generated frames, speed changes, DOM edits, login or microphone'},null,2));
} finally {
  if(recorder) recorder.kill('SIGINT');
  await browser.close();
}
const video=`${out}/sound-bloom-production.mp4`;
const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_streams','-show_format','-of','json',video]));
assert(probe.streams.some(s=>s.codec_name==='h264'&&s.width===1440&&s.height===1080));
assert(probe.streams.some(s=>s.codec_name==='aac'));
assert(Number(probe.format.duration)>30 && Number(probe.format.duration)<65);
writeFileSync(`${out}/ffprobe.json`,JSON.stringify(probe,null,2));
for(const second of [3,10,20,30]) execFileSync('ffmpeg',['-y','-ss',String(second),'-i',video,'-frames:v','1',`${out}/frame-${second}.jpg`]);
execFileSync('ffmpeg',['-y','-i',video,'-vn','-ac','1','-ar','16000',`${out}/review-audio.wav`]);
