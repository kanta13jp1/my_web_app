import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync, writeFileSync, readFileSync, readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const origin = 'https://my-web-app-b67f4.web.app';
const expected = process.env.EXPECTED_PRODUCTION_SHA;
assert.match(expected ?? '', /^[a-f0-9]{40}$/);
const out = 'echo-public-evidence';
mkdirSync(out, {recursive: true});
async function version() {
  const r = await fetch(`${origin}/version.json`, {cache: 'no-store'});
  assert(r.ok);
  const v = await r.json(); assert.equal(v.commit, expected); return v;
}
let before;
// Overlap dependency setup with deployment, but never test an older revision.
for (let attempt = 0; attempt < 30; attempt++) {
  try { before = await version(); break; }
  catch (error) {
    if (attempt === 29) throw error;
    await new Promise(resolve => setTimeout(resolve, 10000));
  }
}
const browser = await chromium.launch({headless: true});
const reports = [];
try {
  // A tall desktop view keeps both the ordinary controls and response visible
  // during recording. It does not alter the game's clock or animation settings.
  for (const [name, viewport] of [['desktop', {width: 1440, height: 2000}], ['mobile', {width: 390, height: 1000}]]) {
    const context = await browser.newContext({viewport, locale: 'ja-JP', reducedMotion: 'no-preference', recordVideo: {dir: out, size: viewport}});
    const page = await context.newPage(), video = page.video();
    const errors = [], events = [], started = Date.now();
    page.on('pageerror', e => errors.push(e.message));
    const mark = action => events.push({ms: Date.now() - started, action});
    await page.addInitScript(() => {
      const audit = {plays: [], media: [], contexts: []};
      window.__echoPublicAudit = audit;
      const play = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function () {
        if (!audit.media.includes(this)) audit.media.push(this);
        const result = play.call(this);
        result.then(() => audit.plays.push(this.currentSrc || this.src), () => {});
        return result;
      };
      const gain = AudioContext.prototype.createGain;
      AudioContext.prototype.createGain = function () {
        if (!audit.contexts.includes(this)) audit.contexts.push(this);
        return gain.call(this);
      };
    });
    const button = text => page.getByRole(/^[ABC] /.test(text) ? 'checkbox' : 'button', {name: text, exact: true});
    async function click(text) {
      const counter = page.getByText(/^ターン \d+$/).first();
      const previous = await counter.count() ? await counter.textContent() : null;
      mark(`${text}:begin`);
      await button(text).click({timeout: 15000}); mark(text);
      if (previous && !['音をON', '音をOFF'].includes(text)) {
        await page.waitForFunction(previous => Array.from(document.querySelectorAll('flt-semantics > span')).some(e => /^ターン \d+$/.test(e.textContent) && e.textContent !== previous), previous, {timeout: 15000});
      }
    }
    async function progressHas(text) {
      const progress = await page.getByText(/探索の進行/).first().textContent();
      assert(progress.includes(text), `Missing progress: ${text}`);
    }
    async function played(file) {
      await page.waitForFunction(file => window.__echoPublicAudit.plays.some(x => x.includes(`/${file}.wav`)), file, {timeout: 15000});
    }
    let passed = false, audio;
    const animationWindows = {};
    async function sampleAnimation(stem, message, trigger) {
      await page.mouse.move(viewport.width / 2, viewport.height / 2);
      await page.mouse.wheel(0, -30000);
      await page.waitForTimeout(80);
      const box = await page.locator('flt-semantics > span').filter({hasText: message}).last().locator('..').boundingBox();
      assert(box && box.width > 100 && box.height > 40 && box.y >= 0 && box.y + box.height < viewport.height - 40);
      const begin = events.findLast(e => e.action === `${trigger}:begin`).ms;
      animationWindows[stem] = {start: Math.max(0, begin / 1000 - 0.4), end: (Date.now() - started) / 1000 + 0.3,
        clip: {x: Math.floor(box.x / 2) * 2, y: Math.floor(box.y / 2) * 2, width: Math.floor(box.width / 2) * 2, height: Math.floor(box.height / 2) * 2}};
      await page.screenshot({path: `${out}/${stem}-settled.png`, clip: box});
    }
    try {
      await page.goto(`${origin}/echo-pump`, {waitUntil: 'domcontentloaded'});
      const activate = page.locator('flt-semantics-placeholder');
      await Promise.race([
        button('ゲーム開始').waitFor({timeout: 60000}),
        activate.waitFor({state: 'attached', timeout: 60000}),
      ]);
      if (await activate.count()) await activate.dispatchEvent('click');
      await button('ゲーム開始').waitFor({timeout: 60000});
      assert.equal(await page.evaluate(() => window.__echoPublicAudit.media.length), 0);
      await click('音をON'); await played('bgm');
      await page.waitForFunction(() => window.__echoPublicAudit.contexts.some(c => c.state === 'running') && window.__echoPublicAudit.media.some(m => m.loop && !m.paused && m.currentTime > 0.1), null, {timeout: 15000});
      await click('ゲーム開始'); await click('スキップして開始');
      await button('B 整備').waitFor({timeout: 15000});
      await progressHas('回収：次の目標');
      await page.screenshot({path: `${out}/${name}-goals.png`});
      await click('B 整備'); await played('power');
      await click('A 搬入');
      await click('中央廊下へ');
      if (name === 'desktop') {
        await sampleAnimation('movement', '中央廊下へ移動した。', '中央廊下へ');
      }
      await played('step');
      await page.screenshot({path: `${out}/${name}-movement.png`});
      if (name === 'desktop') {
        for (const label of ['工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ','ヒューズで修理','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ','隔壁を閉じる','排水ポンプを起動','中央廊下へ','管理室へ','出口へ']) {
          await click(label);
          if (label === 'ヒューズを回収') await progressHas('回収：完了');
          if (label === 'ヒューズで修理') await progressHas('修理：完了');
          if (label === '隔壁を閉じる') await sampleAnimation('seal', '隔壁を閉鎖！ 敵を点検槽に封じ込めた。', label);
          if (label === '排水ポンプを起動') await sampleAnimation('drain', '排水完了。管理室から出口へ戻ろう。', label);
        }
        await button('リトライ').waitFor({timeout: 15000});
        await played('escape');
        for (const label of ['回収','修理','封鎖','排水','脱出']) await progressHas(`${label}：完了`);
        await page.mouse.wheel(0, -30000); await page.waitForTimeout(250);
        await page.screenshot({path: `${out}/desktop-complete.png`});
      }
      audio = await page.evaluate(() => ({plays: window.__echoPublicAudit.plays, contexts: window.__echoPublicAudit.contexts.map(c => c.state), media: window.__echoPublicAudit.media.map(m => ({src: m.currentSrc || m.src, paused: m.paused, currentTime: m.currentTime, ended: m.ended, muted: m.muted}))}));
      await click('音をOFF');
      await page.waitForFunction(() => window.__echoPublicAudit.media.every(m => m.paused || m.ended || !m.getAttribute('src')), null, {timeout: 10000});
      assert.deepEqual(errors, []);
      passed = true;
    } finally {
      if (!passed) {
        await page.screenshot({path: `${out}/${name}-failure.png`}).catch(() => {});
        const labels = await page.locator('[aria-label]').evaluateAll(nodes => nodes.map(n => n.getAttribute('aria-label'))).catch(() => []);
        writeFileSync(`${out}/${name}-failure-labels.json`, JSON.stringify(labels, null, 2));
        audio ??= await page.evaluate(() => ({plays: window.__echoPublicAudit?.plays, contexts: window.__echoPublicAudit?.contexts.map(c => c.state)})).catch(() => ({}));
      }
      const report = {name, passed, errors, events, audio, animationWindows, animationProof: {}};
      await context.close();
      try {
        if (passed && name === 'desktop') {
          const raw = await video.path();
          for (const [stem, window] of Object.entries(animationWindows)) {
            const c = window.clip;
            const args = ['-v','error','-y','-ss',String(window.start),'-i',raw,'-t',String(window.end-window.start),'-vf',`fps=12,crop=${c.width}:${c.height}:${c.x}:${c.y}`,`${out}/${stem}-video-%03d.png`];
            execFileSync('ffmpeg', args);
            const files = readdirSync(out).filter(f => f.startsWith(`${stem}-video-`) && f.endsWith('.png')).sort();
            const hashes = files.map(f => createHash('sha256').update(readFileSync(`${out}/${f}`)).digest('hex'));
            const distinct = new Set(hashes).size;
            report.animationProof[stem] = {raw, args, files, hashes, distinct};
            assert(distinct >= 4, `${stem} needs multiple real intermediate frames; got ${distinct}`);
          }
        }
      } catch (error) { report.passed = false; throw error; }
      finally {
        reports.push(report);
        writeFileSync(`${out}/${name}-result.json`, JSON.stringify(report, null, 2));
      }
    }
  }
  const after = await version();
  writeFileSync(`${out}/result.json`, JSON.stringify({passed: true, before, after, reports, method: 'Actual public UI in clean unauthenticated contexts. Native playback promises and running contexts observed. Real intermediate frames decoded from unmodified session video, cropped to each action rectangle; no game clock/state injection. Tall desktop viewport keeps controls and response in view. No human listening or device-speaker verification.'}, null, 2));
} finally { await browser.close(); }
