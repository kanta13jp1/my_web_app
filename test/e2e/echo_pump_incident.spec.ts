import { test, expect } from '@playwright/test';

test.setTimeout(90000);

for (const skip of [false, true]) {
  test(`equipment incident ${skip ? 'skip' : 'natural end'} stops walking and returns once`, async ({ page }, info) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => {
      const audit = { requests: [] as { src: string; time: number }[], steps: 0, media: [] as HTMLMediaElement[] };
      (window as any).__incidentAudio = audit;
      const play = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function () {
        if (!audit.media.includes(this)) audit.media.push(this);
        audit.requests.push({ src: this.currentSrc || this.src, time: performance.now() });
        const result = play.call(this);
        result.then(() => { if ((this.currentSrc || this.src).includes('/step.wav')) audit.steps++; }, () => {});
        return result;
      };
    });
    const button = (name: string) => page.getByRole('button', { name, exact: true });
    await page.goto('/');
    await button('音をON').click();
    await button('ゲーム開始').click();
    await button('スキップして開始').click();
    await button('保守メモを調べる').click();
    await expect(page.getByText('歩行中…', { exact: true }).first()).toBeVisible();
    await button('異常灯を調べる').dispatchEvent('click');
    await expect(page.getByText('設備異常 1 / 3', { exact: true })).toBeVisible();
    await expect(page.getByText('歩行中…', { exact: true })).toHaveCount(0);
    const opened = await page.evaluate(() => performance.now());
    await button('演出を一時停止').click();
    await page.waitForTimeout(1800);
    const audio = await page.evaluate(t => {
      const a = (window as any).__incidentAudio;
      return {
        late: a.requests.filter((x: any) => x.time >= t && x.src.includes('/step.wav')),
        activeSteps: a.media.filter((m: HTMLMediaElement) => (m.currentSrc || m.src).includes('/step.wav') && !m.paused && !m.ended).length,
        music: a.media.some((m: HTMLMediaElement) => (m.currentSrc || m.src).includes('/bgm.wav') && !m.paused && !m.ended),
      };
    }, opened);
    expect(audio).toEqual({ late: [], activeSteps: 0, music: true });
    await expect(page.getByText('夜間保守メモ 1 / 2', { exact: true })).toHaveCount(0);
    await page.screenshot({ path: info.outputPath('incident-warning.png') });
    if (skip) {
      await button('スキップして探索へ').click();
    } else {
      await button('演出を再開').click();
      await expect(page.getByText('設備異常 2 / 3', { exact: true })).toBeVisible();
      await page.screenshot({ path: info.outputPath('incident-shadow.png') });
      await expect(page.getByText('設備異常 3 / 3', { exact: true })).toBeVisible();
    }
    await expect(button('異常灯：確認済み')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('ターン 0', { exact: true })).toBeVisible();
    await button('異常灯：確認済み').click();
    await expect(button('探索へ戻る')).toBeVisible();
    await expect(page.getByText('設備異常 1 / 3', { exact: true })).toHaveCount(0);
    await button('探索へ戻る').click();
    const before = await page.evaluate(() => (window as any).__incidentAudio.steps);
    await button('保守メモを調べる').click();
    await expect(page.getByText('夜間保守メモ 1 / 2', { exact: true })).toBeVisible();
    await expect.poll(() => page.evaluate(() => (window as any).__incidentAudio.steps)).toBeGreaterThan(before);
    await button('メモを閉じる').click();
    await button('中央廊下の扉を調べる').click();
    await button('扉を開けて進む').click();
    await expect(page.getByText('ターン 1', { exact: true })).toBeVisible();
    await page.screenshot({ path: info.outputPath('incident-returned-hall.png') });
    expect(errors).toEqual([]);
  });
}

test('silent reduced-motion incident resets for a new game', async ({ page }, info) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const button = (name: string) => page.getByRole('button', { name, exact: true });
  await page.goto('/');
  await button('ゲーム開始').click();
  await button('スキップして開始').click();
  await button('異常灯を調べる').click();
  await expect(page.getByText('予備灯だけが、揺れている。', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('incident-reduced-motion.png') });
  await button('スキップして探索へ').click();
  await expect(button('異常灯：確認済み')).toBeVisible();
  await button('所持品を開く').click();
  await expect(page.getByText('所持品は空', { exact: true })).toBeVisible();
  await button('所持品を閉じる').click();
  await button('最初からやり直す').click();
  await expect(button('異常灯を調べる')).toBeVisible();
  await expect(page.getByText('ターン 0', { exact: true })).toBeVisible();
});
