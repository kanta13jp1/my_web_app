import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const origin = 'https://my-web-app-b67f4.web.app';
const expected = process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected ?? '', /^[0-9a-f]{40}$/);
const out = 'echo-pump-public';
mkdirSync(out, {recursive:true});
async function version() {
  const response = await fetch(origin+'/version.json?verify='+Date.now(), {cache:'no-store'});
  assert(response.ok);
  const value = await response.json();
  assert.equal(value.commit, expected);
  return value;
}
const before = await version(), reports = [];
const selection=JSON.parse(readFileSync('scripts/echo_pump_release/SOURCE_SELECTION.json','utf8'));
for (const [path,digest] of Object.entries(selection.runtime_sha256).filter(([p])=>p.endsWith('.png'))) {
 const response=await fetch(origin+'/assets/'+path+'?verify='+Date.now());
 assert(response.ok);
 assert.equal(createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex'),digest,path);
}
const browser = await chromium.launch();
try {
  for (const [name,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:1000}]]) {
    for (const missing of [false,true]) {
      const id = name+(missing ? '-fallback' : '-rendered');
      const context = await browser.newContext({viewport,deviceScaleFactor:1,locale:'ja-JP'});
      const page = await context.newPage(), errors = [], states = new Set();
      page.setDefaultTimeout(30000);
      page.on('pageerror', e=>errors.push(e.message));
      await page.route('**/assets/echo_pump/pump_*.png', async route=>{
        const state = route.request().url().match(/pump_(fault|idle|live)\.png/)?.[1];
        if (state) states.add(state);
        if (missing) await route.abort(); else await route.continue();
      });
      const button = text=>page.getByRole(/^[ABC] /.test(text)?'checkbox':'button',{name:text,exact:true});
      const shot = tag=>page.screenshot({path:`${out}/${id}-${tag}.png`,scale:'css'});
      const bottom = async()=>{
        await page.mouse.move(viewport.width/2, viewport.height/2);
        await page.mouse.wheel(0,30000);
        await page.waitForTimeout(1300);
      };
      let stage='opening',passed=false;
      try {
        await page.goto(origin+'/echo-pump',{waitUntil:'domcontentloaded'});
        const activate=page.locator('flt-semantics-placeholder');
        await Promise.race([button('ゲーム開始').waitFor({timeout:60000}),activate.waitFor({state:'attached',timeout:60000})]);
        if (await activate.count()) await activate.dispatchEvent('click');
        await button('ゲーム開始').click();
        await button('スキップして開始').click();
        for (const label of [
          'B 整備','A 搬入','中央廊下へ','工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ',
          'ヒューズで修理','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ',
          '中央廊下へ','ポンプ室へ','隔壁を閉じる','排水ポンプを起動','中央廊下へ','管理室へ','出口へ',
        ]) {
          stage=label;
          await button(label).click();
          if (['ヒューズで修理','排水ポンプを起動'].includes(label)) {
            await bottom();
            const expression=label==='ヒューズで修理'
              ? /設備断面：ヒューズ装着済み、隔壁開放、水位高/
              : /設備断面：ヒューズ装着済み、隔壁閉鎖、水位低下・排水完了/;
            await page.getByRole('img',{name:expression}).waitFor({state:'attached'});
            await shot(label==='ヒューズで修理'?'idle':'live');
          }
        }
        await button('リトライ').waitFor();
        assert.deepEqual([...states].sort(),['fault','idle','live']);
        assert.deepEqual(errors,[]);
        await button('リトライ').click();
        await button('B 整備').waitFor();
        passed=true;
      } finally {
        await shot('final').catch(()=>{});
        writeFileSync(`${out}/${id}-body.txt`,await page.locator('body').innerText().catch(()=>''));
        reports.push({id,viewport,missing,stage,passed,states:[...states],errors});
        writeFileSync(out+'/REPORT.json',JSON.stringify({before,expected,reports},null,2));
        await context.close();
      }
    }
  }
  const after=await version();
  writeFileSync(out+'/REPORT.json',JSON.stringify({before,after,expected,reports},null,2));
  assert(reports.every(r=>r.passed));
} finally { await browser.close(); }
