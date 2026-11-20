import { test, expect } from '@playwright/test';

const path = '/labs/neon-showcase/index.html';

test('catalog tabs, live 3D modal playback, and 20 X benchmarks render cleanly', async ({ page }) => {
  const errors: string[] = [];
  const external: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => {
    if (!request.url().startsWith('http://127.0.0.1:4173/')) {
      external.push(request.url());
    }
  });

  await page.goto(path);
  await expect(page.getByRole('heading', { level: 1 })).toContainText('NEON SHOWCASE');
  const demoTotal = Number((await page.locator('#stat-demos').textContent())?.trim() || '0');
  expect(demoTotal).toBeGreaterThanOrEqual(32);
  await expect(page.locator('#result-count')).toHaveText(`${demoTotal} / ${demoTotal} 作品`);
  await expect(page.locator('[data-demo-slug="neon-fluid"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="helix-bio-3d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="sentinel-earth-3d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="quant-terminal-3d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="tourbillon-watch-3d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="pagoda-clouds-3d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="solarpunk-canal-2d"]')).toBeVisible();
  await expect(page.locator('[data-demo-slug="red-fuji-flight-3d"]')).toBeVisible();

  await expect(page.locator('#hero-x-thread')).toHaveAttribute(
    'href',
    'https://x.com/kanta13jp1/status/2123532429545906405',
  );
  await expect(page.locator('[data-demo-x]')).toHaveCount(demoTotal);

  // Filter live demos by category and launch a standalone interactive 3D demo modal
  await page.locator('[data-demo-cat="cinema"]').click();
  await expect(page.locator('[data-demo-slug="sea-train-3d"]')).toBeVisible();
  await page.locator('[data-launch-demo="sea-train-3d"]').click();
  await expect(page.locator('#demo-modal')).toBeVisible();
  await expect(page.locator('#modal-title')).toContainText('SHIOKAZE EXPRESS');
  await expect(page.locator('#modal-iframe')).toHaveAttribute(
    'src',
    './demos/sea-train-3d.html?v=20261120-34',
  );
  await expect(page.locator('#modal-iframe')).toHaveAttribute('sandbox', 'allow-scripts');
  await expect(page.locator('#modal-iframe')).toHaveAttribute('allow', 'fullscreen');
  await expect(page.locator('#modal-fullscreen')).toBeVisible();
  await expect(page.locator('#modal-copy-link')).toBeVisible();
  await expect(page.locator('#modal-x-link')).toHaveAttribute(
    'href',
    'https://x.com/kanta13jp1/status/2123332856516845606',
  );
  await expect(page.locator('#modal-open-tab')).toHaveAttribute(
    'href',
    './demos/sea-train-3d.html?v=20261120-34',
  );
  await page.locator('#modal-close').click();
  await expect(page.locator('#demo-modal')).toBeHidden();

  // Switch to Blender 3D tab & test multi-angle procedural preview switcher
  await page.locator('#tab-blender').click();
  await expect(page.locator('#result-count')).toHaveText('5 / 5 作品');
  await page.locator('[data-blender-id="tourbillon-watch-3d"][data-angle-idx="2"]').click();
  await expect(
    page.locator('[data-blender-card="tourbillon-watch-3d"][data-art-angle="exploded"]'),
  ).toBeVisible();
  await expect(page.locator('[data-launch-demo="tourbillon-watch-3d"]')).toBeVisible();
  await expect(page.locator('[data-launch-demo="blender-domino"]')).toBeVisible();

  // Switch to Concept Plans tab & confirm all 6 plans have live launch buttons
  await page.locator('#tab-plans').click();
  await expect(page.locator('#result-count')).toHaveText('6 / 6 企画');
  await expect(page.locator('[data-launch-demo]')).toHaveCount(6);

  // Switch to 20 Referenced X Benchmarks tab & sort by bookmarks
  await page.locator('#tab-benchmarks').click();
  await expect(page.locator('#result-count')).toHaveText('20 / 20 投稿');
  await page.locator('[data-bench-sort="bookmarks"]').click();
  await expect(page.locator('.bench-author').first()).toContainText('@GoogleAIStudio');

  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(errors).toEqual([]);
  expect(external).toEqual([]);
});

test('search empty state recovers cleanly via reset button', async ({ page }) => {
  await page.goto(path);
  const demoTotal = Number((await page.locator('#stat-demos').textContent())?.trim() || '0');
  await page.locator('#search-input').fill('___NO_MATCH_QUERY_999___');
  await expect(page.getByRole('status')).toContainText('見つかりませんでした');
  await page.locator('[data-action="reset-all"]').click();
  await expect(page.locator('#result-count')).toHaveText(`${demoTotal} / ${demoTotal} 作品`);
});

test('reload restores initial clean state without errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(path);
  const demoTotal = Number((await page.locator('#stat-demos').textContent())?.trim() || '0');
  await page.locator('#tab-benchmarks').click();
  await expect(page.locator('#result-count')).toHaveText('20 / 20 投稿');
  await page.reload();
  await expect(page.locator('#tab-demos')).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('#result-count')).toHaveText(`${demoTotal} / ${demoTotal} 作品`);
  expect(errors).toEqual([]);
});
