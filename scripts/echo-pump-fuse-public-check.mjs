import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
const origin='https://my-web-app-b67f4.web.app',expected=process.env.EXPECTED_PRODUCTION_SHA;
const pngHash='f7fb7fe7c84630824cbb026ccd536e78f8c8259b2879f342d57461e4c5b9ba71';
assert.match(expected??'',/^[0-9a-f]{40}$/);
const out='echo-fuse-public';mkdirSync(out,{recursive:true});
const version=async()=>{const r=await fetch(origin+'/version.json?verify='+Date.now(),{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;};
const before=await version(),reports=[];const browser=await chromium.launch({headless:true});
try{
 for(const [name,viewport] of [['desktop',{width:1440,height:1300}],['mobile',{width:390,height:1000}]]){
  const context=await browser.newContext({viewport,locale:'ja-JP',recordVideo:{dir:out+'/'+name,size:viewport}});
  const page=await context.newPage(),errors=[];let stage='opening',passed=false;
  page.setDefaultTimeout(30000);page.on('pageerror',e=>errors.push(e.message));
  const button=n=>page.getByRole('button',{name:n,exact:true});
  const inventory=()=>page.getByRole('button',{name:/^所持品：/});
  const text=n=>page.getByText(n,{exact:true}).first();
  const shot=n=>page.screenshot({path:`${out}/${name}-${n}.png`,scale:'css'});
  const observed={};
  try{
   await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
   const activate=page.locator('flt-semantics-placeholder');
   await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
   if(await activate.count())await activate.dispatchEvent('click');
   await button('ゲーム開始').waitFor({timeout:60000});
   await button('ゲーム開始').click();await button('スキップして開始').click();
   stage='empty inventory';await inventory().click();await text('所持品は空').waitFor();await shot('empty');
   await button('所持品を閉じる').click();await text('ターン 0').waitFor();
   stage='power and workshop';await page.getByRole('checkbox',{name:'B 整備',exact:true}).click();await page.getByRole('checkbox',{name:'A 搬入',exact:true}).click();
   await button('中央廊下へ').click();
   const image=page.waitForResponse(r=>r.url().split('?')[0].endsWith('/assets/echo_pump/fuse_blender.png')&&r.status()===200);
   await button('工具庫へ').click();const response=await image;
   observed.png={url:response.url(),sha256:createHash('sha256').update(await response.body()).digest('hex')};assert.equal(observed.png.sha256,pngHash);
   await page.mouse.move(150,250);await page.mouse.wheel(0,30000);await page.waitForTimeout(400);await shot('fuse-shelf');
   stage='collect';await button('ヒューズを回収').click();assert.equal(await button('ヒューズを回収').isEnabled(),false);
   await inventory().click();await text('所持数 1').waitFor();assert.equal(await button('このヒューズで修理').count(),0);await shot('inventory-carried');
   await button('所持品を閉じる').click();await text('ターン 5').waitFor();observed.collected={quantity:1,turn:5};
   stage='install';await button('中央廊下へ').click();await button('ポンプ室へ').click();await inventory().click();await text('所持数 1').waitFor();await shot('inventory-use');
   await button('このヒューズで修理').click();await text('ターン 8').waitFor();
   await inventory().click();await text('ポンプへ装着済み').waitFor();await text('所持数 0').waitFor();assert.equal(await button('このヒューズで修理').count(),0);await shot('inventory-installed');
   await button('所持品を閉じる').click();await text('ターン 8').waitFor();observed.installed={quantity:0,turn:8};assert.deepEqual(errors,[]);passed=true;
  }finally{
   await shot('final').catch(()=>{});writeFileSync(`${out}/${name}-accessibility.txt`,await page.locator('body').ariaSnapshot().catch(()=>''));
   await context.close();reports.push({name,viewport,stage,passed,observed,errors});writeFileSync(out+'/REPORT.json',JSON.stringify({before,expected,reports},null,2));
  }
 }
 const after=await version();writeFileSync(out+'/REPORT.json',JSON.stringify({before,after,expected,reports},null,2));assert(reports.every(r=>r.passed));
}finally{await browser.close();}
