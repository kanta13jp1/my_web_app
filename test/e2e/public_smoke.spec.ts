import { expect, test } from '@playwright/test';

const publicRoutes = ['/', '/project-gantt', '/referral'];

test.describe('public production smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} returns the public Flutter shell`, async ({ page }) => {
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' });

      expect(response?.ok()).toBeTruthy();
      await expect(page.locator('body')).toContainText('自分株式会社');
      await expect(page.locator('body')).toContainText('Loading application');
    });
  }

  test('/project-gantt exposes crawlable entry links while app boots', async ({
    page,
  }) => {
    await page.goto('/project-gantt', { waitUntil: 'domcontentloaded' });

    await expect(page.getByRole('link', { name: '無料で始める' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Watch Demo' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'WBSガントチャート' })).toBeVisible();
  });
});
