import { expect, test } from '@playwright/test';

test('hero remains readable and actionable at narrow and wide widths', async ({ page }, testInfo) => {
  const sizes = [{ width: 390, height: 844 }, { width: 1280, height: 900 }, { width: 1440, height: 1000 }];
  for (const size of sizes) {
    await page.setViewportSize(size);
    await page.goto('/?lp_qa=1&lp_hypothesis=h03&lp_variant=treatment');
    const trial = page.getByRole('button', { name: '今やる1件を試す', exact: true });
    await expect(trial).toBeVisible({ timeout: 60000 });
    await expect(trial).toBeInViewport();
    const sample = page.getByRole('button', { name: 'この入力例でAIに提案させる', exact: true });
    await expect(sample).toBeVisible();
    const bounds = await sample.boundingBox();
    expect(bounds?.height).toBeGreaterThanOrEqual(44);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    expect(overflow).toBeFalsy();
    await page.screenshot({ path: testInfo.outputPath(`hero-${size.width}.png`) });
  }
});
