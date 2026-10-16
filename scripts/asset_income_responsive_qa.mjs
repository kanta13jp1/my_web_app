import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';

const origin = 'http://127.0.0.1:4173';
const output = '.ci-logs/income-responsive-qa';
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
const results = [];
const required = ['収入フロー記録計:', '受取済み計画記録計:', '給与明細記録計: 未計算', '給与会計記録計:', '既存明細IDで照合', '対応の確認専用・独立加算なし'];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

for (const viewport of [{ name: 'pc', width: 1440, height: 1000 }, { name: 'narrow', width: 393, height: 851 }]) {
  const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height }, serviceWorkers: 'block' });
  const result = { viewport, passed: false, boot: [], reload: [], blocked: [], externalResponses: [], pageErrors: [], console: [], observed: [], screenshots: [] };
  const page = await context.newPage();
  let lastHttpAt = Date.now();
  const http = [];
  const observed = new Set();
  await context.route('**/*', async route => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin === origin && request.method() === 'GET') return route.continue();
    result.blocked.push({ method: request.method(), origin: url.origin, path: url.pathname });
    return route.abort('blockedbyclient');
  });
  page.on('response', response => {
    if (new URL(response.url()).origin !== origin) result.externalResponses.push({ url: response.url(), status: response.status() });
  });
  page.on('pageerror', error => result.pageErrors.push(String(error)));
  page.on('console', message => {
    const value = message.text();
    result.console.push({ type: message.type(), text: value });
    const index = value.indexOf('INCOME_QA_HTTP ');
    if (index !== -1) {
      try { http.push(JSON.parse(value.slice(index + 'INCOME_QA_HTTP '.length))); lastHttpAt = Date.now(); } catch { /* saved raw console is reviewed on failure */ }
    }
  });
  const texts = async () => page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics')).filter(el => {
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth;
  }).map(el => el.getAttribute('aria-label') ?? el.textContent ?? ''));
  const collect = async () => {
    for (const value of await texts()) for (const expected of required) if (value.includes(expected)) observed.add(expected);
  };
  const screenshot = async stage => {
    const file = `${output}/${viewport.name}-${stage}.png`;
    await page.screenshot({ path: file }); result.screenshots.push(file);
  };
  const visible = async locator => {
    for (let attempt = 0; attempt < 10; attempt++) {
      await collect();
      const box = await locator.boundingBox();
      if (box && box.width > 0 && box.height > 0 && box.y >= 100 && box.y + box.height < viewport.height - 30) return box;
      await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
      await page.mouse.wheel(0, box && box.y < 100 ? -350 : 350);
      await delay(150);
    }
    throw new Error('Control did not become visible within ten observed wheel inputs');
  };
  const click = async locator => {
    const box = await visible(locator);
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await delay(250);
  };
  try {
    const response = await page.goto(origin, { waitUntil: 'domcontentloaded' });
    if (!response?.ok()) throw new Error(`Fixture load ${response?.status()}`);
    await page.locator('#seo-shell').waitFor({ state: 'hidden', timeout: 60000 });
    const panel = page.getByRole('button', { name: /収入の照合が必要|記録上の収入を照合済み/ }).first();
    await panel.waitFor({ state: 'attached', timeout: 60000 });
    const quietDeadline = Date.now() + 15000;
    while (Date.now() < quietDeadline && (http.length === 0 || Date.now() - lastHttpAt < 800)) await delay(100);
    if (!http.length || Date.now() - lastHttpAt < 800) throw new Error('Synthetic boot transport did not settle');
    await click(panel);
    await screenshot('opened');
    const reload = page.getByRole('button', { name: '既存明細を再読込', exact: true });
    await reload.waitFor({ state: 'attached', timeout: 15000 });
    await visible(reload);
    await collect();
    await screenshot('detail');
    const missing = required.filter(value => !observed.has(value));
    if (missing.length) throw new Error(`Required public evidence missing: ${missing.join(', ')}`);
    const before = http.length;
    result.boot = http.slice(0, before);
    await click(reload);
    const deadline = Date.now() + 12000;
    let ready = false;
    while (Date.now() < deadline) {
      if (http.length > before && await reload.count() === 1 && await reload.isEnabled()) { ready = true; break; }
      await delay(100);
    }
    if (!ready) throw new Error('Real reload did not return to ready after new transport');
    await delay(300);
    result.reload = http.slice(before);
    if (!result.reload.length || result.reload.some(row => row.method !== 'GET' || row.denied)) throw new Error('New reload attempted a denied request or non-GET');
    const finance = result.reload.filter(row => /\/(payslips|salary_incomes)$/.test(row.path));
    if (finance.length !== 3) throw new Error(`Expected three finance GETs, got ${finance.length}`);
    await collect();
    await screenshot('reloaded');
    const screen = await page.evaluate(() => ({ width: innerWidth, height: innerHeight, documentWidth: document.documentElement.scrollWidth, dpr: devicePixelRatio }));
    result.screen = screen;
    if (screen.width !== viewport.width || screen.height !== viewport.height || screen.documentWidth > viewport.width + 1) throw new Error('Viewport mismatch or horizontal overflow');
    if (result.externalResponses.length || result.pageErrors.length) throw new Error('Unexpected external transfer or page exception');
    const layoutErrors = result.console.filter(row => /RenderFlex|overflowed by|EXCEPTION CAUGHT|Unhandled Exception|Uncaught/.test(row.text));
    if (layoutErrors.length) throw new Error('Flutter layout or unhandled exception in console');
    const unexpectedErrors = result.console.filter(row => row.type === 'error' && !row.text.includes('INCOME_QA_DENIED'));
    if (unexpectedErrors.length) throw new Error('Unexpected console error (boot denials are recorded separately)');
    result.passed = true;
  } catch (error) {
    result.error = String(error);
    try { await screenshot('failed'); } catch { /* preserve JSON even if renderer failed */ }
    try { await writeFile(`${output}/${viewport.name}-synthetic-dom.html`, await page.content()); } catch { /* preserve other evidence */ }
  } finally {
    result.observed = [...observed];
    result.bootDenied = result.boot.filter(row => row.denied);
    results.push(result);
    await context.close();
    await writeFile(`${output}/results.json`, JSON.stringify({ productHead: process.env.PRODUCT_HEAD, cases: results }, null, 2));
  }
}
await browser.close();
if (results.some(result => !result.passed)) { console.error(JSON.stringify(results.map(({ viewport, passed, error }) => ({ viewport, passed, error })))); process.exitCode = 1; }
else console.log('Both synthetic responsive income cases passed; external responses=0, new reload GET-only.');
