import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync,writeFileSync } from 'node:fs';
const origin='https://my-web-app-b67f4.web.app',expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[0-9a-f]{40}$/);
const out='echo-improvements-public';mkdirSync(out,{recursive:true});
async function version(){const r=await fetch(origin+'/version.json?qa5874='+Date.now(),{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version(),reports=[],browser=await chromium.launch({headless:true});
try {
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:1000}]]) {
  for(const mode of ['live','skip']) {
   const context=await browser.newContext({viewport,deviceScaleFactor:1,locale:'ja-JP',hasTouch:device==='mobile',isMobile:device==='mobile',reducedMotion:'no-preference'});
   const page=await context.newPage(),errors=[],tag=device+'-'+mode;
   let stage='start',passed=false;const observations={};
   const b=name=>page.getByRole(/^[ABC] /.test(name)?'checkbox':'button',{name,exact:true});
   const shot=name=>page.screenshot({path:`${out}/${tag}-${name}.png`,scale:'css'});
   const waitText=name=>page.getByText(name,{exact:true}).first().waitFor({state:'attached'});
   const audio=()=>page.evaluate(()=>window.__audio.plays);
   const count=async name=>(await audio()).filter(x=>x.endsWith('/'+name+'.wav')).length;
   async function quiet(){await b('演出をスキップ').waitFor({state:'detached'});}
   async function act(...names){for(const name of names){stage=name;await b(name).click();if(name.endsWith('へ'))await b('演出をスキップ').waitFor({state:'visible'});await quiet();}}
   page.setDefaultTimeout(30000);page.on('pageerror',e=>errors.push(e.message));
   try {
    await page.addInitScript(()=>{
     const audit={plays:[],media:[]};window.__audio=audit;const play=HTMLMediaElement.prototype.play;
     HTMLMediaElement.prototype.play=function(){const src=this.currentSrc||this.src;if(!audit.media.includes(this))audit.media.push(this);const r=play.call(this);r.then(()=>audit.plays.push(src),()=>{});return r;};
    });
    if(mode==='skip')await page.clock.install({time:new Date('2026-10-19T00:00:00Z')});
    await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
    const activate=page.locator('flt-semantics-placeholder');
    await Promise.race([b('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
    if(await activate.count())await activate.dispatchEvent('click');
    if(mode==='live')await b('音をON').click();
    await b('ゲーム開始').click();await b('スキップして開始').click();
    await b('中央廊下へ').waitFor({state:'visible'});
    if(mode==='skip'){
     stage='early skip';await page.clock.pauseAt(new Date('2026-10-19T00:10:00Z'));
     await b('中央廊下へ').click();await page.clock.runFor(200);
     await b('演出をスキップ').waitFor({state:'visible'});await shot('opening');
     await b('演出をスキップ').click();await page.clock.runFor(400);await quiet();
     await waitText('ターン 1');assert(await b('工具庫へ').isEnabled());
     await page.clock.runFor(2200);await waitText('ターン 1');await shot('arrived');
     observations.turn=1;observations.noRepeatedMove=true;
    }else{
     stage='walk to memo';await page.mouse.move(100,200);await page.mouse.wheel(0,-30000);await page.waitForTimeout(400);
     await b('設備寄りに見る').click();
     await b('保守メモを調べる').click();await waitText('夜間保守メモ 1 / 2');
     assert.equal(await count('step'),2);observations.memoSteps=2;
     const memoPlays=(await audio()).length;await page.waitForTimeout(700);assert.equal((await audio()).length,memoPlays);
     await shot('memo-stopped');await b('メモを閉じる').click();
     stage='long walk';const stepsBefore=await count('step');
     await b('中央廊下の扉を調べる').click();
     await waitText('歩行中…');await shot('walking');
     await b('扉を開けて進む').waitFor({state:'visible'});
     observations.longWalkSteps=(await count('step'))-stepsBefore;assert(observations.longWalkSteps>=3);
     await shot('walk-stopped');await b('扉を開けて進む').click();await b('演出をスキップ').waitFor({state:'visible'});await quiet();await waitText('ターン 1');
     assert((await count('doorOpen'))>=1);assert((await count('doorClose'))>=1);await shot('door-arrived');
     stage='mute';await b('音をOFF').click();
     await page.waitForFunction(()=>window.__audio.media.every(m=>m.paused||m.ended||!m.getAttribute('src')));
     const muted=(await audio()).length;await act('管理室へ');await page.waitForTimeout(400);assert.equal((await audio()).length,muted);observations.mute=true;
     await b('音をON').click();
     const rooms={control:'配電盤と計器の管理室',hall:'奥へ続く扉と配管の中央廊下',loading:'木箱と搬入口の搬入区画',workshop:'工具壁と作業台の工具庫',pump:'大型配管と排水機のポンプ室',inspection:'水路と格子床の点検槽',exit:'雨と外光が差す出口'};
     observations.rooms=[];
     async function capture(room){stage='room '+room;await page.getByRole('img',{name:'部屋の背景：'+rooms[room],exact:true}).waitFor({state:'attached'});await page.mouse.move(100,200);await page.mouse.wheel(0,-30000);await page.waitForTimeout(250);await shot('room-'+room);observations.rooms.push(room);}
     await capture('control');await act('中央廊下へ');await capture('hall');await act('搬入区画へ');await capture('loading');
     await act('中央廊下へ','管理室へ','B 整備','A 搬入','中央廊下へ','工具庫へ');await capture('workshop');
     await act('ヒューズを回収','中央廊下へ','ポンプ室へ');await capture('pump');await act('点検槽へ');await capture('inspection');
     await act('ポンプ室へ','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ','隔壁を閉じる','ヒューズで修理','排水ポンプを起動','中央廊下へ','管理室へ','出口へ');
     await capture('exit');await waitText('脱出成功');await waitText('ターン 29');observations.turn=29;
    }
    observations.audio=await audio();observations.media=await page.evaluate(()=>window.__audio.media.map(m=>({src:m.currentSrc||m.src,paused:m.paused,ended:m.ended,loop:m.loop})));
    assert.deepEqual(errors,[]);passed=true;
   }finally{
    if(!passed)await shot('failure').catch(()=>{});
    writeFileSync(`${out}/${tag}-accessibility.txt`,await page.locator('body').ariaSnapshot().catch(()=>''));
    reports.push({device,viewport,mode,stage,passed,errors,observations});writeFileSync(out+'/REPORT.json',JSON.stringify({before,expected,reports},null,2));await context.close();
   }
  }
 }
 const after=await version();writeFileSync(out+'/REPORT.json',JSON.stringify({before,after,expected,reports},null,2));assert(reports.every(r=>r.passed));
}finally{await browser.close();}
