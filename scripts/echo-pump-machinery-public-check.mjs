import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
const origin='https://my-web-app-b67f4.web.app',expected=process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected??'',/^[0-9a-f]{40}$/);
const out='echo-machinery-public';mkdirSync(out,{recursive:true});
async function version(){const r=await fetch(origin+'/version.json?verify='+Date.now(),{cache:'no-store'});assert(r.ok);const v=await r.json();assert.equal(v.commit,expected);return v;}
const before=await version(),reports=[];const browser=await chromium.launch({headless:true});
try{
 for(const [name,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:1000}]]){
  const context=await browser.newContext({viewport,deviceScaleFactor:1,locale:'ja-JP'});
  const page=await context.newPage(),errors=[];let stage='opening',passed=false;const observed=[];
  page.setDefaultTimeout(30000);page.on('pageerror',e=>errors.push(e.message));
  const button=n=>page.getByRole(/^[ABC] /.test(n)?'checkbox':'button',{name:n,exact:true});
  const shot=n=>page.screenshot({path:`${out}/${name}-${n}.png`,scale:'css'});
  const bottom=async()=>{await page.mouse.move(viewport.width/2,viewport.height/2);await page.mouse.wheel(0,30000);await page.waitForTimeout(300);};
  async function transition(action,label,turn,tag){
   stage=tag;await bottom();await button(action).click();
   await page.getByRole('img',{name:label}).waitFor({state:'attached'});
   await page.waitForTimeout(100);await shot(tag+'-transition');
   await page.waitForTimeout(1200);await shot(tag+'-complete');
   await page.getByText('ターン '+turn,{exact:true}).first().waitFor({state:'attached'});
   observed.push({stage:tag,turn,semanticState:await page.getByRole('img',{name:label}).getAttribute('aria-label')});
  }
  try{
   await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
   const activate=page.locator('flt-semantics-placeholder');
   await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
   if(await activate.count())await activate.dispatchEvent('click');
   await button('ゲーム開始').click();await button('スキップして開始').click();
   stage='collect and enter';
   for(const name of ['B 整備','A 搬入','中央廊下へ','工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ'])await button(name).click();
   await page.getByRole('img',{name:/設備断面：ヒューズ未装着、隔壁開放、水位高/}).waitFor({state:'attached'});await bottom();await shot('before-repair');
   await transition('ヒューズで修理',/設備断面：ヒューズ装着済み、隔壁開放、水位高/,8,'repair');
   for(const name of ['中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ'])await button(name).click();
   await transition('隔壁を閉じる',/設備断面：ヒューズ装着済み、隔壁閉鎖、水位高/,17,'seal');
   await transition('排水ポンプを起動',/設備断面：ヒューズ装着済み、隔壁閉鎖、水位低下・排水完了/,18,'drain');
   assert.equal(await button('排水ポンプを起動').isEnabled(),false);
   for(const name of ['中央廊下へ','管理室へ','出口へ'])await button(name).click();
   await page.getByText('脱出成功',{exact:true}).waitFor();
   assert.deepEqual(errors,[]);passed=true;
  }finally{
   await shot('final').catch(()=>{});writeFileSync(`${out}/${name}-accessibility.txt`,await page.locator('body').ariaSnapshot().catch(()=>''));
   await context.close();reports.push({name,viewport,stage,passed,observed,errors});writeFileSync(out+'/REPORT.json',JSON.stringify({before,expected,reports},null,2));
  }
 }
 const after=await version();writeFileSync(out+'/REPORT.json',JSON.stringify({before,after,expected,reports},null,2));assert(reports.every(r=>r.passed));
}finally{await browser.close();}
