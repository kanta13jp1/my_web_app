import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
const origin = 'https://my-web-app-b67f4.web.app';
const expected = process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected ?? '', /^[a-f0-9]{40}$/);
const out = 'echo-public-evidence'; mkdirSync(out, {recursive:true});
const version = async () => { const response=await fetch(`${origin}/version.json`,{cache:'no-store'}); assert(response.ok); const data=await response.json();assert.equal(data.commit,expected);return data; };
const before=await version(), reports=[];
const browser=await chromium.launch({headless:true});
try {
  for(const [name,viewport,delayArt] of [['desktop-normal',{width:1440,height:1300},false],['desktop-delayed',{width:1440,height:1300},true],['mobile-normal',{width:390,height:1000},false],['mobile-delayed',{width:390,height:1000},true]]) {
    const context=await browser.newContext({viewport,locale:'ja-JP',reducedMotion:'no-preference',recordVideo:{dir:`${out}/${name}`,size:viewport}});
    const page=await context.newPage(), video=page.video(), errors=[], consoleCounts={};
    page.on('console',message=>{
      if(!['error','warning'].includes(message.type())) return;
      const text=message.text();
      const category=/known-race|RenderBox/.test(text)?'layout':/font|preload/i.test(text)?'font-or-preload':/permission|unload/i.test(text)?'browser-policy':'other';
      const key=message.type()+':'+category; consoleCounts[key]=(consoleCounts[key]||0)+1;
    });
    page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(()=>{
      window.__roomAudit={plays:[],media:[],contexts:[],gains:[]};
      const createGain=AudioContext.prototype.createGain;
      AudioContext.prototype.createGain=function(){const node=createGain.call(this);if(!window.__roomAudit.contexts.includes(this)) window.__roomAudit.contexts.push(this);window.__roomAudit.gains.push(node);return node;};
      const play=HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play=function(){
        if(!window.__roomAudit.media.includes(this)) window.__roomAudit.media.push(this);
        const result=play.call(this);
        result.then(()=>window.__roomAudit.plays.push(this.currentSrc||this.src),()=>{});return result;
      };
    });
    let releaseArt;
    const artGate=new Promise(resolve=>{releaseArt=resolve;});
    let requestedBeforeWalk=false, walkStarted=false, artStatus=null;
    const request=page.waitForRequest(r=>r.url().endsWith('/character_walk.png'),{timeout:60000});
    const response=page.waitForResponse(r=>r.url().endsWith('/character_walk.png'),{timeout:60000});
    await page.route('**/assets/echo_pump/character_walk.png',async route=>{
      requestedBeforeWalk=!walkStarted;
      if(delayArt) await artGate;
      await route.continue();
    });
    const button=text=>page.getByRole('button',{name:text,exact:true});
    const steps=()=>page.evaluate(()=>window.__roomAudit.plays.filter(src=>src.includes('/step.wav')).length);
    const shot=stem=>page.screenshot({path:`${out}/${name}-${stem}.png`,scale:'css'});
    let passed=false;
    try {
      await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});
      const activate=page.locator('flt-semantics-placeholder');
      await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
      if(await activate.count()) await activate.dispatchEvent('click');
      await button('ゲーム開始').waitFor({timeout:60000});
      await button('音をON').click();
      await page.waitForFunction(()=>window.__roomAudit.plays.some(src=>src.includes('/bgm.wav')));
      await page.waitForFunction(()=>window.__roomAudit.contexts.some(c=>c.state==='running')&&window.__roomAudit.gains.some(g=>g.gain.value>0));
      await button('ゲーム開始').click();await button('スキップして開始').click();
      await button('保守メモを調べる').waitFor();
      await request;assert.equal(requestedBeforeWalk,true);
      if(!delayArt){const art=await response;artStatus=art.status();assert.equal(artStatus,200);await art.finished();}
      await page.mouse.move(150,250);await page.mouse.wheel(0,-30000);await page.waitForTimeout(300);
      await shot('overview');
      await button('設備寄りに見る').click();await button('全景へ').waitFor();
      walkStarted=true;await button('保守メモを調べる').click();
      await page.getByText('歩行中…',{exact:true}).first().waitFor({timeout:5000});
      await shot('first-walking');
      await page.getByText('夜間保守メモ 1 / 2',{exact:true}).waitFor();
      await page.waitForFunction(()=>window.__roomAudit.plays.filter(src=>src.includes('/step.wav')).length===2);
      await shot('memo-one');
      if(delayArt){releaseArt();const art=await response;artStatus=art.status();assert.equal(artStatus,200);await art.finished();}
      await button('次のページ').click();
      await page.getByText('夜間保守メモ 2 / 2',{exact:true}).waitFor();await shot('memo-two');
      await button('メモを閉じる').click();
      await button('保守メモを調べる').click();await button('メモを閉じる').waitFor();assert.equal(await steps(),2);await button('メモを閉じる').click();
      await button('中央廊下の扉を調べる').click();await page.getByText('歩行中…',{exact:true}).first().waitFor();await page.waitForTimeout(300);await shot('door-walking');await button('扉を開けて進む').waitFor();await shot('door');
      await button('戻る').click();await page.getByText('ターン 0',{exact:true}).first().waitFor();
      await button('中央廊下の扉を調べる').click();await button('扉を開けて進む').click();
      await page.getByText('ターン 1',{exact:true}).first().waitFor();await button('工具庫へ').waitFor();
      await page.mouse.wheel(0,-30000);await page.waitForTimeout(650);await shot('hall');
      assert.equal(await steps(),5); // two memo contacts + two door contacts + one committed room move
      await button('音をOFF').click();
      await page.waitForFunction(()=>window.__roomAudit.media.every(m=>m.paused||m.ended||!m.getAttribute('src')));
      assert.deepEqual(errors,[]); passed=true;
    } finally {
      releaseArt();
      reports.push({name,viewport,delayArt,preload:{requestedBeforeWalk,artStatus},passed,errors,consoleCounts,audio:await page.evaluate(()=>window.__roomAudit.plays).catch(()=>[])});
      reports[reports.length-1].playback=await page.evaluate(()=>({contexts:window.__roomAudit.contexts.map(c=>c.state),gains:window.__roomAudit.gains.map(g=>g.gain.value),media:window.__roomAudit.media.map(m=>({src:m.currentSrc||m.src,paused:m.paused,currentTime:m.currentTime,ended:m.ended,muted:m.muted}))})).catch(()=>null);
      await shot('final').catch(()=>{});await context.close();if(video) reports[reports.length-1].video=await video.path();
      writeFileSync(`${out}/report.json`,JSON.stringify({before,expected,reports},null,2));
    }
  }
  assert.equal((await version()).commit,expected);
} finally {await browser.close();}
