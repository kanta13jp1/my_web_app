import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
const origin='https://my-web-app-b67f4.web.app', expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[0-9a-f]{40}$/);
const out='echo-door-public';mkdirSync(out,{recursive:true});
async function version(){const r=await fetch(origin+'/version.json?door='+Date.now(),{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version(), reports=[], browser=await chromium.launch({headless:true});
try {
  for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:1000}]]) {
    for(const mode of ['frames','skip','realtime','reduced']) {
      const context=await browser.newContext({viewport,deviceScaleFactor:1,locale:'ja-JP',hasTouch:device==='mobile',isMobile:device==='mobile',reducedMotion:mode==='reduced'?'reduce':'no-preference'});
      const page=await context.newPage(), errors=[], tag=device+'-'+mode;
      let stage='start',passed=false;
      const button=name=>page.getByRole('button',{name,exact:true});
      const shot=name=>page.screenshot({path:`${out}/${tag}-${name}.png`,scale:'css'});
      page.setDefaultTimeout(30000);page.on('pageerror',e=>errors.push(e.message));
      const controlled=['frames','skip'].includes(mode);
      try {
        if(controlled)await page.clock.install({time:new Date('2026-10-19T00:00:00Z')});
        await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
        const activate=page.locator('flt-semantics-placeholder');
        await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
        if(await activate.count())await activate.dispatchEvent('click');
        await button('ゲーム開始').click();await button('スキップして開始').click();
        await button('中央廊下へ').waitFor({state:'visible'});
        if(controlled)await page.clock.pauseAt(new Date('2026-10-19T00:10:00Z'));
        stage='move';await button('中央廊下へ').click();
        const skip=button('演出をスキップ');
        if(mode==='frames') {
          await page.clock.runFor(160);await skip.waitFor({state:'visible'});await shot('opening');
          await page.clock.runFor(640);await shot('blackout');
          await page.clock.runFor(450);await shot('closing');
          await page.clock.runFor(1000);
        } else if(mode==='skip') {
          await page.clock.runFor(200);await skip.waitFor({state:'visible'});
          await shot('before-skip');const box=await skip.boundingBox();assert(box);assert(box.y+box.height<=viewport.height);
          const x=box.x+box.width/2,y=box.y+box.height/2;
          if(device==='mobile')await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);
          await page.clock.runFor(400);
        } else if(mode==='realtime') {
          await skip.waitFor({state:'visible'});
          await skip.waitFor({state:'detached'});
        } else {
          await page.waitForTimeout(400);assert.equal(await skip.count(),0);
        }
        stage='arrival';assert.equal(await skip.count(),0);
        await page.getByText('ターン 1',{exact:true}).first().waitFor({state:'attached'});
        assert(await button('工具庫へ').isEnabled());
        await shot('arrived');assert.deepEqual(errors,[]);passed=true;
      } finally {
        if(!passed)await shot('failure').catch(()=>{});
        writeFileSync(`${out}/${tag}-accessibility.txt`,await page.locator('body').ariaSnapshot().catch(()=>''));
        reports.push({device,viewport,mode,controlledClock:controlled,stage,passed,turn:passed?1:null,errors});
        writeFileSync(out+'/REPORT.json',JSON.stringify({before,expected,reports},null,2));await context.close();
      }
    }
  }
  const after=await version();writeFileSync(out+'/REPORT.json',JSON.stringify({before,after,expected,reports},null,2));assert(reports.every(r=>r.passed));
} finally {await browser.close();}
