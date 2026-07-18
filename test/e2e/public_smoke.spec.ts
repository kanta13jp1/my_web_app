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

  test('/project-gantt exposes crawlable entry content while app boots', async ({
    page,
  }) => {
    // クロール用の導線は Flutter 起動前の配信 HTML に含まれる。起動後は live DOM が
    // 置換されるため、配信 HTML 本文で主要導線とルート固有キーワードを検証する。
    // (#4122 でシェルの CTA は '5分だけ無料で試す' 等へ刷新された。)
    const response = await page.goto('/project-gantt', {
      waitUntil: 'domcontentloaded',
    });

    const servedHtml = (await response?.text()) ?? '';
    expect(servedHtml).toContain('5分だけ無料で試す');
    expect(servedHtml).toContain('WBSガントチャート');
  });
});
