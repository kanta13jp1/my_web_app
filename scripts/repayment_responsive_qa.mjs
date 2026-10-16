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
    const semanticText = async () => (await nodes()).map(n => n.text).join('\n');
    const token = async (text, exact = false) => {
      const all = await semanticText();
      const ok = exact ? all.split('\n').some(line => line.trim() === text) : all.includes(text);
      if (!ok) throw new Error(`Public semantic token missing: ${text}`);
      result.observations.push(text);
    };
    const input = page.locator('input[aria-label="毎月の追加返済額"]');
    const anchor = async () => {
      for (let i = 0; i < 30; i++) {
        const box = await input.boundingBox();
        if (box && box.y >= 190 && box.y <= 260 && box.x >= 0 && box.x + box.width <= viewport.width + 1) {
          result.inputAnchor = box; return box;
        }
        const delta = box ? Math.max(-4000, Math.min(4000, box.y - 220)) : 1000;
        await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
        await page.mouse.wheel(0, delta);
        await delay(180);
      }
      throw new Error('Public textbox rect did not reach bounded visible anchor');
    };
    const click = async text => {
      const locator = page.getByRole('checkbox', { name: text, exact: true });
      const box = await locator.boundingBox();
      if (!box || box.y < 60 || box.y + box.height > viewport.height) throw new Error(`Strategy not visible: ${text}`);
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2); await delay(250);
      if (await locator.getAttribute('aria-checked') !== 'true') throw new Error(`Public strategy did not select: ${text}`);
      result.strategyInputs ??= []; result.strategyInputs.push(text);
    };
    const shot = async label => { const path = `${output}/${viewport.name}-${scenario}-${label}.png`; await page.screenshot({ path }); result.screenshots.push(path); };
    try {
      const res = await page.goto(`${origin}/?scenario=${scenario}`, { waitUntil: 'domcontentloaded' });
      if (!res?.ok()) throw new Error(`load ${res?.status()}`);
      await page.locator('#seo-shell').waitFor({ state: 'hidden', timeout: 60000 });
      await delay(1000);
      const bootDeadline = Date.now() + 3000;
      let previous = result.http.length;
      for (; Date.now() < bootDeadline;) {
        await delay(400);
        if (previous === result.http.length) break;
        previous = result.http.length;
      }
      const bootCount = result.http.length;
      result.boot = result.http.slice();
      result.bootDenied = result.boot.filter(r => r.denied);
      if (scenario === 'recurring') {
        // Static text is merged into a scroll group; its rect is not text position.
        // Reach the actual page end with public wheels, then review this PNG.
        for (let i = 0; i < 8; i++) {
          await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
          await page.mouse.wheel(0, 5000); await delay(200);
        }
        await token('返済試算の対象元本はありません。');
        await token('全負債の完済時期ではありません。');
        await shot('empty');
        const all = await semanticText();
        if (all.includes('対象件数・元本') || all.split('\n').some(x => x.trim() === '0回')) throw new Error('Empty case exposes payoff metrics');
      } else {
        await anchor();
        await token('今月未払いの対象元本の返済試算');
        await token('全負債の完済時期ではありません。');
        await token('対象件数・元本');
        await token('1件 / ¥5,000', true);
        await token(scenario === 'zero' ? '未算出（予定返済額が0円）' : '5回', true);
        await shot('metrics');
        await click('残高が少ない順');
        await click('支払日順');
        await click('利率が高い順');
        const box = await input.boundingBox();
        await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
        await page.keyboard.press('Control+A');
        await page.keyboard.type('1000');
        result.enteredValue = await input.inputValue();
        if (result.enteredValue !== '1000') throw new Error('Public keyboard input not reflected');
        await page.keyboard.press('Tab'); await delay(300);
        await token(scenario === 'zero' ? '5回' : '3回', true);
        await shot('extra');
        if (scenario === 'zero' && (await semanticText()).includes('未算出（予定返済額が0円）')) throw new Error('Interest unavailable after public extra input');
      }
      result.publicRequests = result.http.slice(bootCount);
      result.screen = await page.evaluate(() => ({ width: innerWidth, height: innerHeight, documentWidth: document.documentElement.scrollWidth }));
      if (result.screen.documentWidth > viewport.width + 1) throw new Error('Horizontal overflow');
      if (result.blocked.length || result.externalResponses.length || result.pageErrors.length || result.consoleErrors.length) throw new Error('Unexpected external attempt/transfer or console/layout error');
      if (result.publicRequests.some(r => r.method !== 'GET' || r.denied)) throw new Error('Public operation attempted a write');
      result.bootRequiresSourceReview = result.bootDenied.length > 0;
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
