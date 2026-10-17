import { test, expect, Page } from '@playwright/test';

test.setTimeout(60000);

test.beforeEach(async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  (page as any).__echoPageErrors = errors;
  // Observe the real playback promises, audio contexts and gain values.
  // The original methods still perform all decoding and playback.
  await page.addInitScript(() => {
    const audit = { media: [] as HTMLMediaElement[], plays: [] as string[],
      contexts: [] as AudioContext[], gains: [] as GainNode[] };
    (window as any).__echoAudioAudit = audit;
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      if (!audit.media.includes(this)) audit.media.push(this);
      const result = play.call(this);
      result.then(() => audit.plays.push(this.currentSrc || this.src), () => {});
      return result;
    };
    const createGain = AudioContext.prototype.createGain;
    AudioContext.prototype.createGain = function () {
      const node = createGain.call(this);
      if (!audit.contexts.includes(this)) audit.contexts.push(this);
      audit.gains.push(node);
      return node;
    };
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: '音をON', exact: true })).toBeVisible({ timeout: 30000 });
});

test.afterEach(async ({ page }, info) => {
  const errors: string[] = (page as any).__echoPageErrors;
  await info.attach('uncaught-page-errors', {
    body: JSON.stringify(errors), contentType: 'application/json',
  });
  expect(errors).toEqual([]);
});

async function hasPlayed(page: Page, file: string) {
  return page.evaluate(name =>
    (window as any).__echoAudioAudit.plays.some((src: string) => src.includes(`/${name}.wav`)), file);
}

async function enterGame(page: Page) {
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
  await expect(page.getByRole('checkbox', { name: 'B 整備', exact: true })).toBeVisible();
}

test('real BGM and SE play, volume and mute work, leaving closes audio', async ({ page }, info) => {
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.media.length)).toBe(0);
  await page.getByRole('button', { name: '音をON', exact: true }).click();
  await expect.poll(() => hasPlayed(page, 'bgm'), { timeout: 15000 }).toBe(true);
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.contexts.some((c: AudioContext) => c.state === 'running'))).toBe(true);
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.media.some((m: HTMLMediaElement) => m.loop && !m.paused && m.currentTime > 0.1))).toBe(true);
  await enterGame(page);
  await expect.poll(() => hasPlayed(page, 'start')).toBe(true);
  await page.getByRole('checkbox', { name: 'B 整備', exact: true }).click();
  await expect(page.getByRole('checkbox', { name: 'B 整備', exact: true })).toBeChecked();
  await expect.poll(() => hasPlayed(page, 'power')).toBe(true);
  const gainBefore = await page.evaluate(() => (window as any).__echoAudioAudit.gains[0].gain.value);
  const bgmPlaysBefore = await page.evaluate(() => (window as any).__echoAudioAudit.plays.filter((src: string) => src.includes('/bgm.wav')).length);
  const slider = page.getByRole('slider');
  await slider.focus();
  await expect(slider).toBeFocused();
  // Flutter applies focus during its render frame after the power toggle.
  await page.evaluate(() => new Promise<void>(resolve => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  }));
  await expect(slider).toBeFocused();
  const volumeBefore = await slider.getAttribute('aria-valuetext');
  await slider.press('ArrowLeft');
  await expect.poll(() => slider.getAttribute('aria-valuetext')).not.toBe(volumeBefore);
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.gains[0].gain.value)).toBeLessThan(gainBefore);
  expect(await page.evaluate(() => (window as any).__echoAudioAudit.plays.filter((src: string) => src.includes('/bgm.wav')).length)).toBe(bgmPlaysBefore);
  await page.screenshot({ path: info.outputPath('audio-on.png') });
  await page.getByRole('button', { name: '音をOFF', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.media.every((m: HTMLMediaElement) => m.paused || m.ended || !m.getAttribute('src')))).toBe(true);
  const plays = await page.evaluate(() => (window as any).__echoAudioAudit.plays.length);
  await page.getByRole('checkbox', { name: 'A 搬入', exact: true }).click();
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => (window as any).__echoAudioAudit.plays.length)).toBe(plays);
  await page.getByRole('button', { name: '音をON', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.media.some((m: HTMLMediaElement) => !m.paused && m.loop))).toBe(true);
  await page.getByRole('button', { name: '中央廊下へ', exact: true }).click();
  await expect.poll(() => hasPlayed(page, 'step')).toBe(true);
  await page.mouse.move(page.viewportSize()!.width / 2, page.viewportSize()!.height / 2);
  await page.mouse.wheel(0, -4000);
  await page.waitForTimeout(300);
  await page.screenshot({ path: info.outputPath('visual-guidance.png') });
  await info.attach('actual-audio-playback', {
    body: JSON.stringify(await page.evaluate(() => ({
      plays: (window as any).__echoAudioAudit.plays,
      gains: (window as any).__echoAudioAudit.gains.map((g: GainNode) => g.gain.value),
      contexts: (window as any).__echoAudioAudit.contexts.map((c: AudioContext) => c.state),
    }))), contentType: 'application/json',
  });
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await expect(page.getByText('音声確認ホーム')).toBeVisible();
  await expect.poll(() => page.evaluate(() => (window as any).__echoAudioAudit.contexts.every((c: AudioContext) => c.state === 'closed'))).toBe(true);
});

test('failed audio stays silent, game still works, and retry can recover', async ({ page }, info) => {
  await page.route('**/bgm.wav', route => route.abort());
  await page.getByRole('button', { name: '音をON', exact: true }).click();
  await expect(page.getByText('再生できませんでした。音をONにして再試行できます。')).toBeVisible({ timeout: 15000 });
  await enterGame(page);
  await page.unroute('**/bgm.wav');
  await page.getByRole('button', { name: '音をON', exact: true }).click();
  await expect.poll(() => hasPlayed(page, 'bgm'), { timeout: 15000 }).toBe(true);
  await page.screenshot({ path: info.outputPath('audio-recovered.png') });
});
