// spec: specs/public-no-signup-trial.md
// seed: test/e2e/seed.spec.ts

import { expect, test } from '@playwright/test';

test.use({ javaScriptEnabled: false });

test.describe('Public no-signup trial entry', () => {
  test('opens the WBS entry and follows the no-signup trial link', async ({
    page,
  }) => {
    // 1. Open the crawlable public WBS entry.
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

    // 2. Follow the public no-signup trial link.
    const trialLink = page.getByRole('link', {
      name: '登録なしで1件試す',
      exact: true,
    });
    await expect(trialLink).toBeVisible();
    await trialLink.click();

    // 3. Verify the trial intent and visible landing-page content.
    await page.waitForURL(
      (url) => url.searchParams.get('lp_intent') === 'trial',
    );
    expect(new URL(page.url()).searchParams.get('lp_intent')).toBe('trial');
    await expect(
      page.getByRole('heading', { name: '自分株式会社', exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole('heading', {
        name: '困っていることを書く',
        exact: true,
      }),
    ).toBeVisible();
  });
});
