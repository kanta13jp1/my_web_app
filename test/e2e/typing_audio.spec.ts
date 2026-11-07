import { expect, test } from '@playwright/test';

test('synthesis is opt-in, bounded and stopped when hidden or leaving', async ({ page }) => {
  await page.addInitScript(() => {
    const Original = window.AudioContext;
    const contexts: AudioContext[] = [];
    let starts = 0;
    let active = 0;
    let maximum = 0;
    const frequencies: number[] = [];
    (window as any).__typingAudio = { contexts, frequencies, get starts() { return starts; }, get maximum() { return maximum; } };
    window.AudioContext = new Proxy(Original, {
      construct(target, args) {
        const context = Reflect.construct(target, args) as AudioContext;
        contexts.push(context);
        const create = context.createOscillator.bind(context);
        context.createOscillator = () => {
          const voice = create();
          const start = voice.start.bind(voice);
          const stop = voice.stop.bind(voice);
          let counted = false;
          const release = () => { if (counted) { active--; counted = false; } };
          voice.start = (when) => { starts++; active++; counted = true; frequencies.push(voice.frequency.value); maximum = Math.max(maximum, active); start(when); };
          voice.stop = (when) => { if (when === undefined) release(); stop(when); };
          voice.addEventListener('ended', release);
          return voice;
        };
        return context;
      },
    });
  });
  await page.goto('/');
  await expect(page.locator('#seo-shell')).toHaveCount(0, { timeout: 60_000 });
  await page.getByRole('button', { name: 'English', exact: true }).click();
  await page.getByText('Sound settings', { exact: true }).click();
  expect(await page.evaluate(() => (window as any).__typingAudio.contexts.length)).toBe(0);
  await page.getByRole('button', { name: 'Enable sound', exact: true }).click();
  await expect(page.getByRole('slider', { name: 'Music volume', exact: true })).toBeVisible();
  await expect(page.getByRole('slider', { name: 'Effects volume', exact: true })).toBeVisible();
  expect(await page.evaluate(() => (window as any).__typingAudio.contexts.length)).toBe(1);
  expect(await page.evaluate(() => (window as any).__typingAudio.starts)).toBe(0);
  await page.getByRole('checkbox', { name: '10-word practice', exact: true }).click();
  await page.getByRole('button', { name: 'Start (Enter)', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.starts)).toBeGreaterThan(0);
  await page.getByRole('textbox', { name: 'Romaji input', exact: true }).pressSequentially('qqqqqqqqqqqq');
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.frequencies.includes(220))).toBe(true);
  const mute = page.getByRole('switch', { name: 'Mute', exact: true });
  await mute.click();
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.contexts[0].state)).toBe('suspended');
  await mute.click();
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.contexts[0].state)).toBe('running');
  await page.getByRole('button', { name: 'End practice', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.contexts[0].state)).toBe('suspended');
  await page.getByRole('button', { name: 'Try again (Enter)', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.contexts[0].state)).toBe('running');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(() => page.evaluate(() => (window as any).__typingAudio.contexts[0].state)).toBe('suspended');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => false });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  expect(await page.evaluate(() => (window as any).__typingAudio.contexts.length)).toBe(1);
  expect(await page.evaluate(() => (window as any).__typingAudio.maximum)).toBeLessThanOrEqual(2);
  await page.goto('about:blank');
});

test('missing Web Audio support keeps typing usable', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
  });
  await page.goto('/');
  await expect(page.locator('#seo-shell')).toHaveCount(0, { timeout: 60_000 });
  await page.getByRole('button', { name: 'English', exact: true }).click();
  await page.getByText('Sound settings', { exact: true }).click();
  await page.getByRole('button', { name: 'Enable sound', exact: true }).click();
  await expect(page.getByText(/Audio could not start here/)).toBeVisible();
  await page.getByRole('button', { name: 'Start (Enter)', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Romaji input', exact: true })).toBeVisible();
});
