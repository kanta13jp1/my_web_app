import { expect, test } from '@playwright/test';

test('hero remains readable and actionable at narrow and wide widths', async ({ page }, testInfo) => {
  test.setTimeout(120_000);
  const layoutErrors: string[] = [];
  page.on('pageerror', (error) => layoutErrors.push(error.message));
  page.on('console', (message) => {
    if (/RenderFlex overflowed|EXCEPTION CAUGHT BY RENDERING/.test(message.text())) {
      layoutErrors.push(message.text());
    }
  });
  const sizes = [{ width: 390, height: 844 }, { width: 1280, height: 900 }, { width: 1440, height: 1000 }];
  for (const size of sizes) {
    await page.setViewportSize(size);
    await page.goto('/?lp_qa=1&lp_hypothesis=h03&lp_variant=treatment');
    await expect(page.locator('#seo-shell')).toBeHidden({ timeout: 30000 });
    const trial = page.getByRole('button', { name: '今やる1件を試す', exact: true });
    await expect(trial).toBeVisible({ timeout: 60000 });
    await expect(trial).toBeInViewport();
    const sample = page.getByRole('button', { name: 'この入力例でAIに提案させる', exact: true });
    await expect(sample).toBeVisible();
    const bounds = await sample.boundingBox();
    expect(bounds?.height).toBeGreaterThanOrEqual(44);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    expect(overflow).toBeFalsy();
    expect(layoutErrors).toEqual([]);
    await page.screenshot({ path: testInfo.outputPath(`hero-${size.width}.png`), scale: 'css' });
  }
});

test('keeps the slow-start preview readable and carries the trial intent into Flutter', async ({ page }, testInfo) => {
  test.setTimeout(120_000);
  let releaseApp!: () => void;
  const appGate = new Promise<void>(resolve => { releaseApp = resolve; });
  let appRequests = 0;
  await page.route('**/main.dart.js*', async route => {
    appRequests++;
    await appGate;
    await route.continue();
  });
  try {
    await page.goto('/?lp_qa=1&lp_hypothesis=h03&lp_variant=treatment', { waitUntil: 'domcontentloaded' });
    const shell = page.locator('#seo-shell');
    await expect(shell).toBeVisible();
    await expect(shell.getByRole('heading', { name: '自分株式会社', exact: true })).toBeVisible();
    const trial = shell.getByRole('link', { name: '登録なしで1件試す', exact: true });
    await expect(trial).toBeInViewport();
    expect((await trial.boundingBox())!.height).toBeGreaterThanOrEqual(44);
    expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)).toBe(false);
    await page.screenshot({ path: testInfo.outputPath('slow-start-preview.png'), scale: 'css' });
    await trial.click();
    await expect(page).toHaveURL(/lp_intent=trial/);
    await expect(shell.getByRole('status')).toContainText('入力画面へ自動で切り替わります');
    releaseApp();
    await expect(shell).toBeHidden({ timeout: 60_000 });
    await expect(page.getByRole('textbox', { name: /例: 今日いちばん詰まっていること|いま詰まっていること/ })).toBeInViewport({ timeout: 60_000 });
    expect(appRequests).toBe(1);
    await page.screenshot({ path: testInfo.outputPath('slow-start-trial-ready.png'), scale: 'css' });
  } finally {
    releaseApp();
  }
});
