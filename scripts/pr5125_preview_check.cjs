const { chromium } = require('@playwright/test');
const fs = require('fs');
const assert = require('node:assert/strict');

(async () => {
  fs.mkdirSync('preview-evidence', { recursive: true });
  const browser = await chromium.launch();
  const screens = ['note-list','note-editor','import','note-collections','note-tags','note-navigation','note-tasks','space-sharing'];
  const labels = {'note-list':'架空データ：秋の読書メモ','note-editor':'メモを編集',import:'データ取込','note-collections':'ノートブック・スタック・共有スペース','note-tags':'階層タグ','note-navigation':'保存済み検索・ショートカット','note-tasks':'ノートタスク','space-sharing':'スペースの共有'};
  const oldCopy=Object.keys(JSON.parse(fs.readFileSync('config/pr5125-ja-copy.json','utf8'))).filter(s=>!s.includes('$') && /^[A-Za-z]/.test(s) && s.length>3);
  const report = [];
  try {
    for (const [device, viewport] of Object.entries({pc:{width:1440,height:1000},mobile:{width:390,height:844}})) {
      const context = await browser.newContext({viewport, deviceScaleFactor:1, isMobile:device==='mobile', hasTouch:device==='mobile'});
      const page = await context.newPage();
      const errors = [];
      const external = [];
      const consoleMessages = [];
      page.on('console',m=>consoleMessages.push(m.text()));
      page.on('pageerror', e => errors.push(String(e)));
      page.on('request', r => {if(!r.url().startsWith('http://localhost:8080/') && !r.url().startsWith('data:') && !r.url().startsWith('blob:')) external.push(r.url());});
      for(const screen of screens) {
        const start = errors.length;
        await page.goto('http://localhost:8080/?screen='+screen, {waitUntil:'networkidle'});
        await page.locator('flutter-view').waitFor({timeout:120000});
        await page.waitForTimeout(4000);
        const placeholder=page.locator('flt-semantics-placeholder');
        if(await placeholder.count()) await placeholder.evaluate(e=>e.click());
        await page.waitForTimeout(700);
        assert.equal(await page.locator('#screen').inputValue(),screen);
        const semantics=(await page.locator('[aria-label], input, textarea').evaluateAll(nodes=>nodes.map(e=>(e.getAttribute('aria-label')||'')+' '+(e.value||'')).join(' ')))+' '+(await page.locator('flt-semantics').allTextContents()).join(' ');
        await page.screenshot({path:`preview-evidence/${device}-${screen}.png`,fullPage:true});
        fs.writeFileSync(`preview-evidence/${device}-${screen}.json`,JSON.stringify({semantics,errors,external,consoleMessages},null,2));
        assert((await page.locator('nav').innerText()).includes('架空データ・DB接続なし'), 'Missing offline header');
        assert(semantics.includes(labels[screen]), 'Missing actual screen content: '+device+'/'+screen+' '+semantics.slice(0,1000));
        const untranslated=oldCopy.filter(copy=>semantics.includes(copy));
        assert.deepEqual(untranslated,[], 'Untranslated English interface copy: '+device+'/'+screen);
        if(screen==='import') {
          assert(semantics.includes('Notion・Evernoteからノートを移す'));
          assert(semantics.includes('Evernoteの移行台帳'));
        }
        assert(!/Assertion failed|ProviderNotFoundException|Supabase has not been initialized|ErrorWidget/.test(semantics), 'Broken screen: '+device+'/'+screen);
        await page.screenshot({path:`preview-evidence/${device}-${screen}.png`,fullPage:true});
        assert.equal(errors.length,start, 'Browser error: '+errors.slice(start).join('\n'));
        assert.equal(external.length,0,'External request attempted: '+external.join(','));
        const blocked=await page.evaluate(async()=>{try{await fetch('https://pr5125.invalid/rest/v1/notes');return false;}catch(_){return true;}});
        assert(blocked,'Off-origin browser guard failed');
        assert.equal(external.length,0,'Guard leaked an external request');
        report.push({device,screen,semantics:semantics.slice(0,6000),externalRequests:0});
      }
      await context.close();
    }
  } finally {
    fs.writeFileSync('preview-evidence/report.json',JSON.stringify(report,null,2));
    await browser.close();
  }
  console.log('PASS: 8 actual Flutter screens x PC/mobile; zero external network requests');
})().catch(e=>{console.error(e);process.exit(1);});
