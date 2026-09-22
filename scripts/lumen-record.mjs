// Cloud-only candidate. Records the public app viewport, never a user's desktop.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const origin = 'https://my-web-app-b67f4.web.app';
const expected = process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected ?? '', /^[a-f0-9]{40}$/, 'Require reviewed production revision');
const out = 'lumen-recording';
mkdirSync(out, { recursive: true });
async function version() {
  const response = await fetch(`${origin}/version.json`, { cache: 'no-store' });
  assert(response.ok);
  const value = await response.json();
  assert.equal(value.commit, expected, 'Production changed: review before recording');
  return value;
}
const before = await version();
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1440, height: 1080 }, locale: 'ja-JP',
  recordVideo: { dir: out, size: { width: 1440, height: 1080 } },
});
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
  await page.goto(`${origin}/labs/lumen-path/index.html`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.getByRole('button', { name: /^鏡 1、/ }).waitFor();
  await page.screenshot({ path: `${out}/ready.png` });
  mark('ready'); await hold(2500);
  await page.getByRole('button', { name: /^鏡 1、/ }).click();
  assert.equal(await page.locator('#lit').innerText(), '1 / 1 LIGHTS');
  mark('room-1-lit'); await hold(5000);
  await page.getByRole('button', { name: '一手戻す', exact: true }).click();
  assert.equal(await page.locator('#lit').innerText(), '0 / 1 LIGHTS');
  mark('undo'); await hold(3500);
  await page.getByRole('combobox', { name: '部屋を選ぶ' }).selectOption('2');
  mark('room-3'); await hold(4000);
  for (let i = 1; i <= 3; i++) {
    await page.getByRole('button', { name: new RegExp(`^鏡 ${i}、`) }).click();
    mark(`rotate-${i}`); await hold(4500);
  }
  assert.equal(await page.locator('#lit').innerText(), '3 / 3 LIGHTS');
  assert.equal(await page.locator('#status').innerText(), '3色すべて点灯。光の道がつながりました。');
  await page.screenshot({ path: `${out}/solved.png` });
  mark('solved'); await hold(5000);
  after = await version();
  assert.deepEqual(errors, []);
} finally {
  await context.close();
  await browser.close();
  writeFileSync(`${out}/evidence.json`, JSON.stringify({ before, after, events, errors,
    method: 'Actual public-site Chromium viewport recording; normal UI actions; no DOM changes, generated frames, cookies, microphone or audio',
    candidatePassed: Boolean(after) && errors.length === 0,
  }, null, 2));
}
const raw = await video.path();
// Remove loading lead-in only; keep original WebM and preserve actual playback speed.
const trim = events.find(event => event.action === 'ready').seconds;
const final = `${out}/lumen-path-x.mp4`;
execFileSync('ffmpeg', ['-y', '-i', raw, '-ss', String(trim), '-an', '-c:v', 'libx264',
  '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', final]);
const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', final]));
assert(probe.streams.some(s => s.codec_name === 'h264' && s.width === 1440 && s.height === 1080));
assert(Number(probe.format.duration) >= 30 && Number(probe.format.duration) <= 60);
writeFileSync(`${out}/media-check.json`, JSON.stringify({ raw, final, trimStartSeconds: trim, speed: 1, probe }, null, 2));
for (const second of [1, 8, 18, 28]) {
  execFileSync('ffmpeg', ['-y', '-ss', String(second), '-i', final, '-frames:v', '1', `${out}/frame-${second}.jpg`]);
}
