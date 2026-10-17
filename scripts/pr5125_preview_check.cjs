const { chromium } = require('@playwright/test');
const fs = require('fs');
const assert = require('node:assert/strict');

(async () => {
  fs.mkdirSync('preview-evidence', { recursive: true });
  const browser = await chromium.launch();
  const screens = ['note-list','note-editor','import','note-collections','note-tags','note-navigation','note-tasks','space-sharing'];
  const report = [];
  try {
    for (const [device, viewport] of Object.entries({pc:{width:1440,height:1000},mobile:{width:390,height:844}})) {
      const context = await browser.newContext({viewport, deviceScaleFactor:1, isMobile:device==='mobile', hasTouch:device==='mobile'});
      const page = await context.newPage();
      const errors = [];
      const external = [];
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
        const semantics=await page.locator('flt-semantics-host').evaluateAll(hosts=>hosts.map(h=>h.innerText+' '+Array.from(h.querySelectorAll('[aria-label]')).map(e=>e.getAttribute('aria-label')).join(' ')).join(' '));
        assert(semantics.includes('架空データ'), 'Missing offline banner: '+device+'/'+screen);
        assert(!/Assertion failed|ProviderNotFoundException|Supabase has not been initialized|ErrorWidget/.test(semantics), 'Broken screen: '+device+'/'+screen);
        await page.screenshot({path:`preview-evidence/${device}-${screen}.png`,fullPage:true});
        assert.equal(errors.length,start, 'Browser error: '+errors.slice(start).join('\n'));
        assert.equal(external.length,0,'External request attempted: '+external.join(','));
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
