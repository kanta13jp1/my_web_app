// Actual production viewport recording, no private cookies or synthetic UI.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const origin = 'https://my-web-app-b67f4.web.app';
const expected = process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected ?? '', /^[a-f0-9]{40}$/);
const out = 'flow-city-recording';
mkdirSync(out, { recursive: true });
async function version() {
  const response = await fetch(`${origin}/version.json`, { cache: 'no-store' });
  assert(response.ok);
  const value = await response.json();
  assert.equal(value.commit, expected, 'Production revision changed');
  return value;
}
const before = await version();
const browser = await chromium.launch({ headless: true });
// Verify the actual integrated public route before recording its public asset.
const smoke = await browser.newContext({ viewport: { width: 1440, height: 1080 }, locale: 'ja-JP' });
const smokePage = await smoke.newPage();
const smokeErrors = [];
smokePage.on('pageerror', error => smokeErrors.push(error.message));
await smokePage.goto(`${origin}/flow-city`, { waitUntil: 'domcontentloaded' });
const lab = smokePage.frameLocator('iframe');
await lab.locator('#play').waitFor({ timeout: 60000 });
await lab.locator('#play').click();
await lab.locator('#play').filter({ hasText: '一時停止' }).waitFor();
await smokePage.waitForTimeout(1500);
await lab.locator('#play').click();
assert.notEqual(await lab.locator('#clock').innerText(), '0 / 720 tick');
await smokePage.screenshot({ path: `${out}/production-route.png` });
assert.deepEqual(smokeErrors, []);
writeFileSync(`${out}/route-check.json`, JSON.stringify({ revision: before, route: '/flow-city', errors: smokeErrors, clock: await lab.locator('#clock').innerText() }, null, 2));
await smoke.close();
const context = await browser.newContext({ viewport: { width: 1440, height: 1080 },
  locale: 'ja-JP', recordVideo: { dir: out, size: { width: 1440, height: 1080 } } });
const page = await context.newPage();
const video = page.video();
const events = [], errors = [];
const start = Date.now();
const mark = action => events.push({ seconds: (Date.now() - start) / 1000, action });
const hold = ms => new Promise(resolve => setTimeout(resolve, ms));
page.on('pageerror', error => errors.push(error.message));
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
let after;
try {
  await page.goto(`${origin}/labs/flow-city/index.html`, { waitUntil: 'networkidle' });
  await page.locator('#focus').click();
  await page.locator('#speed').selectOption('40');
  mark('ready'); await hold(3000);
  await page.locator('#play').click(); mark('baseline-running'); await hold(12000);
  await page.locator('#play').click(); mark('baseline-paused'); await hold(4000);
  const baseline = await page.locator('#difference').innerText();
  await page.locator('#wave').click(); mark('east-wave'); await hold(3000);
  // Configuration controls may leave playback stopped; explicit UI state only.
  if ((await page.locator('#play').innerText()).includes('停止') === false) {
    await page.locator('#play').click();
  }
  mark('wave-running'); await hold(12000);
  if ((await page.locator('#play').innerText()).includes('停止')) {
    await page.locator('#play').click();
  }
  const comparison = await page.locator('#difference').innerText();
  mark('comparison-paused'); await hold(6000);
  await page.screenshot({ path: `${out}/comparison.png` });
  after = await version();
  assert.deepEqual(errors, []);
  writeFileSync(`${out}/results.json`, JSON.stringify({ baseline, comparison }, null, 2));
} finally {
  await context.close(); await browser.close();
  writeFileSync(`${out}/evidence.json`, JSON.stringify({ before, after, events, errors,
    method: 'Public production Chromium viewport; normal UI actions; no cookies/audio/generated frames',
    candidatePassed: Boolean(after) && errors.length === 0 }, null, 2));
}
const raw = await video.path();
const trim = events.find(event => event.action === 'ready').seconds;
const final = `${out}/flow-city-x.mp4`;
execFileSync('ffmpeg', ['-y', '-i', raw, '-ss', String(trim), '-an', '-c:v', 'libx264',
  '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', final]);
const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', final]));
assert(probe.streams.some(s => s.codec_name === 'h264' && s.width === 1440 && s.height === 1080));
assert(Number(probe.format.duration) >= 30 && Number(probe.format.duration) <= 60);
writeFileSync(`${out}/media-check.json`, JSON.stringify({ raw, final, trimStartSeconds: trim, speed: 1, probe }, null, 2));
for (const second of [1, 8, 22, 36]) {
  execFileSync('ffmpeg', ['-y', '-ss', String(second), '-i', final, '-frames:v', '1', `${out}/frame-${second}.jpg`]);
}
