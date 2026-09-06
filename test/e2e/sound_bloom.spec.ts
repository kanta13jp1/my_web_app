import { test, expect } from '@playwright/test';

test('audio output is non-silent during playback and stops on request', async ({ page }) => {
  // Observe the browser's output graph, not private application state.
  await page.addInitScript(() => {
    const original = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (...args: Parameters<AudioNode['connect']>) {
      const result = Reflect.apply(original, this, args);
      if (args[0] instanceof AudioDestinationNode) {
        const analyser = this.context.createAnalyser(); analyser.fftSize = 2048;
        Reflect.apply(original, this, [analyser]);
        (window as any).__soundProbe = { analyser, context: this.context };
      }
      return result;
    } as AudioNode['connect'];
  });
  await page.goto('/labs/sound-bloom/index.html');
  await page.getByRole('button', { name: '音を咲かせる' }).click();
  await expect.poll(() => page.evaluate(() => {
    const probe = (window as any).__soundProbe;
    if (!probe) return 0;
    const samples = new Float32Array(probe.analyser.fftSize);
    probe.analyser.getFloatTimeDomainData(samples);
    return Math.max(...samples.map(Math.abs));
  })).toBeGreaterThan(.001);
  await page.getByRole('button', { name: '演奏を止める' }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__soundProbe.context.state)).toBe('suspended');
});

test('editable garden, playback, undo, presets, and responsive layout', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/labs/sound-bloom/index.html');
  await expect(page.getByRole('heading', { name: '光を植えて、 音楽を育てる。' })).toBeVisible();
  const seed = page.getByRole('button', { name: '雫 1番目の音', exact: true });
  await expect(seed).toHaveAttribute('aria-pressed', 'true');
  await seed.click(); await expect(seed).toHaveAttribute('aria-pressed', 'false');
  await page.getByRole('button', { name: 'ひとつ戻す' }).click();
  await expect(seed).toHaveAttribute('aria-pressed', 'true');
  await page.getByRole('button', { name: '音を咲かせる' }).click();
  await expect(page.getByRole('button', { name: '演奏を止める' })).toBeVisible();
  await expect.poll(() => page.locator('#beat').innerText()).not.toBe('✳');
  await page.getByRole('button', { name: '03 夜光' }).click();
  await expect(page.locator('#tempo-value')).toHaveText('136');
  await page.getByRole('button', { name: '根の消音切替' }).click();
  await expect(page.getByRole('button', { name: '根の消音切替' })).toHaveAttribute('aria-pressed', 'true');
  await page.screenshot({ path: test.info().outputPath(`garden-${info.project.name}.png`), fullPage: true });
  await page.getByRole('button', { name: '演奏を止める' }).click();
  await expect(page.locator('#beat')).toHaveText('✳');
  await page.getByRole('button', { name: '種をすべて消す' }).click();
  await expect(page.locator('.seed[aria-pressed="true"]')).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  expect(errors).toEqual([]);
});

test('saved state restores, invalid input preserves the garden', async ({ page }) => {
  await page.goto('/labs/sound-bloom/index.html');
  await page.getByRole('button', { name: '02 木漏れ日' }).click();
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: '構成を保存' }).click();
  const download = await downloadPromise;
  const path = test.info().outputPath('sound-bloom.json'); await download.saveAs(path);
  await page.getByRole('button', { name: '種をすべて消す' }).click();
  await page.locator('#load').setInputFiles(path);
  await expect(page.locator('#status')).toContainText('復元しました');
  await expect(page.locator('#tempo-value')).toHaveText('112');
  const active = await page.locator('.seed[aria-pressed="true"]').count(); expect(active).toBeGreaterThan(0);
  await page.locator('#load').setInputFiles({ name: 'bad.json', mimeType: 'application/json', buffer: Buffer.from('{"tempo":999}') });
  await expect(page.locator('#status')).toContainText('読み込めません');
  await expect(page.locator('.seed[aria-pressed="true"]')).toHaveCount(active);
});
