import { expect, test } from '@playwright/test';

const publicRoutes = ['/', '/project-gantt', '/referral'];

test.describe('public production smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} returns the public Flutter shell`, async ({ request }) => {
      const response = await request.get(route);

      expect(response.ok()).toBeTruthy();
      const html = await response.text();
      expect(html).toContain('id="seo-shell"');
      expect(html).toContain('id="seo-title"');
      expect(html).toMatch(
        /<p\b(?=[^>]*\bclass="seo-loading")(?=[^>]*\brole="status")[^>]*>/,
      );
    });
  }

  test('/project-gantt exposes crawlable entry content while app boots', async ({
    request,
  }) => {
    const response = await request.get('/project-gantt');
    expect(response.ok()).toBeTruthy();
    const html = await response.text();

    expect(html).toContain('登録なしで1件試す');
    expect(html).toContain('WBSガントチャート');
    expect(html).toMatch(
      /href="(?:https:\/\/my-web-app-b67f4\.web\.app)?\/?\?lp_intent=trial&amp;utm_source=seo_shell&amp;utm_medium=landing&amp;utm_campaign=first_user_growth"/,
    );
    expect(html).toContain('href="#seo-how"');
  });
});
