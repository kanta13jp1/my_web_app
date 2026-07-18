import { expect, test } from '@playwright/test';

const publicRoutes = ['/', '/project-gantt', '/referral'];

test.describe('public production smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} returns the public Flutter shell`, async ({ page }) => {
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' });

      expect(response?.ok()).toBeTruthy();
      await expect(page.locator('body')).toContainText('自分株式会社');
      // 起動中に表示される SEO フォールバックの準備文言。PR #4122 で
      // index.html の boot 文言が 'Loading application' から日本語の
      // 準備メッセージへ変わったため追随する。
      await expect(page.locator('body')).toContainText('無料体験を準備しています');
    });
  }

  test('/project-gantt exposes crawlable entry links while app boots', async ({
    page,
  }) => {
    await page.goto('/project-gantt', { waitUntil: 'domcontentloaded' });

    // PR #4122 で SEO シェルの CTA が刷新された (無料で始める/Proで支援する/
    // WBSガントチャート → 5分だけ無料で試す/使い方を見る)。クローラブルな
    // 入口リンクが app boot 前に描画されていることを現行文言で検証する。
    await expect(
      page.getByRole('link', { name: '5分だけ無料で試す' }),
    ).toBeVisible();
    await expect(
      page.getByRole('link', { name: '使い方を見る' }),
    ).toBeVisible();
  });
});
