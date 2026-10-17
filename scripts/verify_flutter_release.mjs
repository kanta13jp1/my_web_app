import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, expect } from '@playwright/test';

if (process.platform !== 'linux' || process.env.GITHUB_ACTIONS !== 'true') {
  throw new Error('Release verification requires an isolated Linux GitHub runner');
}
const entry = process.env.BENCH_ENTRY;
if (!['normal', 'isolated'].includes(entry)) throw new Error('Unknown entry');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const web = path.resolve(process.env.RELEASE_ARTIFACT_ROOT || path.join(root, 'build/web'));
const output = path.join(root, '.ci-logs/release-prototype');
const prefix = '/prototype/echo-pump/';
const origin = 'http://127.0.0.1:7366';
const report = { entry, head_sha: process.env.GITHUB_SHA, result: 'failure', samples: [],
  packaged_artifact_readback: !!process.env.RELEASE_ARTIFACT_ROOT,
  limitations: ['CI host landing page substitutes for the real host app',
    'fixture home is not production navigation; no shared login/session tested'],
  requests: [], blocked_external_hosts: [] };
const mime = { '.js': 'text/javascript', '.json': 'application/json', '.html': 'text/html',
  '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg' };
const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, origin);
    report.requests.push({ method: req.method, path: url.pathname });
    if (url.pathname.startsWith('/rest/v1/') || url.pathname.startsWith('/functions/v1/')) {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' });
      res.end(JSON.stringify(url.pathname.startsWith('/rest/v1/') ? [] : {})); return;
    }
    if (url.pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<h1>CI配信試作</h1><a href="${prefix}${entry === 'normal' ? 'echo-pump' : ''}">試作を開く</a>`); return;
    }
    if (!url.pathname.startsWith(prefix)) { res.writeHead(404); res.end(); return; }
    const relative = decodeURIComponent(url.pathname.slice(prefix.length));
    const safe = path.resolve(web, relative || 'index.html');
    if (!safe.startsWith(web + path.sep)) { res.writeHead(403); res.end(); return; }
    let file = safe;
    if (relative === 'echo-pump') file = path.join(web, 'index.html');
    const data = await fs.readFile(file);
    res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(7366, '127.0.0.1', resolve));
let browser; let activePage;
try {
  const build = JSON.parse(await fs.readFile(path.join(output, 'BUILD.json'), 'utf8'));
  for (const file of build.files) {
    const data = await fs.readFile(path.join(web, file.path));
    if (data.length !== file.bytes || createHash('sha256').update(data).digest('hex') !== file.sha256) {
      throw new Error('Artifact readback mismatch: ' + file.path);
    }
  }
  report.verified_file_count = build.files.length;
  const index = await fs.readFile(path.join(web, 'index.html'), 'utf8');
  if (!index.includes(`<base href="${prefix}">`)) throw new Error('Nested base href missing');
  browser = await chromium.launch({ headless: true });
  report.browser_version = browser.version();
  for (const viewport of [{ width: 1440, height: 1000 }, { width: 393, height: 851 }]) {
    const context = await browser.newContext({ viewport, serviceWorkers: 'block' });
    await context.route('**/*', route => {
      const url = new URL(route.request().url());
      if (url.origin === origin || (url.protocol === 'https:' &&
        ['fonts.gstatic.com', 'fonts.googleapis.com'].includes(url.hostname))) return route.continue();
      report.blocked_external_hosts.push(url.hostname); return route.abort();
    });
    const page = await context.newPage();
    activePage = page;
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    const missing = []; page.on('response', r => { if (r.url().startsWith(origin + prefix) && r.status() >= 400) missing.push(r.url()); });
    await page.goto(origin);
    await page.getByRole('link', { name: '試作を開く', exact: true }).click();
    const start = page.getByRole('button', { name: 'ゲーム開始', exact: true });
    await expect(start).toBeVisible({ timeout: 90000 });
    await page.screenshot({ path: path.join(output, `title-${viewport.width}.png`) });
    await start.click();
    await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
    await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).toBeVisible();
    await page.screenshot({ path: path.join(output, `play-${viewport.width}.png`) });
    await page.reload();
    await expect(start).toBeVisible({ timeout: 90000 });
    for (let back = 0; back < 3 && page.url() !== origin + '/'; back++) await page.goBack();
    await expect(page.getByRole('heading', { name: 'CI配信試作', exact: true })).toBeVisible();
    if (errors.length || missing.length) throw new Error(JSON.stringify({ errors, missing }));
    report.samples.push({ viewport, launch: true, start_game: true, direct_reload: true,
      browser_back_to_host: true, browser_errors: errors, missing_local_assets: missing });
    await context.close();
  }
  report.result = 'success';
} catch (error) {
  report.failure = String(error.stack || error); process.exitCode = 1;
  if (activePage && !activePage.isClosed()) {
    await activePage.screenshot({ path: path.join(output, 'failure.png') }).catch(() => {});
    await fs.writeFile(path.join(output, 'failure.html'), await activePage.content().catch(() => '')).catch(() => {});
  }
}
finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
  await fs.writeFile(path.join(output, 'SMOKE.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ entry, result: report.result, samples: report.samples, failure: report.failure }));
}
