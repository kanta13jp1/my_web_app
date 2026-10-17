import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

await mkdir('.ci-logs/flow-input', { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROME_BIN || '/usr/bin/google-chrome', headless: true });
const evidence = [];
try {
  for (const method of ['fillOnly', 'domSameTask', 'domAfterFocus', 'fill', 'settledFill', 'insertText', 'type']) {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1200 } });
    await context.route('**/*', async route => {
      const url = new URL(route.request().url());
      if (url.hostname === '127.0.0.1' && url.port === '8080') return route.continue();
      return route.abort('blockedbyclient');
    });
    const page = await context.newPage();
    const row = { method, events: [], errors: [], snapshots: [] };
    evidence.push(row);
    page.on('pageerror', e => row.errors.push(String(e)));
    await page.addInitScript(() => {
      window.__inputEvents = [];
      for (const kind of ['focus', 'blur', 'beforeinput', 'input', 'change']) {
        document.addEventListener(kind, event => {
          const target = event.target;
          window.__inputEvents.push({type: event.type, tag: target.tagName, role: target.getAttribute?.('role'), aria: target.getAttribute?.('aria-label'), value: target.value, trusted: event.isTrusted, inputType: event.inputType});
        }, true);
      }
    });
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.__flowProbeState && JSON.parse(window.__flowProbeState).fields['内容'] === '', null, { timeout: 90000 });
    await page.waitForTimeout(1800);
    const memo = page.getByRole('textbox', {name:'内容', exact:true});
    const amount = page.getByRole('textbox', {name:'金額 (円)', exact:true});
    async function snapshot(stage) {
      await page.waitForTimeout(350);
      row.snapshots.push({stage, controller: await page.evaluate(() => JSON.parse(window.__flowProbeState)), dom: await page.locator('input,textarea').evaluateAll(nodes => nodes.map(x => ({tag:x.tagName, role:x.getAttribute('role'), aria:x.getAttribute('aria-label'), value:x.value, active:x === document.activeElement}))) });
    }
    async function enter(locator, text) {
      if (method === 'fillOnly') return locator.fill(text);
      if (method === 'domAfterFocus') { await locator.focus(); await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))); }
      if (method === 'domSameTask' || method === 'domAfterFocus') return locator.evaluate((element, text) => { element.focus(); element.value = text; element.dispatchEvent(new InputEvent('input', {bubbles:true, data:text, inputType:'insertText'})); }, text);
      await locator.click({ force: true });
      if (method === 'settledFill') await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      if (method === 'fill' || method === 'settledFill') await locator.fill(text);
      else if (method === 'insertText') await page.keyboard.insertText(text);
      else await page.keyboard.type(text, {delay:50});
    }
    try {
      await snapshot('before');
      await enter(memo, method === 'type' ? 'Synthetic coffee' : 'Synthetic probe コーヒー');
      await snapshot('memo entered');
      await enter(amount, '1234');
      await snapshot('amount entered and memo blurred');
      await memo.click({force:true});
      await snapshot('memo refocused and amount blurred');
      await page.screenshot({path: `.ci-logs/flow-input/${method}.png`});
      row.events = await page.evaluate(() => window.__inputEvents);
      const last = row.snapshots.at(-1).controller;
      assert.equal(last.authenticated, false);
      assert.equal(last.requests.filter(x => x.includes('/rest/v1/') && !x.startsWith('GET ') && !x.startsWith('HEAD ')).length, 0);
      row.retained = last.fields['内容'] === (method === 'type' ? 'Synthetic coffee' : 'Synthetic probe コーヒー') && last.fields['金額 (円)'] === '1234';
    } catch (error) {
      row.failure = String(error);
      row.events = await page.evaluate(() => window.__inputEvents);
      await snapshot('failure');
      await page.screenshot({path: `.ci-logs/flow-input/${method}-failure.png`});
      await writeFile(`.ci-logs/flow-input/${method}-dom.html`, await page.content());
    }
    await writeFile('.ci-logs/flow-input/browser-evidence.json', JSON.stringify(evidence, null, 2));
    await context.close();
  }
  console.log(JSON.stringify(evidence.map(({method, retained, failure, snapshots}) => ({method, retained, failure, controllers:snapshots.map(x=>({stage:x.stage, ...x.controller}))})), null, 2));
  for (const method of ['domAfterFocus', 'fill', 'settledFill', 'insertText', 'type']) assert.equal(evidence.find(x => x.method === method)?.retained, true, `${method} must retain both controller values`);
} finally {
  await browser.close();
  await writeFile('.ci-logs/flow-input/browser-evidence.json', JSON.stringify(evidence, null, 2));
}
