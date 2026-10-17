import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

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
  for (const [name, viewport] of [['desktop', {width: 1440, height: 1080}], ['mobile', {width: 390, height: 1000}]]) {
    const context = await browser.newContext({viewport, locale: 'ja-JP', reducedMotion: 'no-preference', recordVideo: {dir: out, size: viewport}});
    const page = await context.newPage();
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
    let passed = false, audio, frameHashes = [], otherAnimationHashes = {};
    async function sampleAnimation(stem, message) {
      await page.mouse.move(viewport.width / 2, viewport.height / 2);
      await page.mouse.wheel(0, -30000);
      await page.waitForTimeout(80);
      const box = await page.locator('flt-semantics > span').filter({hasText: message}).last().locator('..').boundingBox();
      assert(box && box.width > 100 && box.height > 40 && box.y >= 0 && box.y + box.height < viewport.height - 40);
      const hashes = [];
      for (let i = 0; i < 3; i++) {
        const bytes = await page.screenshot({path: `${out}/${stem}-frame-${i}.png`, clip: box});
        hashes.push(createHash('sha256').update(bytes).digest('hex'));
        if (i < 2) await page.waitForTimeout(260);
      }
      assert(new Set(hashes).size > 1, `${stem} animation must change pixels inside its own rectangle`);
      return hashes;
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
        frameHashes = await sampleAnimation('movement', '中央廊下へ移動した。');
      }
      await played('step');
      await page.screenshot({path: `${out}/${name}-movement.png`});
      if (name === 'desktop') {
        for (const label of ['工具庫へ','ヒューズを回収','中央廊下へ','ポンプ室へ','ヒューズで修理','中央廊下へ','管理室へ','B 整備','C 排水','1ターン待つ','1ターン待つ','中央廊下へ','ポンプ室へ','隔壁を閉じる','排水ポンプを起動','中央廊下へ','管理室へ','出口へ']) {
          await click(label);
          if (label === 'ヒューズを回収') await progressHas('回収：完了');
          if (label === 'ヒューズで修理') await progressHas('修理：完了');
          if (label === '隔壁を閉じる') otherAnimationHashes.seal = await sampleAnimation('seal', '隔壁を閉鎖！ 敵を点検槽に封じ込めた。');
          if (label === '排水ポンプを起動') otherAnimationHashes.drain = await sampleAnimation('drain', '排水完了。管理室から出口へ戻ろう。');
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
      const report = {name, passed, errors, events, audio, frameHashes, otherAnimationHashes};
      reports.push(report);
      writeFileSync(`${out}/${name}-result.json`, JSON.stringify(report, null, 2));
      await context.close();
    }
  }
  const after = await version();
  writeFileSync(`${out}/result.json`, JSON.stringify({passed: true, before, after, reports, method: 'Actual public UI in clean unauthenticated contexts. Playback wrappers observe native promises without replacing decoding/playback. Movement pixels sampled only inside the action rectangle. No human listening or device-speaker verification.'}, null, 2));
} finally { await browser.close(); }
