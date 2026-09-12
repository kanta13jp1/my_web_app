import { expect, test } from '@playwright/test';

test.use({ javaScriptEnabled: false });

test.describe('Playwright agent seed', () => {
  test('opens the public WBS entry', async ({ page }) => {
    const response = await page.goto('/project-gantt', {
      waitUntil: 'domcontentloaded',
    });

    expect(response?.ok()).toBeTruthy();
    await expect(
      page.getByRole('heading', {
        name: 'WBSガントチャート — 開発を公開',
        exact: true,
      }),
    ).toBeVisible();
  });
});
