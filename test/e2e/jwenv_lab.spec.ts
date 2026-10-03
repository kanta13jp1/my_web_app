import { test, expect } from '@playwright/test';

const path = '/labs/jwenv/index.html';

test('jwenv lab page renders header, file input, and disabled run button initially', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));

  await page.goto(path);
  await expect(page.locator('h1')).toHaveText('Jev WebGPU Demo');
  await expect(page.locator('#model-file')).toBeVisible();
  await expect(page.locator('#run')).toBeDisabled();
  expect(errors).toEqual([]);
});

test('jwenv lab supports language toggle between Japanese and English', async ({ page }) => {
  await page.goto(path);
  const enButton = page.locator('button[data-lang="en"]');
  const jaButton = page.locator('button[data-lang="ja"]');

  await enButton.click();
  await expect(enButton).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('#tab-request')).toHaveText('Request');

  await jaButton.click();
  await expect(jaButton).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('#tab-request')).toHaveText('リクエスト');
});

test('jwenv lab allows adding question cards', async ({ page }) => {
  await page.goto(path);
  const addBtn = page.locator('#add-question');
  await addBtn.click();
  const cards = page.locator('.qcard');
  await expect(cards).toHaveCount(1);
});
