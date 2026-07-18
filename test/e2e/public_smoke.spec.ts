import { expect, test } from '@playwright/test';

const publicRoutes = ['/', '/project-gantt', '/referral'];

test.describe('public production smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} returns the public Flutter shell`, async ({ page }) => {
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' });

      expect(response?.ok()).toBeTruthy();
      await expect(page.locator('body')).toContainText('自分株式会社');
      // クロール用のプリブート SEO シェルが配信されていることを検証する。
      // (#4122 で 'Loading application' プレースホルダは #seo-shell 構造へ刷新。
      //  Flutter 起動後は live DOM が置換され消えるため、配信 HTML 本文で確認する。)
      const servedHtml = (await response?.text()) ?? '';
      expect(servedHtml).toContain('seo-shell');
    });
  }

  test('/project-gantt exposes crawlable entry links while app boots', async ({
    page,
  }) => {
    await page.goto('/project-gantt', { waitUntil: 'domcontentloaded' });

    await expect(page.getByRole('link', { name: '無料で始める' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Proで支援する' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'WBSガントチャート' })).toBeVisible();
  });
});
