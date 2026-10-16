import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
const origin = 'http://127.0.0.1:4173';
const output = '.ci-logs/repayment-responsive-qa';
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
const results = [];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
for (const viewport of [{ name: 'pc', width: 1440, height: 1000 }, { name: 'narrow', width: 393, height: 851 }]) {
  for (const scenario of ['recurring', 'mixed', 'zero']) {
    const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height }, serviceWorkers: 'block' });
    const page = await context.newPage();
    const result = { viewport, scenario, passed: false, blocked: [], externalResponses: [], pageErrors: [], consoleErrors: [], http: [], observations: [], screenshots: [] };
    await context.route('**/*', async route => {
      const req = route.request(); const url = new URL(req.url());
      if (url.origin === origin && req.method() === 'GET') return route.continue();
      result.blocked.push({ method: req.method(), origin: url.origin, path: url.pathname });
      await route.abort('blockedbyclient');
    });
    page.on('response', res => { if (new URL(res.url()).origin !== origin) result.externalResponses.push(res.status()); });
    page.on('pageerror', err => result.pageErrors.push(String(err)));
    page.on('console', msg => {
      const text = msg.text();
      if (msg.type() === 'error' || /RenderFlex|overflowed by|EXCEPTION CAUGHT|Unhandled Exception|Uncaught/.test(text)) result.consoleErrors.push(text);
      const prefix = 'REPAYMENT_QA_HTTP '; const i = text.indexOf(prefix);
      if (i >= 0) { try { result.http.push(JSON.parse(text.slice(i + prefix.length))); } catch {} }
    });
    const nodes = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics, input')].map(el => {
      const r = el.getBoundingClientRect();
      return { text: el.getAttribute('aria-label') || el.textContent || '', role: el.getAttribute('role'), x: r.x, y: r.y, width: r.width, height: r.height };
    }).filter(r => r.width > 0 && r.height > 0));
    const find = async (text, exact = false, scroll = true) => {
      for (let i = 0; i < (scroll ? 75 : 1); i++) {
        const all = await nodes();
        const candidates = all.filter(n => exact ? n.text === text : n.text.includes(text)).sort((a, b) => a.width * a.height - b.width * b.height);
        const hit = candidates.find(n => n.y >= 70 && n.y + n.height <= viewport.height - 20 && n.x >= 0 && n.x + n.width <= viewport.width + 1);
        if (hit) { result.observations.push(hit.text); return hit; }
        if (!scroll) break;
        const target = candidates[0];
        await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
        await page.mouse.wheel(0, target && target.y < 70 ? -350 : 500);
        await delay(120);
      }
      throw new Error(`Visible public target missing: ${text}`);
    };
    const click = async text => { const n = await find(text, true); await page.mouse.click(n.x + n.width / 2, n.y + n.height / 2); await delay(250); };
    const shot = async label => { const path = `${output}/${viewport.name}-${scenario}-${label}.png`; await page.screenshot({ path }); result.screenshots.push(path); };
    try {
      const res = await page.goto(`${origin}/?scenario=${scenario}`, { waitUntil: 'domcontentloaded' });
      if (!res?.ok()) throw new Error(`load ${res?.status()}`);
      await page.locator('#seo-shell').waitFor({ state: 'hidden', timeout: 60000 });
      await delay(1000);
      if (scenario === 'recurring') {
        await find('返済試算の対象元本はありません。');
        await find('全負債の完済時期ではありません。');
        await shot('empty');
        const all = await nodes();
        if (all.some(n => n.text.includes('対象件数・元本') || n.text === '0回')) throw new Error('Empty case exposes payoff metrics');
      } else {
        await find('今月未払いの対象元本の返済試算');
        await shot('scope');
        await find('全負債の完済時期ではありません。');
        await find('対象件数・元本');
        await find('1件 / ¥5,000');
        await find(scenario === 'zero' ? '未算出（予定返済額が0円）' : '5回', true);
        await shot('metrics');
        await click('残高が少ない順');
        await click('支払日順');
        await click('利率が高い順');
        await click('毎月の追加返済額');
        await page.keyboard.press('Control+A');
        await page.keyboard.type('1000');
        await page.keyboard.press('Tab');
        await delay(300);
        await find(scenario === 'zero' ? '5回' : '3回', true);
        await shot('extra');
        if (scenario === 'zero') {
          const all = await nodes();
          if (all.some(n => n.text.includes('未算出（予定返済額が0円）'))) throw new Error('Interest unavailable after public extra input');
        }
      }
      result.screen = await page.evaluate(() => ({ width: innerWidth, height: innerHeight, documentWidth: document.documentElement.scrollWidth }));
      if (result.screen.documentWidth > viewport.width + 1) throw new Error('Horizontal overflow');
      if (result.blocked.length || result.externalResponses.length || result.pageErrors.length || result.consoleErrors.length) throw new Error('Unexpected external attempt/transfer or console/layout error');
      if (result.http.some(r => r.method !== 'GET' || r.denied)) throw new Error('Unexpected write attempt');
      result.passed = true;
    } catch (err) {
      result.error = String(err);
      try { await shot('failed'); await writeFile(`${output}/${viewport.name}-${scenario}-dom.html`, await page.content()); } catch {}
    } finally {
      results.push(result); await context.close();
      await writeFile(`${output}/results.json`, JSON.stringify({ productHead: process.env.PRODUCT_HEAD, cases: results }, null, 2));
    }
  }
}
await browser.close();
if (results.some(r => !r.passed)) { console.error(JSON.stringify(results.map(({ viewport, scenario, passed, error }) => ({ viewport, scenario, passed, error })))); process.exitCode = 1; }
else console.log('Six real-page synthetic responsive cases passed; external attempts/transfers and writes=0.');
