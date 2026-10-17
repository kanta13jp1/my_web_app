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
  for(const [name,viewport] of [['desktop',{width:1440,height:1300}],['mobile',{width:390,height:1000}]]) {
    const context=await browser.newContext({viewport,locale:'ja-JP',reducedMotion:'no-preference',recordVideo:{dir:out,size:viewport}});
    const page=await context.newPage(), video=page.video(), errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(()=>{
      window.__roomAudit={plays:[],media:[]};
      const play=HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play=function(){
        if(!window.__roomAudit.media.includes(this)) window.__roomAudit.media.push(this);
        const result=play.call(this);
        result.then(()=>window.__roomAudit.plays.push(this.currentSrc||this.src),()=>{});return result;
      };
    });
    const button=text=>page.getByRole('button',{name:text,exact:true});
    const steps=()=>page.evaluate(()=>window.__roomAudit.plays.filter(src=>src.includes('/step.wav')).length);
    const shot=stem=>page.screenshot({path:`${out}/${name}-${stem}.png`});
    let passed=false;
    try {
      await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});
      const activate=page.locator('flt-semantics-placeholder');
      await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
      if(await activate.count()) await activate.dispatchEvent('click');
      await button('ゲーム開始').waitFor({timeout:60000});
      await button('音をON').click();
      await page.waitForFunction(()=>window.__roomAudit.plays.some(src=>src.includes('/bgm.wav')));
      await button('ゲーム開始').click();await button('スキップして開始').click();
      await button('保守メモを調べる').waitFor();
      await page.mouse.move(150,250);await page.mouse.wheel(0,-30000);await page.waitForTimeout(300);
      await shot('overview');
      await button('設備寄りに見る').click();await button('全景へ').waitFor();
      await button('保守メモを調べる').click();
      await page.getByText('歩行中…',{exact:true}).waitFor({timeout:5000});
      await page.waitForTimeout(150);await shot('walking');
      await page.getByText('夜間保守メモ 1 / 2',{exact:true}).waitFor();
      await page.waitForFunction(()=>window.__roomAudit.plays.filter(src=>src.includes('/step.wav')).length===2);
      await shot('memo-one');await button('次のページ').click();
      await page.getByText('夜間保守メモ 2 / 2',{exact:true}).waitFor();await shot('memo-two');
      await button('メモを閉じる').click();
      await button('保守メモを調べる').click();await button('メモを閉じる').waitFor();assert.equal(await steps(),2);await button('メモを閉じる').click();
      await button('中央廊下の扉を調べる').click();await button('扉を開けて進む').waitFor();await shot('door');
      await button('戻る').click();assert.equal(await page.getByText('ターン 0',{exact:true}).count(),1);
      await button('中央廊下の扉を調べる').click();await button('扉を開けて進む').click();
      await page.getByText('ターン 1',{exact:true}).waitFor();await button('工具庫へ').waitFor();
      await page.mouse.wheel(0,-30000);await page.waitForTimeout(650);await shot('hall');
      assert.equal(await steps(),5); // two memo contacts + two door contacts + one committed room move
      await button('音をOFF').click();
      await page.waitForFunction(()=>window.__roomAudit.media.every(m=>m.paused||m.ended||!m.getAttribute('src')));
      assert.deepEqual(errors,[]); passed=true;
    } finally {
      reports.push({name,passed,errors,audio:await page.evaluate(()=>window.__roomAudit.plays).catch(()=>[])});
      await shot('final').catch(()=>{});await context.close();if(video) await video.saveAs(`${out}/${name}-flow.webm`);
      writeFileSync(`${out}/report.json`,JSON.stringify({before,expected,reports},null,2));
    }
  }
  assert.equal((await version()).commit,expected);
} finally {await browser.close();}
