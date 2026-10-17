import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
const origin='https://my-web-app-b67f4.web.app', expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[a-f0-9]{40}$/);
const out='echo-public-evidence';mkdirSync(out,{recursive:true});
const version=async()=>{const r=await fetch(`${origin}/version.json`,{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;};
const before=await version(),reports=[];
const browser=await chromium.launch({headless:true});
try {
 for(const [name,viewport] of [['desktop',{width:1440,height:1300}],['mobile',{width:390,height:1000}]]) {
  const context=await browser.newContext({viewport,locale:'ja-JP',reducedMotion:'no-preference',recordVideo:{dir:`${out}/${name}`,size:viewport}});
  const page=await context.newPage(),video=page.video(),errors=[],consoleCounts={};
  page.setDefaultTimeout(30000);
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(!['warning','error'].includes(m.type()))return;const t=m.text(),cat=/known-race|RenderBox/.test(t)?'layout':/font|preload/i.test(t)?'font-or-preload':/permission|unload/i.test(t)?'browser-policy':'other';const key=m.type()+':'+cat;consoleCounts[key]=(consoleCounts[key]||0)+1;});
  await page.addInitScript(()=>{
   window.__roomAudit={plays:[],requests:[],media:[],contexts:[],gains:[]};
   const gain=AudioContext.prototype.createGain;
   AudioContext.prototype.createGain=function(){const n=gain.call(this);if(!window.__roomAudit.contexts.includes(this))window.__roomAudit.contexts.push(this);window.__roomAudit.gains.push(n);return n;};
   const play=HTMLMediaElement.prototype.play;
   HTMLMediaElement.prototype.play=function(){if(!window.__roomAudit.media.includes(this))window.__roomAudit.media.push(this);const calledAt=performance.now(),src=this.currentSrc||this.src;window.__roomAudit.requests.push({src,calledAt});const r=play.call(this);r.then(()=>window.__roomAudit.plays.push({src:this.currentSrc||this.src,time:performance.now(),calledAt}),()=>{});return r;};
  });
  const button=n=>page.getByRole('button',{name:n,exact:true});
  const inventory=()=>page.getByRole('button',{name:/^所持品：/});
  const text=n=>page.getByText(n,{exact:true}).first();
  const steps=()=>page.evaluate(()=>window.__roomAudit.plays.filter(x=>x.src.includes('/step.wav')).length);
  const cueCount=cue=>page.evaluate(c=>window.__roomAudit.plays.filter(x=>x.src.includes('/'+c+'.wav')).length,cue);
  const shot=n=>page.screenshot({path:`${out}/${name}-${n}.png`,scale:'css'});
  const top=async()=>{await page.mouse.move(150,250);await page.mouse.wheel(0,-30000);await page.waitForTimeout(250);};
  const bottom=async()=>{await page.mouse.move(150,250);await page.mouse.wheel(0,30000);await page.waitForTimeout(250);};
  const observed={};let passed=false;
  try {
   await page.goto(`${origin}/echo-pump`,{waitUntil:'domcontentloaded'});
   const activate=page.locator('flt-semantics-placeholder');
   await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
   if(await activate.count())await activate.dispatchEvent('click');
   await button('ゲーム開始').waitFor({timeout:60000});
   await button('音をON').click();
   await page.waitForFunction(()=>window.__roomAudit.plays.some(x=>x.src.includes('/bgm.wav')));
   await page.waitForFunction(()=>window.__roomAudit.contexts.some(c=>c.state==='running')&&window.__roomAudit.gains.some(g=>g.gain.value>0));
   await button('ゲーム開始').click();await button('スキップして開始').click();
   await button('保守メモを調べる').waitFor();await top();
   writeFileSync(`${out}/${name}-accessibility-before.txt`,await page.locator('body').ariaSnapshot());
   await inventory().waitFor();await inventory().click();await text('所持品は空').waitFor();await button('所持品を閉じる').click();await text('ターン 0').waitFor();
   const stepBefore=await steps();
   await button('保守メモを調べる').click();
   await text('歩行中…').waitFor();
   observed.walkingBeforeMenu=true;
   await button('所持品を開く').dispatchEvent('click');await text('所持品は空').waitFor();
   assert.equal(await text('歩行中…').count(),0);assert.equal(await text('夜間保守メモ 1 / 2').count(),0);
   const openedAt=await page.evaluate(()=>performance.now());
   const initialResolved=await steps();
   await page.waitForTimeout(400); // allow a play request already issued before the modal to settle
   const stopped=await steps();await shot('inventory-stops-walking');
   await page.waitForTimeout(1800);
   const afterWait=await steps();
   assert.equal(await text('夜間保守メモ 1 / 2').count(),0);
   const audibleSteps=await page.evaluate(()=>window.__roomAudit.media.filter(m=>(m.currentSrc||m.src).includes('/step.wav')&&!m.paused&&!m.ended).length);
   const lateRequests=await page.evaluate(t=>window.__roomAudit.requests.filter(x=>x.src.includes('/step.wav')&&x.calledAt>=t),openedAt);
   const bgmPlaying=await page.evaluate(()=>window.__roomAudit.media.some(m=>(m.currentSrc||m.src).includes('/bgm.wav')&&!m.paused&&!m.ended));
   observed.menu={stepBefore,initialResolved,stopped,afterWait,waitMs:1800,openedAt,audibleSteps,lateRequests,bgmPlaying,passed:afterWait===stopped&&audibleSteps===0&&lateRequests.length===0&&bgmPlaying};
   await shot('inventory-still-stopped');
   await button('所持品を閉じる').click();await text('ターン 0').waitFor();
   await button('保守メモを調べる').click();await text('夜間保守メモ 1 / 2').waitFor();
   assert((await steps())>stopped);await button('メモを閉じる').click();
   observed.resumedSteps=await steps();
   await inventory().click();await text('所持数 0').waitFor();await button('所持品を閉じる').click();await text('ターン 0').waitFor();
   await page.getByRole('checkbox',{name:'B 整備',exact:true}).click();
   await page.getByRole('checkbox',{name:'A 搬入',exact:true}).click();
   await button('中央廊下へ').click();await button('工具庫へ').click();
   await bottom();await shot('fuse-shelf');
   const collectBefore=await cueCount('collect');await button('ヒューズを回収').click();
   assert.equal(await button('ヒューズを回収').isEnabled(),false);
   await inventory().click();await text('所持数 1').waitFor();
   assert.equal(await button('このヒューズで修理').count(),0);
   await shot('inventory-carried');await button('所持品を閉じる').click();await text('ターン 5').waitFor();
   observed.collected={quantity:1,turn:5,cueBefore:collectBefore,cueAfter:await cueCount('collect')};
   assert(observed.collected.cueAfter>collectBefore);
   await button('中央廊下へ').click();await button('ポンプ室へ').click();
   await inventory().click();await text('所持数 1').waitFor();await shot('inventory-use');
   const repairBefore=await cueCount('repair');await button('このヒューズで修理').click();await text('ターン 8').waitFor();
   await inventory().click();await text('ポンプへ装着済み').waitFor();await text('所持数 0').waitFor();
   assert.equal(await button('このヒューズで修理').count(),0);await shot('inventory-installed');
   await button('所持品を閉じる').click();await text('ターン 8').waitFor();
   observed.installed={quantity:0,turn:8,cueBefore:repairBefore,cueAfter:await cueCount('repair')};assert(observed.installed.cueAfter>repairBefore);
   await bottom();await button('音をOFF').click();
   await page.waitForFunction(()=>window.__roomAudit.media.every(m=>m.paused||m.ended||!m.getAttribute('src')));
   assert.deepEqual(errors,[]);passed=observed.menu.passed;
  } finally {
   writeFileSync(`${out}/${name}-accessibility-final.txt`,await page.locator('body').ariaSnapshot().catch(()=>''));
   const audio=await page.evaluate(()=>({plays:window.__roomAudit.plays,requests:window.__roomAudit.requests,contexts:window.__roomAudit.contexts.map(c=>c.state),gains:window.__roomAudit.gains.map(g=>g.gain.value),media:window.__roomAudit.media.map(m=>({src:m.currentSrc||m.src,paused:m.paused,currentTime:m.currentTime,ended:m.ended}))})).catch(()=>null);
   await shot('final').catch(()=>{});await context.close();reports.push({name,viewport,passed,observed,errors,consoleCounts,audio,video:video?await video.path():null});
   writeFileSync(`${out}/report.json`,JSON.stringify({before,expected,reports},null,2));
  }
 }
 const after=await version();writeFileSync(`${out}/report.json`,JSON.stringify({before,after,expected,reports},null,2));assert(reports.every(r=>r.passed),'All public acceptance criteria must pass');
} finally {await browser.close();}
