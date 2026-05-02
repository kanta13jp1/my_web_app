import { readFileSync } from 'node:fs';
import { expect, test } from '@playwright/test';
import {
  installConsoleGuard,
  isKnownFlutterFocusTraversalIssue,
} from './console_guard';

const publicRoutes = ['/', '/project-gantt', '/referral'];

test.describe('public production smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} returns the public Flutter shell`, async ({
      page,
    }, testInfo) => {
      const assertNoUnexpectedBrowserIssues = installConsoleGuard(
        page,
        testInfo,
      );
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' });

      expect(response?.ok()).toBeTruthy();
      await expect(page.locator('body')).toContainText('自分株式会社');
      await expect(page.locator('body')).toContainText('Loading application');
      await page.waitForTimeout(500);
      await assertNoUnexpectedBrowserIssues();
    });
  }

  test('/project-gantt exposes crawlable entry links while app boots', async ({
    page,
  }, testInfo) => {
    const assertNoUnexpectedBrowserIssues = installConsoleGuard(page, testInfo);
    await page.goto('/project-gantt', { waitUntil: 'domcontentloaded' });

    await expect(page.getByRole('link', { name: '無料で始める' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Watch Demo' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'WBSガントチャート' })).toBeVisible();
    await page.waitForTimeout(500);
    await assertNoUnexpectedBrowserIssues();
  });

  test('bootstrap keeps the current Flutter focus traversal release stack filtered', () => {
    const html = readFileSync('web/index.html', 'utf8');

    for (const signature of [
      '.gO',
      '.ge2',
      'Object.e93',
      'Object.dBT',
      '.aEM',
      '.aTV',
      '.asE',
    ]) {
      expect(html).toContain(signature);
    }
  });

  test('console guard allowlists the current Flutter focus traversal release stack', () => {
    expect(
      isKnownFlutterFocusTraversalIssue({
        kind: 'pageerror',
        text: 'Error',
        stack: [
          'at Object.aW (https://example.com/main.dart.js:3992:30)',
          'at ayb.gO (https://example.com/main.dart.js:117655:18)',
          'at ayb.gnc (https://example.com/main.dart.js:117656:18)',
          'at il.ge2 (https://example.com/main.dart.js:134386:45)',
          'at Object.e93 (https://example.com/main.dart.js:29614:5)',
          'at Object.dBT (https://example.com/main.dart.js:29578:5)',
          'at bqk.akW (https://example.com/main.dart.js:134844:11)',
          'at bqk.aEM (https://example.com/main.dart.js:134848:22)',
          'at ahm.aTV (https://example.com/main.dart.js:149224:45)',
          'at a7h.asE (https://example.com/main.dart.js:131579:52)',
        ].join('\n'),
      }),
    ).toBe(true);
  });
});
